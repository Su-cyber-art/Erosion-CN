import SwiftUI

struct WatchPresetsView: View {
    @EnvironmentObject private var model: WatchViewModel
    private var faceSupported: Bool {
        guard let document = model.document else { return false }
        return WatchTweakCatalog.faceLayout(plist: document, build: model.connection.build) != nil
    }

    var body: some View {
        List {
            Section {
                Text("选择预设后会暂存修改，检查变更后再写入手表。恢复原值使用本应用保存的同版本首次备份。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            ForEach(WatchTweakGroup.allCases) { group in
                Section(group.title) {
                    ForEach(WatchTweakCatalog.definitions.filter { $0.group == group }) { preset in
                        WatchPresetRow(preset: preset, faceSupported: faceSupported)
                    }
                }
            }

            Section {
                Menu("地区代码") {
                    ForEach(WatchTweakCatalog.regions, id: \.1) { region in
                        Button(watchLocalized(region.0)) { model.setRegion(code: region.1, sales: nil) }
                    }
                }
                Menu("销售地区") {
                    ForEach(WatchTweakCatalog.regions, id: \.2) { region in
                        Button(watchLocalized(region.0)) { model.setRegion(code: nil, sales: region.2) }
                    }
                }
                Menu("屏幕分辨率") {
                    ForEach(WatchTweakCatalog.resolutions.indices, id: \.self) { index in
                        let choice = WatchTweakCatalog.resolutions[index]
                        Button("\(choice.0) · \(choice.1) × \(choice.2)") { model.setResolution(index) }
                    }
                }
            } header: {
                Text("地区与显示")
            } footer: {
                Text("预设调整功能标记，实际效果取决于手表硬件与系统。表盘布局仅对已验证的系统缓存开放。")
            }
            .disabled(model.isBusy)
        }
        .navigationTitle("表盘与功能预设")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { WatchApplyBar() }
    }
}

private struct WatchPresetRow: View {
    let preset: WatchTweak
    let faceSupported: Bool
    @EnvironmentObject private var model: WatchViewModel
    private var ultraOptions: [Int] {
        guard let document = model.document else { return [] }
        return WatchTweakCatalog.ultraFaceClasses(plist: document, build: model.connection.build)
    }
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(preset.title).font(.body.weight(.medium))
                if preset.isFace && !faceSupported {
                    Text("当前系统的表盘布局暂不支持").font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Menu {
                if preset.id == "ultra" {
                    ForEach(ultraOptions, id: \.self) { value in ultraButton(value) }
                } else {
                    Button("启用预设") { model.applyPreset(preset) }
                }
                Button("还原原值") { model.restorePreset(preset) }
            } label: {
                Label("选择", systemImage: "plus.circle").labelStyle(.iconOnly).font(.title3)
            }
            .disabled(model.isBusy || (preset.isFace && !faceSupported))
            .accessibilityLabel(L("配置 \(preset.title)"))
        }.padding(.vertical, 4)
    }
    private func ultraButton(_ value: Int) -> some View {
        let title: String = L("应用 Ultra 布局 \(value)")
        return Button(title) { model.applyPreset(preset, ultraClass: value) }
    }
}
