// WatchConnectivity flow adapted from frs0n/GestaltEdit, commit b8b9ce4.
import SwiftUI
import WatchConnectivity
import WatchKit
import Combine
import Darwin

@main
struct ErosionWatchApp: App {
    @StateObject private var helper = ErosionWatchHelper()
    var body: some Scene {
        WindowGroup {
            VStack(spacing: 14) {
                Image(systemName: "applewatch")
                    .font(.system(size: 38, weight: .medium))
                    .foregroundStyle(.orange)
                Text("Erosion Plus").font(.headline)
                Text(helper.status)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                if helper.isConnected {
                    Label("iPhone 已连接", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
            .padding(.horizontal, 12)
        }
    }
}

@MainActor
final class ErosionWatchHelper: NSObject, ObservableObject, WCSessionDelegate {
    @Published private(set) var status = L("在 iPhone 上打开 Erosion Plus，连接后管理这块手表。")
    @Published private(set) var isConnected = false
    private let access = WatchGestaltAccess()
    private let identifier: String
    private lazy var service = WatchMGService(
        deviceID: identifier,
        read: { try self.access.read() },
        write: { try self.access.write($0) },
        backup: { _ = try WatchBackupStore.create($0, deviceID: self.identifier) }
    )

    override init() {
        let defaults = UserDefaults.standard
        identifier = defaults.string(forKey: "ErosionPlus.WatchDeviceID") ?? UUID().uuidString
        defaults.set(identifier, forKey: "ErosionPlus.WatchDeviceID")
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    private func information() -> [String: Any] {
        ["protocol": WatchMGWire.protocolVersion, "deviceID": identifier,
         "name": WKInterfaceDevice.current().name,
         "version": WKInterfaceDevice.current().systemVersion,
         "build": systemValue("kern.osversion"),
         "hardwareIdentifier": systemValue("hw.machine"),
         "regionIdentifier": Locale.current.region?.identifier ?? ""]
    }

    private func systemValue(_ key: String) -> String {
        var size = 0
        guard sysctlbyname(key, nil, &size, nil, 0) == 0, size > 0 else { return "" }
        var bytes = [CChar](repeating: 0, count: size)
        guard sysctlbyname(key, &bytes, &size, nil, 0) == 0 else { return "" }
        return String(cString: bytes)
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            if let error { status = error.localizedDescription }
            if activationState == .activated { try? session.updateApplicationContext(information()) }
            isConnected = session.isReachable
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in isConnected = session.isReachable }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        Task { @MainActor in
            do {
                if message["operation"] as? String == "info" {
                    replyHandler(information())
                    return
                }
                if message["operation"] as? String == "respring" {
                    guard message["deviceID"] as? String == identifier else {
                        throw WatchMGWire.failure(watchLocalized("The selected Apple Watch has changed. Reload before continuing."))
                    }
                    var error: NSError?
                    guard ErosionWatchStartRespring(&error) else {
                        throw error ?? WatchMGWire.failure(watchLocalized("Could not prepare Watch interface restart."))
                    }
                    replyHandler(["accepted": true])
                    return
                }
                let result = try service.handle(message)
                if result["saved"] as? Bool == true { status = L("修改已保存，正在等待 iPhone 请求刷新手表界面。") }
                replyHandler(result)
            } catch {
                status = error.localizedDescription
                replyHandler(["error": error.localizedDescription])
            }
        }
    }
}
