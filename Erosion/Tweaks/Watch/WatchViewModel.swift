import Foundation
import Combine

struct WatchChange: Identifiable {
    let id: String
    let title: String
    let before: String
    let after: String
}

struct WatchWritePreview: Identifiable {
    let id = UUID()
    let deviceID: String
    let generation: Int
    let expected: Data
    let document: WatchMGDocument
    let changes: [WatchChange]
}

@MainActor
final class WatchViewModel: ObservableObject {
    let connection = WatchConnection()
    @Published private(set) var document: WatchMGDocument?
    @Published private(set) var baseline: WatchMGDocument?
    @Published private(set) var isBusy = false
    @Published private(set) var backups: [WatchBackup] = []
    @Published var message: String?
    @Published var pendingPreview: WatchWritePreview?
    private var snapshot: Data?
    private var original: WatchMGDocument?
    private var deviceID: String?
    private var originalBackupURL: URL?
    private var deviceObservation: AnyCancellable?

    init() {
        deviceObservation = connection.$pairingGeneration.dropFirst().sink { [weak self] _ in self?.invalidateDevice() }
    }

    var changes: [WatchChange] {
        guard let baseline, let document else { return [] }
        return changes(from: baseline, to: document)
    }
    var hasChanges: Bool { !changes.isEmpty }
    var canApply: Bool { hasChanges && snapshot != nil && !isBusy && connection.isReachable }

    func loadIfReachable() async {
        connection.refresh()
        if connection.isReachable, document == nil, !isBusy { await load() }
    }

    func load() async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        let generation = connection.pairingGeneration
        do {
            let id = try await connection.identify()
            let data = try await connection.read(deviceID: id)
            guard generation == connection.pairingGeneration else { throw changedWatch }
            let loaded = try WatchMGDocument(data: data)
            var records = try WatchBackupStore.list(deviceID: id)
            var firstCompatible: WatchMGDocument?
            var firstURL: URL?
            for record in records.reversed() {
                let candidate = try WatchMGDocument(data: Data(contentsOf: record.url))
                if (try? candidate.validateRestore(against: loaded)) != nil {
                    firstCompatible = candidate
                    firstURL = record.url
                    break
                }
            }
            if firstCompatible == nil {
                let saved = try WatchBackupStore.create(data, deviceID: id)
                records.insert(saved, at: 0)
                firstCompatible = loaded
                firstURL = saved.url
            }
            deviceID = id
            snapshot = data
            baseline = loaded
            document = loaded
            original = firstCompatible
            originalBackupURL = firstURL
            backups = records
        } catch { message = error.localizedDescription }
    }

    func invalidateDevice() {
        document = nil
        baseline = nil
        snapshot = nil
        original = nil
        deviceID = nil
        originalBackupURL = nil
        backups = []
        pendingPreview = nil
    }

    func discard() { document = baseline }

    func applyPreset(_ preset: WatchTweak, ultraClass: Int? = nil) {
        guard !isBusy, let document else { return }
        do {
            self.document = try WatchTweakCatalog.apply([preset.id], to: document,
                build: connection.build, regionIdentifier: connection.regionIdentifier,
                ultraFaceClass: ultraClass, original: original,
                hardwareIdentifier: connection.hardwareIdentifier)
        } catch { message = error.localizedDescription }
    }

    func restorePreset(_ preset: WatchTweak) {
        guard !isBusy, var current = document, let original else { return }
        do {
            try original.validateRestore(against: current)
            var keys = preset.keys
            if preset.isFace {
                guard let layout = WatchTweakCatalog.faceLayout(plist: current, build: connection.build),
                      WatchTweakCatalog.faceLayout(plist: original, build: connection.build) != nil,
                      let offset = layout[preset.id == "hermes" ? "DeviceBrandOffset" : "ScreenClassOffset"] as? Int,
                      var data = current.dict["CacheData"] as? Data,
                      let old = original.dict["CacheData"] as? Data else {
                    throw WatchMGWire.failure(watchLocalized("The original Watch face layout is unavailable."))
                }
                data.replaceSubrange(offset..<(offset + 4), with: old[offset..<(offset + 4)])
                current.dict["CacheData"] = data
                keys = [preset.id == "hermes" ? "fuKL2rMywRgQF1wowOA/cg" : "fdh+s6j3VijuyrK7xLjd7g"]
            } else if preset.id == "intelligence" {
                keys += ["h63QSdBCiT/z0WU6rdQv6Q", "zHeENZu+wbg7PUprwNwBWg", "yK+xavymRGZ3xWc1tb8XDg"]
            }
            for key in keys {
                if let value = original.cacheExtra[key] { current.setCacheExtra(value, forKey: key) }
                else { current.removeCacheExtraValue(forKey: key) }
            }
            document = current
        } catch { message = error.localizedDescription }
    }

    func setRegion(code: String?, sales: String?) {
        guard !isBusy, var current = document else { return }
        if let code { current.setCacheExtra(code, forKey: "h63QSdBCiT/z0WU6rdQv6Q") }
        if let sales {
            let present = ["zHeENZu+wbg7PUprwNwBWg", "yK+xavymRGZ3xWc1tb8XDg"].filter { current.cacheExtra[$0] != nil }
            for key in present.isEmpty ? ["zHeENZu+wbg7PUprwNwBWg"] : present { current.setCacheExtra(sales, forKey: key) }
        }
        document = current
    }

    func setResolution(_ index: Int) {
        guard !isBusy, var current = document, WatchTweakCatalog.resolutions.indices.contains(index) else { return }
        let resolution = WatchTweakCatalog.resolutions[index]
        current.setCacheExtra(resolution.1, forKey: "g7YQ1Djxh4YiKlEeaoGhzg")
        current.setCacheExtra(resolution.2, forKey: "OjzOua0LkOegX7pQdgMksw")
        document = current
    }

    func setField(_ key: String, value: Any?) {
        guard !isBusy, var current = document else { return }
        guard !WatchMGDocument.identityKeys.contains(key) else {
            message = L("设备身份字段仅供查看。")
            return
        }
        if let value { current.setCacheExtra(value, forKey: key) }
        else { current.removeCacheExtraValue(forKey: key) }
        document = current
    }

    func preview(restoring backup: WatchBackup? = nil) throws -> WatchWritePreview {
        guard let deviceID, let snapshot, let baseline, let document else { throw changedWatch }
        let target: WatchMGDocument
        if let backup {
            target = try WatchMGDocument(data: Data(contentsOf: backup.url))
            try target.validateRestore(against: baseline)
        } else { target = document }
        return WatchWritePreview(deviceID: deviceID, generation: connection.pairingGeneration,
                                 expected: snapshot, document: target, changes: changes(from: baseline, to: target))
    }

    func commit(_ preview: WatchWritePreview) async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            guard deviceID == preview.deviceID, connection.pairingGeneration == preview.generation else { throw changedWatch }
            _ = try WatchBackupStore.create(preview.expected, deviceID: preview.deviceID)
            let payload = try preview.document.encoded()
            guard payload.count <= WatchMGWire.maximumFileSize else {
                throw WatchMGWire.failure(watchLocalized("Choose a Watch plist smaller than 4 MB."))
            }
            try await connection.write(payload, deviceID: preview.deviceID, expectedHash: WatchMGWire.digest(preview.expected))
            guard connection.pairingGeneration == preview.generation else { throw changedWatch }
            let data = try await connection.read(deviceID: preview.deviceID)
            guard connection.pairingGeneration == preview.generation else { throw changedWatch }
            let verified = try WatchMGDocument(data: data)
            guard WatchMGDocument.equal(verified.dict, preview.document.dict) else {
                throw WatchMGWire.failure(watchLocalized("Write verification failed. Reload Apple Watch before continuing."))
            }
            snapshot = data
            baseline = verified
            document = verified
            backups = try WatchBackupStore.list(deviceID: preview.deviceID)
        } catch {
            snapshot = nil // A reply may be lost after a successful write; read again before retrying.
            message = error.localizedDescription
            return
        }
        do {
            try await connection.restartInterface(deviceID: preview.deviceID)
            message = L("已保存并核验，已请求刷新手表界面。")
        } catch {
            message = L("修改已保存并核验，但未能确认界面刷新。请手动重启手表。\n\(error.localizedDescription)")
        }
    }

    func createBackup() async {
        guard !isBusy, let deviceID else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            let data = try await connection.read(deviceID: deviceID)
            _ = try WatchBackupStore.create(data, deviceID: deviceID)
            backups = try WatchBackupStore.list(deviceID: deviceID)
            message = L("手表当前配置已备份到这台 iPhone。")
        } catch { message = error.localizedDescription }
    }

    func importBackup(_ url: URL) {
        guard !isBusy, let deviceID, let baseline else { return }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize
            guard let size, size > 0, size <= WatchMGWire.maximumFileSize else {
                throw WatchMGWire.failure(watchLocalized("Choose a Watch plist smaller than 4 MB."))
            }
            let data = try Data(contentsOf: url)
            try WatchMGDocument(data: data).validateRestore(against: baseline)
            _ = try WatchBackupStore.create(data, deviceID: deviceID)
            backups = try WatchBackupStore.list(deviceID: deviceID)
        } catch { message = error.localizedDescription }
    }

    func isInitialBackup(_ backup: WatchBackup) -> Bool { backup.url == originalBackupURL }

    func deleteBackup(_ backup: WatchBackup) {
        guard !isBusy, let deviceID, !isInitialBackup(backup) else { return }
        do {
            try FileManager.default.removeItem(at: backup.url)
            backups = try WatchBackupStore.list(deviceID: deviceID)
        } catch { message = error.localizedDescription }
    }

    private var changedWatch: NSError { WatchMGWire.failure(watchLocalized("Reload Apple Watch before saving.")) }

    private func changes(from before: WatchMGDocument, to after: WatchMGDocument) -> [WatchChange] {
        let keys = Set(before.cacheExtra.keys).union(after.cacheExtra.keys).sorted()
        var result = keys.compactMap { key -> WatchChange? in
            guard !WatchMGDocument.equal(before.cacheExtra[key], after.cacheExtra[key]) else { return nil }
            let name = WatchTweakCatalog.definitions.first { $0.keys.contains(key) }?.title ?? key
            return WatchChange(id: key, title: name, before: mgFormatValue(before.cacheExtra[key]), after: mgFormatValue(after.cacheExtra[key]))
        }
        if let a = before.dict["CacheData"] as? Data, let b = after.dict["CacheData"] as? Data, a != b {
            if a.count == b.count {
                for index in a.indices where a[index] != b[index] {
                    result.append(WatchChange(id: "CacheData-\(index)", title: L("表盘参数 · 偏移 \(index)"),
                                              before: String(format: "0x%02X", a[index]), after: String(format: "0x%02X", b[index])))
                }
            }
        }
        for key in Set(before.dict.keys).union(after.dict.keys).subtracting(["CacheExtra", "CacheData"]).sorted() {
            if !WatchMGDocument.equal(before.dict[key], after.dict[key]) {
                result.append(WatchChange(id: "root-\(key)", title: key,
                                          before: mgFormatValue(before.dict[key]), after: mgFormatValue(after.dict[key])))
            }
        }
        return result
    }
}
