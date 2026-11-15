// SPDX-License-Identifier: GPL-3.0-only
// Adapted from huamidev/GestaltX, commit 72bf625. See THIRD_PARTY_NOTICES.md.
import Foundation
import CryptoKit

nonisolated struct CustomizationFailure: LocalizedError {
    let key: String
    init(_ key: String) { self.key = key }
    var errorDescription: String? { customizationLocalized(key) }
}

/// These hashes identify original and replacement bytes in restoration records.
nonisolated enum CustomizationFiles {
    static let maximumFile = 256 * 1024 * 1024

    static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func saveVerified<T: Codable>(_ object: T, to url: URL) throws {
        let data = try PropertyListEncoder().encode(object)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
        guard try Data(contentsOf: url) == data else {
            throw CustomizationFailure("The original files could not be backed up.")
        }
    }
}
