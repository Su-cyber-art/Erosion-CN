import SwiftUI

struct SettingsView: View {
    @ObservedObject private var languages = LocalizationManager.shared
    @EnvironmentObject private var manager: ErosionManager
    @AppStorage("autoRespring") private var autoRespring = false
    @State private var asksRespring = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        ToolIcon(symbol: "slider.horizontal.3", size: 54)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Erosion Plus").font(.headline)
                            Text("\(AppInfo.appVersion) · Build \(AppInfo.appBuild)").font(.caption).foregroundStyle(.secondary)
                        }
                    }.padding(.vertical, 5)
                }

                Section("偏好设置") {
                    Picker("界面语言", selection: $languages.languageModeRaw) {
                        Text("跟随系统").tag("system")
                        Text("简体中文").tag("zh-Hans")
                        Text("English").tag("en")
                    }
                    Toggle("应用修改后自动注销", isOn: $autoRespring)
                }

                Section("维护") {
                    NavigationLink { RuntimeLogScreen() } label: { Label("运行日志", systemImage: "text.alignleft") }
                    NavigationLink { AdvancedSettingsView() } label: { Label("高级设置", systemImage: "gearshape.2") }
                    Button { asksRespring = true } label: { Label("注销设备界面", systemImage: "arrow.clockwise") }
                    NavigationLink { RestoreToolsView() } label: { Label("恢复与重建", systemImage: "arrow.counterclockwise.shield") }
                }

                Section {
                    NavigationLink { CreditsView() } label: { Label("关于与开源", systemImage: "info.circle") }
                } footer: {
                    Text("基于 Erosion-CN，融合 GestaltX 与 GestaltEdit 的开源功能。")
                }
            }
            .navigationTitle("设置")
            .confirmationDialog("注销设备界面？", isPresented: $asksRespring, titleVisibility: .visible) {
                Button("立即注销") { manager.shouldRespring = true }
            } message: { Text("设备界面将重新载入，请先保存其他应用中的内容。") }
        }
    }
}

private struct AdvancedSettingsView: View {
    @AppStorage(CSStoreEngine.fastScanDefaultsKey) private var fastScan = true
    var body: some View {
        List {
            Section {
                Toggle("CSStore2 快速容器扫描", isOn: $fastScan)
                Button("刷新容器列表缓存") {
                    CSStoreEngine.shared.invalidate()
                    fsHandlers.invalidateCache()
                    Alertinator.shared.alert(title: L("缓存已刷新"), body: L("下次打开工具时会重新读取应用容器信息。"))
                }
            } footer: {
                Text("快速扫描通过 LaunchServices 读取容器信息。遇到兼容问题时可关闭，使用路径扫描。")
            }
            Section("运行环境") {
                LabeledContent("系统版本", value: "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)")
                LabeledContent("硬件标识", value: machineName())
                LabeledContent("系统构建", value: buildNumber())
                Text(group).font(.caption.monospaced()).foregroundStyle(.secondary).textSelection(.enabled)
            }
        }
        .navigationTitle("高级设置")
        .navigationBarTitleDisplayMode(.inline)
    }
}
