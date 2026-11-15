// SPDX-License-Identifier: GPL-3.0-only
// Adapted from huamidev/GestaltX, commit 72bf625. See THIRD_PARTY_NOTICES.md.
import Foundation
import Darwin

nonisolated struct LaunchArtworkApp: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let name: String
    var byteCount: Int64 = 0
}
nonisolated struct LaunchArtworkState: Sendable {
    let count: Int
    let canRestore: Bool
    let preview: Data?
    let width: Int
    let height: Int
}

actor LaunchArtworkStore {
    private let storage: URL
    private let device: String
    private let resolver: (@Sendable (LaunchArtworkApp) throws -> URL)?
    private let beforeWrite: (@Sendable () throws -> Void)?
    private let fm = FileManager.default
    init(storage: URL, device: String, resolver: (@Sendable (LaunchArtworkApp) throws -> URL)? = nil,
         beforeWrite: (@Sendable () throws -> Void)? = nil) {
        self.storage = storage; self.device = device; self.resolver = resolver; self.beforeWrite = beforeWrite
    }
    private func access<T>(_ app: LaunchArtworkApp, _ operation: (URL, LaunchArtworkDirectory) throws -> T) throws -> T {
        guard !device.isEmpty, LaunchArtworkDirectory.validIdentifier(app.id) else { throw changed }
        let folder = storage.appendingPathComponent(app.id, isDirectory: true)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        let lease = open(folder.appendingPathComponent(".writer.lock").path, O_RDWR | O_CREAT | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard lease >= 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
        defer { close(lease) }
        guard flock(lease, LOCK_EX | LOCK_NB) == 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
        let container: URL
        var handle: Int64 = -1
        if let resolver { container = try resolver(app) }
        else {
            #if os(iOS) && !targetEnvironment(simulator)
            guard let path = GXCustomizationAccess.launchContainer(for: app.id) else {
                throw CustomizationFailure("The device container could not be located. Read again.")
            }
            container = URL(fileURLWithPath: path, isDirectory: true)
            if app.id != Bundle.main.bundleIdentifier {
                handle = GXCustomizationAccess.acquirePath(path)
                guard handle >= 0 else { throw CustomizationFailure("These system settings are not accessible on this device.") }
            }
            #else
            throw CustomizationFailure("Device access is unavailable in the Simulator. Open a plist to explore Erosion.")
            #endif
        }
        defer {
            #if os(iOS) && !targetEnvironment(simulator)
            if handle >= 0 { worse_query_release(handle) }
            #endif
        }
        return try operation(container, LaunchArtworkDirectory(container: container, identifier: app.id))
    }
    func state(_ app: LaunchArtworkApp) throws -> LaunchArtworkState {
        try access(app) { container, directory in
            let names = try directory.names()
            var canRestore = false, preview: Data?, width = 1, height = 2
            for name in names {
                guard let file = try directory.read(name) else { continue }
                let size = try LaunchArtworkImages.dimensions(file.data)
                if preview == nil { preview = LaunchArtworkImages.preview(file.data); width = size.width; height = size.height }
                if let saved = try directory.original(name), saved.matches(file.data), file.data != saved.data { canRestore = true }
            }
            return LaunchArtworkState(count: names.count, canRestore: canRestore, preview: preview, width: width, height: height)
        }
    }
    func currentImage(_ app: LaunchArtworkApp) throws -> Data {
        try access(app) { _, directory in
            for name in try directory.names() {
                if let file = try directory.read(name), let png = LaunchArtworkImages.export(file.data) { return png }
            }
            throw CustomizationFailure("No launch images found. Open the app once, close it, then read again.")
        }
    }
    func apply(_ photo: Data, to app: LaunchArtworkApp) throws -> Int {
        try access(app) { container, directory in
            let names = try directory.names()
            guard !names.isEmpty else { throw CustomizationFailure("No launch images found. Open the app once, close it, then read again.") }
            var before: [String: LaunchArtworkDirectory.File] = [:], replacements: [String: Data] = [:]
            var total = 0, encodedTotal = 0
            for name in names {
                guard let file = try directory.read(name) else { throw changed }
                total += file.data.count
                guard total <= 64 * 1024 * 1024 else { throw changed }
                let size = try LaunchArtworkImages.dimensions(file.data)
                let png = try LaunchArtworkImages.render(photo, width: size.width, height: size.height)
                encodedTotal += png.count
                guard png.count <= LaunchArtworkDirectory.maximumFile, encodedTotal <= 64 * 1024 * 1024 else {
                    throw CustomizationFailure("This image could not be used. Choose another image.")
                }
                before[name] = file; replacements[name] = png
            }
            // Publish and verify every original before touching any target.
            for name in names { try directory.backup(name, file: before[name]!, replacement: replacements[name]!) }
            try commit(replacements, before: before, directory: directory)
            log("Launch images: applied \(replacements.count) image(s); originals kept beside the files.")
            return replacements.count
        }
    }
    func restore(_ app: LaunchArtworkApp) throws -> Int {
        try access(app) { container, directory in
            var before: [String: LaunchArtworkDirectory.File] = [:], replacements: [String: Data] = [:]
            var originals: [String: ContainerOriginals.Backup] = [:]
            for name in try directory.names() {
                guard let file = try directory.read(name), let saved = try directory.original(name),
                      saved.matches(file.data), saved.data != file.data else { continue }
                _ = try LaunchArtworkImages.dimensions(saved.data)
                before[name] = file; replacements[name] = saved.data; originals[name] = saved
            }
            try commit(replacements, before: before, directory: directory, restoring: originals)
            log("Launch images: restored \(replacements.count) image(s); sibling backups retained.")
            return replacements.count
        }
    }
    private func commit(_ replacements: [String: Data], before: [String: LaunchArtworkDirectory.File], directory: LaunchArtworkDirectory,
                        restoring: [String: ContainerOriginals.Backup] = [:]) throws {
        var written: [String] = []
        do {
            for name in replacements.keys.sorted() {
                try beforeWrite?()
                written.append(name)
                try directory.replace(name, expected: before[name]!, data: replacements[name]!,
                                      protection: restoring[name]?.protection, mode: restoring[name]?.mode)
            }
        } catch {
            var recovered = true
            for name in written.reversed() {
                do {
                    guard let current = try directory.read(name), current.data == replacements[name] else { continue }
                    try directory.replace(name, expected: current, data: before[name]!.data,
                                          protection: before[name]!.protection, mode: before[name]!.mode)
                } catch { recovered = false }
            }
            if !recovered { throw CustomizationFailure("Some files could not be restored. The backup has been kept.") }
            throw error
        }
    }
    private var changed: CustomizationFailure { CustomizationFailure("The files changed. Read again before applying.") }
    private func log(_ message: String) {
        NotificationCenter.default.post(name: Notification.Name("Erosion.worse_query.log"), object: nil, userInfo: ["message": message])
    }
}
