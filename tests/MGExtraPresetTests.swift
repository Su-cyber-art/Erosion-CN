import Foundation
import CoreFoundation

@main enum MGExtraPresetTests {
    static func expect(_ condition: Bool, _ message: String) throws {
        if !condition { throw NSError(domain: "MGExtraPresetTests", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
    }

    static func main() throws {
        let cache = Data([0, 13, 255, 1])
        let current: NSDictionary = ["CacheData": cache, "CacheUUID": "unchanged", "CacheExtra": ["unrelated": NSNumber(value: 1.25)]]
        let original: NSDictionary = ["CacheExtra": [MGExtraPreset.hdrPhotos.key: NSNumber(value: true), MGExtraPreset.onDeviceSiri.key: NSNumber(value: 2)]]
        for preset in MGExtraPreset.allCases where preset.canEnable {
            let edited = try preset.applying(to: current, original: original, restore: false)
            try expect(edited["CacheData"] as? Data == cache && edited["CacheUUID"] as? String == "unchanged", "A preset changed the binary cache or its identity")
            try expect((current["CacheExtra"] as! NSDictionary)[preset.key] == nil, "Staging mutated the loaded baseline")
            let restored = try preset.applying(to: edited, original: original, restore: true)
            let extra = restored["CacheExtra"] as! NSDictionary
            try expect(extra["unrelated"] as? Double == 1.25, "Restore discarded an unrelated edit")
            if preset == .hdrPhotos {
                let value = extra[preset.key] as! NSNumber
                try expect(CFGetTypeID(value) == CFBooleanGetTypeID() && value.boolValue, "Restore lost the original Boolean type")
            } else {
                try expect(extra[preset.key] == nil, "Restore did not remove an originally absent key")
            }
        }
        let siri = try MGExtraPreset.onDeviceSiri.applying(to: current, original: original, restore: true)
        try expect((siri["CacheExtra"] as! NSDictionary)[MGExtraPreset.onDeviceSiri.key] as? Int == 2, "Device-specific Siri value was not restored")
        do {
            _ = try MGExtraPreset.onDeviceSiri.applying(to: current, original: original, restore: false)
            throw NSError(domain: "MGExtraPresetTests", code: 2)
        } catch MGExtraPresetError.restoreOnly {}
        do {
            _ = try MGExtraPreset.siriAIMode.applying(to: current, original: [:], restore: true)
            throw NSError(domain: "MGExtraPresetTests", code: 3)
        } catch MGExtraPresetError.invalidBackup {}
        print("PASS: staged edits preserve the binary cache, baseline, unrelated values, original types and absent keys; invalid restores are rejected.")
    }
}
