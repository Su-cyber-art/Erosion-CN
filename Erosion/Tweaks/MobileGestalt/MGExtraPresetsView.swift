import SwiftUI

struct MGExtraPresetsView: View {
    @ObservedObject private var store = GestaltStore.shared
    @State private var message: String?

    var body: some View {
        List {
            Section {
                Text("更改会暂存到当前配置。返回 MobileGestalt 页面，点击「应用」查看变更并写入。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            ForEach(MGExtraPreset.allCases) { preset in
                Section {
                    LabeledContent("当前值", value: mgFormatValue(store.cacheExtra[preset.key]))
                    if preset.canEnable {
                        Button("启用预设") { stage(preset, restore: false) }
                    }
                    Button("还原原值") { stage(preset, restore: true) }
                } header: {
                    Text(customizationLocalized(preset.title))
                } footer: {
                    Text(customizationLocalized(preset.detail))
                }
            }
        }
        .navigationTitle("更多功能预设")
        .navigationBarTitleDisplayMode(.inline)
        .alert("无法修改预设", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("好", role: .cancel) { message = nil }
        } message: { Text(message ?? "") }
    }

    private func stage(_ preset: MGExtraPreset, restore: Bool) {
        do {
            guard let original = NSDictionary(contentsOf: MGURL.savedGestaltURL) else {
                throw MGExtraPresetError.invalidBackup
            }
            store.mgCurrentDict = try preset.applying(to: store.mgCurrentDict, original: original, restore: restore)
        } catch { message = error.localizedDescription }
    }
}
