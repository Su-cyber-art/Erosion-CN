import Foundation

nonisolated func L(_ value: String.LocalizationValue) -> String {
    String(localized: value)
}

@MainActor
final class WatchGestaltAccess {
    private let access = GestaltAccess.shared()
    private let url = URL(fileURLWithPath: "/private/var/containers/Shared/SystemGroup/systemgroup.com.apple.mobilegestaltcache/Library/Caches/com.apple.MobileGestalt.plist")

    func read() throws -> Data {
        try access.readGestaltData()
    }

    func write(_ dictionary: [String: Any]) throws {
        try access.connect()
        let data = try PropertyListSerialization.data(fromPropertyList: dictionary, format: .binary, options: 0)
        let result = writeFileAtomically(data, to: url)
        guard result.0 else { throw WatchMGWire.failure(result.1) }
    }
}
