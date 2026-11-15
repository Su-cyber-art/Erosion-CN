import Foundation
import CoreFoundation

nonisolated struct WatchMGDocument {
    static let identityKeys: Set<String> = ["h9jDsbgj7xIVeIQ8S3/X3Q", "oYicEKzVTz4/CxxE05pEgQ", "5pYKlGnYYBzGvAlIU8RjEQ", "re6Zb+zwFKJNlkQTUeT+/w", "VasUgeSzVyHdB27g2XpN0g", "TF31PAB6aO8KAbPyNKSxKA"]
    var dict: [String: Any]
    var cacheExtra: [String: Any] { dict["CacheExtra"] as! [String: Any] }

    init(dict: [String: Any]) { self.dict = dict }
    init(data: Data) throws { dict = try WatchMGWire.decode(data) }

    mutating func setCacheExtra(_ value: Any, forKey key: String) {
        var extra = cacheExtra
        extra[key] = value
        dict["CacheExtra"] = extra
    }
    mutating func removeCacheExtraValue(forKey key: String) {
        var extra = cacheExtra
        extra.removeValue(forKey: key)
        dict["CacheExtra"] = extra
    }
    func encoded() throws -> Data {
        try PropertyListSerialization.data(fromPropertyList: dict, format: .binary, options: 0)
    }

    func validateRestore(against current: Self) throws {
        guard let uuid = dict["CacheUUID"] as? String,
              let currentUUID = current.dict["CacheUUID"] as? String,
              uuid.caseInsensitiveCompare(currentUUID) == .orderedSame,
              let data = dict["CacheData"] as? Data,
              let currentData = current.dict["CacheData"] as? Data,
              data.count == currentData.count,
              Self.equal(dict["CacheVersion"], current.dict["CacheVersion"]),
              Self.identityKeys.allSatisfy({ Self.equal(cacheExtra[$0], current.cacheExtra[$0]) }) else {
            throw WatchMGWire.failure(watchLocalized("This backup uses a different Watch cache layout. It cannot be restored."))
        }
    }

    static func equal(_ lhs: Any?, _ rhs: Any?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil): return true
        case (nil, _), (_, nil): return false
        case (let lhs?, let rhs?):
            if let a = lhs as? NSNumber, let b = rhs as? NSNumber {
                let boolA = CFGetTypeID(a) == CFBooleanGetTypeID()
                let boolB = CFGetTypeID(b) == CFBooleanGetTypeID()
                guard boolA == boolB else { return false }
                if boolA { return a.boolValue == b.boolValue }
                let floatA = CFNumberIsFloatType(a), floatB = CFNumberIsFloatType(b)
                guard floatA == floatB else { return false }
                return floatA ? a.doubleValue == b.doubleValue : a.stringValue == b.stringValue
            }
            if let a = lhs as? [String: Any], let b = rhs as? [String: Any] {
                return a.count == b.count && a.allSatisfy { equal($0.value, b[$0.key]) }
            }
            if let a = lhs as? [Any], let b = rhs as? [Any] {
                return a.count == b.count && zip(a, b).allSatisfy { equal($0.0, $0.1) }
            }
            return (lhs as AnyObject).isEqual(rhs)
        }
    }
}
