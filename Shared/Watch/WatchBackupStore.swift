import Foundation

nonisolated struct WatchBackup: Identifiable, Hashable {
    let url: URL
    let date: Date
    let size: Int
    var id: URL { url }
}

nonisolated enum WatchBackupStore {
    static func directory(deviceID: String) throws -> URL {
        guard UUID(uuidString: deviceID) != nil else { throw WatchMGWire.failure("Invalid Apple Watch identifier.") }
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Watch Backups", isDirectory: true)
            .appendingPathComponent(deviceID, isDirectory: true)
    }

    @discardableResult static func create(_ data: Data, deviceID: String) throws -> WatchBackup {
        _ = try WatchMGWire.decode(data)
        let folder = try directory(deviceID: deviceID)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(UUID().uuidString).appendingPathExtension("plist")
        try data.write(to: url, options: .atomic)
        guard try Data(contentsOf: url) == data else {
            throw WatchMGWire.failure(watchLocalized("The backup could not be verified. No system write was started."))
        }
        return WatchBackup(url: url, date: Date(), size: data.count)
    }

    static func list(deviceID: String) throws -> [WatchBackup] {
        let folder = try directory(deviceID: deviceID)
        if !FileManager.default.fileExists(atPath: folder.path) { return [] }
        return try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.creationDateKey, .fileSizeKey])
            .filter { $0.pathExtension == "plist" }
            .map { url in
                let attributes = try url.resourceValues(forKeys: [.creationDateKey, .fileSizeKey])
                return WatchBackup(url: url, date: attributes.creationDate ?? .distantPast, size: attributes.fileSize ?? 0)
            }
            .sorted { $0.date > $1.date }
    }
}
