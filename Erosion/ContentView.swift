import SwiftUI

struct ContentView: View {
    @AppStorage("ogMachineName") private var originalMachine = ""
    @EnvironmentObject private var watchModel: WatchViewModel
    @ObservedObject private var stagingVault = APFSStagingVault.shared
    private let shortcuts: [AppTool] = [.launchImages, .sounds, .backups, .cacheCleaner]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    statusMessages

                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 14) {
                            ToolIcon(symbol: isPad() ? "ipad" : "iphone", size: 52)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(UIDevice.current.name).font(.headline)
                                Text("\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 4)
                            Text("本机").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                        }
                        if !isPad() {
                            Divider()
                            NavigationLink { WatchWorkspaceView() } label: {
                                WatchConnectionRow(connection: watchModel.connection)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .appCard()

                    NavigationLink { AppToolDestination(tool: .gestalt) } label: {
                        HStack(alignment: .top, spacing: 16) {
                            ToolIcon(symbol: "slider.horizontal.3", size: 52)
                            VStack(alignment: .leading, spacing: 6) {
                                Text("MobileGestalt").font(.title3.weight(.semibold)).foregroundStyle(.primary)
                                Text("集中管理设备功能、地区与高级预设")
                                    .font(.subheadline).foregroundStyle(.secondary)
                                Text(AppTool.gestalt.isAvailable ? L("打开系统能力") : L("需要 iOS 27 或更高版本"))
                                    .font(.caption.weight(.semibold)).foregroundStyle(.tint).padding(.top, 4)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "arrow.up.right").font(.subheadline.weight(.semibold)).foregroundStyle(.tint)
                        }
                        .appCard()
                    }
                    .buttonStyle(.plain)
                    .disabled(!AppTool.gestalt.isAvailable)

                    VStack(spacing: 12) {
                        DashboardHeading(title: L("常用工具"))
                        LazyVGrid(columns: [GridItem(.flexible(), alignment: .top), GridItem(.flexible(), alignment: .top)], spacing: 12) {
                            ForEach(shortcuts) { tool in
                                NavigationLink { AppToolDestination(tool: tool) } label: {
                                    VStack(alignment: .leading, spacing: 12) {
                                        ToolIcon(symbol: tool.symbol, tint: tool.category.tint)
                                        Text(tool.title).font(.headline).foregroundStyle(.primary)
                                        Text(tool.subtitle).font(.caption).foregroundStyle(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 116, alignment: .topLeading)
                                    .appCard()
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    VStack(spacing: 0) {
                        homeLink(.pairing)
                        Divider().padding(.leading, 72)
                        homeLink(.logs)
                    }
                    .background(AppDesign.card, in: RoundedRectangle(cornerRadius: AppDesign.radius, style: .continuous))

                    Text("Erosion Plus · \(AppInfo.appVersion)")
                        .font(.caption).foregroundStyle(.tertiary).padding(.bottom, 8)
                }
                .padding(AppDesign.spacing)
                .frame(maxWidth: 820)
                .frame(maxWidth: .infinity)
            }
            .background(AppDesign.page)
            .navigationTitle("Erosion Plus")
            .onAppear { if originalMachine.isEmpty { originalMachine = machineName() } }
        }
    }

    @ViewBuilder
    private var statusMessages: some View {
        if isWorseQueryPatchedOS() {
            CompactAlert(
                title: LocalizationManager.isEnglish
                    ? "worse_query Patched on This iOS Build"
                    : "当前系统版本已封堵 worse_query 漏洞",
                symbol: "exclamationmark.octagon.fill",
                text: LocalizationManager.isEnglish
                    ? "Apple patched worse_query in iOS 27.3 beta 2+ and 26.7.3+. MobileGestalt and cross-container changes are unavailable on this build. The highest supported version is iOS 27.3 beta 1."
                    : "Apple 已于 iOS 27.3 beta 2+ 及 26.7.3+ 封堵 worse_query 漏洞，当前系统无法写入 MobileGestalt 或跨容器修改文件。最高支持至 iOS 27.3 beta 1。",
                color: .red
            )
        }

        if isRunningInLiveContainer() {
            CompactAlert(
                title: LocalizationManager.isEnglish ? "Running Inside LiveContainer" : "当前运行在 LiveContainer 内",
                symbol: "shippingbox.circle.fill",
                text: LocalizationManager.isEnglish
                    ? "If container authorization fails, check the host App Group configuration in LiveContainer's app settings, or install Erosion Plus as a standalone app."
                    : "若遇容器授权失败，请在 LiveContainer 应用设置中检查宿主 App Group 配置，或独立侧载安装 Erosion Plus。",
                color: .orange
            )
        }

        if stagingVault.activeStagedItemsCount > 0 {
            VStack(alignment: .leading, spacing: 12) {
                CompactAlert(
                    title: LocalizationManager.isEnglish
                        ? "Keep Erosion Plus Installed (\(stagingVault.activeStagedItemsCount) Staged)"
                        : "请保留 Erosion Plus（\(stagingVault.activeStagedItemsCount) 份待还原数据）",
                    symbol: "externaldrive.badge.exclamationmark",
                    text: LocalizationManager.isEnglish
                        ? "The APFS vault contains app data awaiting restore. Restore and verify the data in Save Manager, then release the vault before uninstalling Erosion Plus."
                        : "APFS 暂存舱中有应用数据等待还原。请在存档管理中完成还原并确认数据完整，释放暂存舱后再卸载 Erosion Plus。",
                    color: .orange
                )
                NavigationLink { AppDataBackupView() } label: {
                    Label(AppTool.backups.title, systemImage: AppTool.backups.symbol)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func homeLink(_ tool: AppTool) -> some View {
        NavigationLink { AppToolDestination(tool: tool) } label: {
            HStack {
                ToolRow(title: tool.title, subtitle: tool.subtitle, symbol: tool.symbol, tint: tool.category.tint)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }
}

struct WatchConnectionRow: View {
    @ObservedObject var connection: WatchConnection
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "applewatch").font(.title3).foregroundStyle(.indigo)
            Text("Apple Watch").font(.subheadline.weight(.medium))
            Spacer()
            Text(connection.isReachable ? L("可连接") : L("管理手表"))
                .font(.caption).foregroundStyle(.secondary)
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }
}
