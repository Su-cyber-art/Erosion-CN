import Foundation

@main enum WatchDocumentTests {
    static func verify(_ condition: Bool) { precondition(condition) }
    static func main() throws {
        let original = WatchMGDocument(dict: ["CacheUUID": "ABC", "CacheVersion": "build", "CacheData": Data([1, 2]),
            "CacheExtra": ["h9jDsbgj7xIVeIQ8S3/X3Q": "Watch7,18", "flag": NSNumber(value: true), "number": NSNumber(value: 1.0)]])
        var alternate = original
        alternate.dict["CacheUUID"] = "abc"
        try alternate.validateRestore(against: original)
        verify(!WatchMGDocument.equal(NSNumber(value: true), NSNumber(value: 1)))
        verify(!WatchMGDocument.equal(NSNumber(value: 1.0), NSNumber(value: 1)))
        verify(WatchMGDocument.equal(try WatchMGDocument(data: original.encoded()).dict, original.dict))
        let replacements: [(String, Any)] = [("CacheUUID", "other"), ("CacheVersion", "new-build"), ("CacheData", Data([1]))]
        for replacement in replacements {
            var invalid = original
            invalid.dict[replacement.0] = replacement.1
            do { try invalid.validateRestore(against: original); fatalError("Accepted incompatible Watch cache") } catch {}
        }
        var otherWatch = original
        otherWatch.setCacheExtra("Watch99,1", forKey: "h9jDsbgj7xIVeIQ8S3/X3Q")
        do { try otherWatch.validateRestore(against: original); fatalError("Accepted different hardware identity") } catch {}
        print("PASS: Watch restores require compatible cache generations and identity; Plist comparisons preserve Boolean and numeric types.")
    }
}
