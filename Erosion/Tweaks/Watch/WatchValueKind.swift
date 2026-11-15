// Adapted from huamidev/GestaltX (GPL-3.0), commit 72bf625.
import Foundation
import CoreFoundation

nonisolated enum WatchValueKind: String, CaseIterable, Identifiable, Sendable {
    case string = "String", integer = "Integer", real = "Real", boolean = "Boolean"
    case data = "Data", array = "Array", dictionary = "Dictionary", date = "Date"
    var id: String { rawValue }

    static func detect(_ value: Any) -> Self {
        if let number = value as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() { return .boolean }
            return CFNumberIsFloatType(unsafeBitCast(number, to: CFNumber.self)) ? .real : .integer
        }
        if value is Date { return .date }
        if value is Data { return .data }
        if value is [String: Any] { return .dictionary }
        if value is [Any] { return .array }
        return .string
    }

    func parse(_ text: String) throws -> Any {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        switch self {
        case .string: return text
        case .integer:
            if let value = Int64(trimmed) { return NSNumber(value: value) }
            // Binary plists can also contain unsigned 64-bit identifiers.
            guard let value = UInt64(trimmed) else { throw WatchMGWire.failure("Enter a valid whole number.") }
            return NSNumber(value: value)
        case .real:
            guard let value = Double(trimmed), value.isFinite else { throw WatchMGWire.failure("Enter a finite decimal number.") }
            return NSNumber(value: value)
        case .boolean:
            switch trimmed.lowercased() {
            case "true", "1": return NSNumber(value: true)
            case "false", "0": return NSNumber(value: false)
            default: throw WatchMGWire.failure("Use true or false for a Boolean value.")
            }
        case .date:
            // The formatter can accept a valid date prefix and ignore trailing
            // text. Field edits must consume the complete value the user entered.
            let pattern = #"^[0-9]{4}-[0-9]{2}-[0-9]{2}[Tt][0-9]{2}:[0-9]{2}:[0-9]{2}(?:\.[0-9]+)?(?:[Zz]|[+-][0-9]{2}:?[0-9]{2})$"#
            guard trimmed.range(of: pattern, options: .regularExpression) != nil else {
                throw WatchMGWire.failure("Enter an ISO 8601 date, such as 2026-11-09T12:00:00Z.")
            }
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let value = formatter.date(from: trimmed) { return value }
            formatter.formatOptions = [.withInternetDateTime]
            guard let value = formatter.date(from: trimmed) else { throw WatchMGWire.failure("Enter an ISO 8601 date, such as 2026-11-09T12:00:00Z.") }
            return value
        case .data:
            guard let value = Data(base64Encoded: trimmed.filter { !$0.isWhitespace }) else { throw WatchMGWire.failure("Enter valid Base64 data.") }
            return value
        case .array, .dictionary:
            // An XML plist fragment preserves nested Data, Boolean and integer types.
            let xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><plist version=\"1.0\">\(text)</plist>"
            guard let value = try? PropertyListSerialization.propertyList(from: Data(xml.utf8), options: [], format: nil),
                  (self == .array && value is [Any]) || (self == .dictionary && value is [String: Any]) else {
                throw WatchMGWire.failure("Enter an XML plist array or dictionary fragment.")
            }
            return value
        }
    }

    func text(for value: Any) -> String {
        switch self {
        case .boolean: return (value as? NSNumber)?.boolValue == true ? "true" : "false"
        case .date:
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return (value as? Date).map { formatter.string(from: $0) } ?? ""
        case .data: return (value as? Data)?.base64EncodedString() ?? ""
        case .array, .dictionary:
            guard let data = try? PropertyListSerialization.data(fromPropertyList: value, format: .xml, options: 0),
                  let xml = String(data: data, encoding: .utf8),
                  let start = xml.range(of: "<plist version=\"1.0\">"),
                  let end = xml.range(of: "</plist>", options: .backwards) else { return "" }
            return String(xml[start.upperBound..<end.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        default: return String(describing: value)
        }
    }
}
