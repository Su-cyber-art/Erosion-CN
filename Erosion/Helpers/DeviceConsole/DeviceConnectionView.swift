// SPDX-License-Identifier: GPL-3.0-only
// Adapted from huamidev/GestaltX, commit 72bf625. See THIRD_PARTY_NOTICES.md.
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Device-level pairing. Capture and VPN status live with the audio library;
/// other features reuse this same pairing record.
struct DeviceConnectionView: View {
    @StateObject private var connection = DeviceConnectionModel()
    @State private var copiedCode = false

    var body: some View {
        List {
            if !connection.consoleAvailable {
                Section {
                    Label(customizationLocalized("The device console is not available in this build."), systemImage: "bolt.slash")
                        .foregroundStyle(.secondary)
                } footer: {
                    Text(customizationLocalized("Build the GXDeviceConsole library and enable it to use pairing and capture."))
                }
            }

            pairingSection
        }
        .navigationTitle(customizationLocalized("Device Pairing"))
        .navigationBarTitleDisplayMode(.inline)
        .task { connection.load() }
        .alert(customizationLocalized("Erosion Plus"), isPresented: Binding(get: { connection.message != nil }, set: { if !$0 { connection.message = nil } })) {
            Button(customizationLocalized("OK"), role: .cancel) { connection.message = nil }
        } message: { Text(connection.message ?? "") }
    }

    // MARK: - Pairing

    @ViewBuilder private var pairingSection: some View {
        Section(customizationLocalized("Pairing")) {
            switch connection.state {
            case .idle, .failed:
                pairingInstructions
                pairingCodePlaceholder
                Button { connection.beginPairing() } label: { Label(customizationLocalized("Start Pairing"), systemImage: "link") }
                    .disabled(connection.busy || !connection.consoleAvailable)
            case .advertising:
                pairingInstructions
                HStack(spacing: 12) {
                    ProgressView()
                    VStack(alignment: .leading, spacing: 3) {
                        Text(customizationLocalized("Broadcasting as Erosion")).font(.headline)
                        Text(customizationLocalized("Privacy & Security → Developer Mode")).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
                Button { openDeveloperSettings() } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "gear")
                        Text(customizationLocalized("Open Settings")).fontWeight(.semibold)
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.accentColor)
                    )
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowSeparator(.hidden)
                pairingCodePlaceholder
                Button(role: .cancel) { connection.cancel() } label: { Text(customizationLocalized("Cancel")) }
            case .pairing:
                if let pin = connection.pin {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "link.badge.plus").foregroundStyle(.tint)
                            Text(customizationLocalized("Pairing Code")).font(.headline)
                            Spacer()
                            Image(systemName: "iphone").foregroundStyle(.secondary)
                        }
                        Text(PairingNotifier.formatted(pin))
                            .font(.system(size: 46, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 8)
                        Text(customizationLocalized("Enter this code in Settings to finish pairing."))
                            .font(.footnote)
                        HStack {
                            Button {
                                UIPasteboard.general.string = pin.filter(\.isNumber)
                                copiedCode = true
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copiedCode = false }
                            } label: {
                                Label(copiedCode ? customizationLocalized("Copied") : customizationLocalized("Copy Code"),
                                      systemImage: copiedCode ? "checkmark" : "doc.on.doc")
                            }
                            .buttonStyle(.bordered)
                            Spacer()
                            Text(customizationLocalized("Dynamic Island + notification")).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                Button(role: .cancel) { connection.cancel() } label: { Text(customizationLocalized("Cancel")) }
            case .paired:
                if let record = connection.record {
                    LabeledContent(customizationLocalized("Device")) { Text(record.deviceName).foregroundStyle(.secondary) }
                    LabeledContent(customizationLocalized("Model")) { Text(record.deviceModel).foregroundStyle(.secondary) }
                }
                Button(role: .destructive) { connection.clearPairing() } label: { Label(customizationLocalized("Forget Pairing"), systemImage: "trash") }
                    .tint(.red)
            }
        }
    }

    private var pairingInstructions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(customizationLocalized("Pair this iPhone once"))
                .font(.headline)
            stepRow(1, customizationLocalized("Privacy & Security → Developer Mode"))
            stepRow(2, customizationLocalized("Tap Pair with Erosion"))
            stepRow(3, customizationLocalized("Enter the 6-digit code shown below, in the Dynamic Island, or in the notification"))
        }
        .font(.footnote)
    }

    private func stepRow(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(number)")
                .font(.caption.bold().monospacedDigit())
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.accentColor.opacity(0.15)))
                .foregroundStyle(.tint)
            Text(text).foregroundStyle(.secondary)
        }
    }

    private var pairingCodePlaceholder: some View {
        VStack(spacing: 6) {
            Text("••• •••")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.tertiary)
            Text(customizationLocalized("The pairing code appears here, in the Dynamic Island, and as a notification."))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    /// Developer Mode lives under Privacy & Security. The private prefs URL is
    /// best effort; if iOS refuses it we fall back to the app's Settings page.
    private func openDeveloperSettings() {
        #if canImport(UIKit)
        let candidates = [
            "App-Prefs:root=Privacy&path=DEVELOPER",
            "App-Prefs:Privacy&path=Developer",
            "App-Prefs:root=Privacy&path=Developer"
        ]
        for string in candidates {
            guard let url = URL(string: string) else { continue }
            UIApplication.shared.open(url, options: [:]) { opened in
                if !opened, let settings = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settings)
                }
            }
            return
        }
        if let settings = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settings)
        }
        #endif
    }

}
