// SPDX-License-Identifier: GPL-3.0-only
// Adapted from huamidev/GestaltX, commit 72bf625. See THIRD_PARTY_NOTICES.md.
import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Shared storage locations for the device-console feature. Everything lives in
/// private Application Support, device-bound by `deviceIdentifier`.
nonisolated enum DeviceConsolePaths {
    private static let identity = ConsoleDeviceIdentity()

    @MainActor static func configureIdentity() {
        #if canImport(UIKit)
        identity.set(identifier: UIDevice.current.identifierForVendor?.uuidString ?? "", model: UIDevice.current.model)
        #endif
    }
    static func base() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    }
    static var pairing: URL { base().appendingPathComponent("Erosion/Pairing", isDirectory: true) }
    static var capturedSounds: URL { base().appendingPathComponent("Erosion/CapturedSounds", isDirectory: true) }

    static var deviceIdentifier: String {
        identity.snapshot.identifier
    }

    /// Bundle id at runtime — background-task identifiers derive from this so a
    /// self-signed rewrite of the bundle id does not break registration.
    static var runtimeBundleID: String {
        Bundle.main.bundleIdentifier ?? "io.github.su-cyber-art.ErosionPlus"
    }

    static var hostModelName: String {
        identity.snapshot.model
    }
}

/// UIKit identity is captured on the main actor before background stores open.
nonisolated private final class ConsoleDeviceIdentity: @unchecked Sendable {
    private let lock = NSLock()
    private var identifier = ""
    private var model = ""
    func set(identifier: String, model: String) {
        lock.lock(); defer { lock.unlock() }
        self.identifier = identifier
        self.model = model
    }
    var snapshot: (identifier: String, model: String) {
        lock.lock(); defer { lock.unlock() }
        return (identifier, model)
    }
}
