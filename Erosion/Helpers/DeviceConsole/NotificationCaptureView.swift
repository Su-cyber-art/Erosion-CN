// SPDX-License-Identifier: GPL-3.0-only
// Adapted from huamidev/GestaltX, commit 72bf625. See THIRD_PARTY_NOTICES.md.
import SwiftUI

/// Capture lives with the audio library, while pairing stays a separate
/// device-level feature. The sheet only reads the shared pairing record.
struct NotificationCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var connection = DeviceConnectionModel()
    @StateObject private var capture = NotificationSoundCaptureModel()
    @State private var isStarting = false

    var body: some View {
        List {
            if !connection.consoleAvailable {
                Section {
                    Label(customizationLocalized("The device console is not available in this build."), systemImage: "bolt.slash")
                        .foregroundStyle(.secondary)
                }
            }
            pairingSection
            if case .paired = connection.state {
                captureSection
                if !capture.capturedSounds.isEmpty { capturedSection }
            }
        }
        .navigationTitle(customizationLocalized("Capture Notification Sounds"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(customizationLocalized("Done")) { dismiss() }
            }
        }
        .task {
            connection.load()
            capture.loadCached()
            while !Task.isCancelled {
                if case .paired = connection.state {
                    _ = await connection.checkVPN(showProgress: false)
                }
                try? await Task.sleep(for: .seconds(5))
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, case .paired = connection.state {
                Task {
                    let host = await connection.checkVPN(showProgress: false)
                    if capture.state == .connecting, host == nil {
                        capture.abortConnecting(customizationLocalized("Cannot reach the device console. Open LocalDevVPN, wait for it to connect, then try again."))
                    }
                }
            }
        }
        .alert(customizationLocalized("Erosion Plus"), isPresented: Binding(get: { connection.message != nil }, set: { if !$0 { connection.message = nil } })) {
            Button(customizationLocalized("OK"), role: .cancel) { connection.message = nil }
        } message: { Text(connection.message ?? "") }
        .alert(customizationLocalized("Erosion Plus"), isPresented: Binding(get: { capture.message != nil }, set: { if !$0 { capture.message = nil } })) {
            Button(customizationLocalized("OK"), role: .cancel) { capture.message = nil }
        } message: { Text(capture.message ?? "") }
    }

    @ViewBuilder private var pairingSection: some View {
        switch connection.state {
        case .paired:
            Section(customizationLocalized("Device Pairing")) {
                if let record = connection.record {
                    LabeledContent(customizationLocalized("Device")) { Text(record.deviceName).foregroundStyle(.secondary) }
                }
            }
        case .advertising, .pairing:
            Section(customizationLocalized("Device Pairing")) {
                HStack(spacing: 10) {
                    ProgressView()
                    Text(customizationLocalized("Pairing is in progress. Finish it in Tools → Device Pairing."))
                        .font(.footnote)
                }
                NavigationLink { DeviceConnectionView() } label: {
                    Label(customizationLocalized("Open Device Pairing"), systemImage: "link")
                }
            }
        case .idle, .failed:
            Section(customizationLocalized("Device Pairing")) {
                Text(customizationLocalized("Pair once before capturing."))
                    .font(.footnote).foregroundStyle(.secondary)
                NavigationLink { DeviceConnectionView() } label: {
                    Label(customizationLocalized("Open Device Pairing"), systemImage: "link")
                }
            }
        }
    }

    @ViewBuilder private var captureSection: some View {
        Section(customizationLocalized("Capture")) {
            LabeledContent(customizationLocalized("Loopback VPN")) {
                Text(vpnStatusText)
                    .foregroundStyle(connection.vpnState == .unavailable ? .red : .secondary)
            }
            if connection.vpnState == .unavailable {
                Button { connection.openLocalDevVPN() } label: {
                    Label(customizationLocalized("Open LocalDevVPN"), systemImage: "arrow.up.forward.app")
                }
            }
            switch capture.state {
            case .connecting:
                HStack { ProgressView(); Text(customizationLocalized("Connecting…")) }
                Text(customizationLocalized("If this stays here, open LocalDevVPN and wait for it to finish connecting."))
                    .font(.footnote).foregroundStyle(.secondary)
                if connection.vpnState == .unavailable {
                    Button { connection.openLocalDevVPN() } label: {
                        Label(customizationLocalized("Open LocalDevVPN"), systemImage: "arrow.up.forward.app")
                    }
                }
                Button(role: .cancel) { capture.stop() } label: { Text(customizationLocalized("Stop Capture")) }
            case .capturing:
                HStack { ProgressView(); Text(customizationLocalized("Capturing…")) }
                LabeledContent(customizationLocalized("Captured")) {
                    Text("\(capture.capturedAppCount) / \(capture.capturedSounds.count)").foregroundStyle(.secondary)
                }
                Button(role: .cancel) { capture.stop() } label: { Label(customizationLocalized("Stop Capture"), systemImage: "stop.fill") }
            default:
                if isStarting {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text(customizationLocalized("Checking…"))
                    }
                    .foregroundStyle(.secondary)
                } else {
                    Button { startCapture() } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "dot.radiowaves.left.and.right")
                            Text(customizationLocalized("Start Capture")).fontWeight(.semibold)
                            Spacer(minLength: 0)
                        }
                        .foregroundStyle(.tint)
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }

    @ViewBuilder private var capturedSection: some View {
        Section(customizationLocalized("Captured Notification Sounds")) {
            ForEach(capture.capturedSounds) { sound in
                VStack(alignment: .leading, spacing: 4) {
                    Text(sound.bundleID).lineLimit(1)
                    Text(sound.representsReplaceableFile ? sound.filename : customizationLocalized("System default (not replaceable)"))
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
        }
    }

    private var vpnStatusText: String {
        switch connection.vpnState {
        case .unknown: return customizationLocalized("Not checked")
        case .checking: return customizationLocalized("Checking…")
        case .ready(let host): return "\(customizationLocalized("Connected")) · \(host)"
        case .unavailable: return customizationLocalized("Not reachable")
        }
    }

    private func startCapture() {
        guard !isStarting else { return }
        isStarting = true
        Task {
            defer { isStarting = false }
            guard let path = await connection.currentPairingPath() else {
                connection.message = customizationLocalized("The saved pairing file is missing. Pair this iPhone again before capturing.")
                return
            }
            guard let host = await connection.checkVPN() else {
                connection.message = customizationLocalized("Loopback VPN is not reachable. Open LocalDevVPN, wait until it connects, then try again.")
                return
            }
            capture.start(pairingPath: path, loopbackHost: host)
        }
    }
}
