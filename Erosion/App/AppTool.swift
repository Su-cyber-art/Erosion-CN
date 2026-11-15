import SwiftUI

enum ToolCategory: String, CaseIterable, Identifiable {
    case system, appearance, data, diagnostics, connections
    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: L("系统能力")
        case .appearance: L("外观与声音")
        case .data: L("数据与存储")
        case .diagnostics: L("诊断与导出")
        case .connections: L("设备连接")
        }
    }
    var tint: Color {
        switch self {
        case .system: .accentColor
        case .appearance: .purple
        case .data: .blue
        case .diagnostics: .teal
        case .connections: .indigo
        }
    }
}

enum AppTool: String, CaseIterable, Identifiable {
    case gestalt, systemConfig, fileReplacement, wallpapers, keypads, launchImages, sounds
    case backups, cacheCleaner, power, crashes, appGroups, recordings, pairing, watch, logs
    var id: String { rawValue }
    var title: String {
        switch self {
        case .gestalt: "MobileGestalt"
        case .systemConfig: L("锁屏与系统配置")
        case .fileReplacement: L("文件替换")
        case .wallpapers: L("锁屏壁纸")
        case .keypads: L("拨号键盘")
        case .launchImages: L("应用启动图")
        case .sounds: L("通知铃声")
        case .backups: L("存档管理")
        case .cacheCleaner: L("缓存清理")
        case .power: L("电池与温控")
        case .crashes: L("崩溃分析")
        case .appGroups: L("分流与书签")
        case .recordings: L("录音与 AI 资源")
        case .pairing: L("本机配对")
        case .watch: "Apple Watch"
        case .logs: L("运行日志")
        }
    }
    var subtitle: String {
        switch self {
        case .gestalt: L("设备功能、地区与高级预设")
        case .systemConfig: L("锁屏文字、铭牌与监管检查")
        case .fileReplacement: L("导入并替换指定文件")
        case .wallpapers: L("导入和管理锁屏壁纸")
        case .keypads: L("调整拨号键盘外观")
        case .launchImages: L("自定义应用打开时的画面")
        case .sounds: L("试听、替换和还原通知声音")
        case .backups: L("备份、还原应用与游戏数据")
        case .cacheCleaner: L("查看并释放容器缓存空间")
        case .power: L("电池状态与温度记录")
        case .crashes: L("查看崩溃和内存终止记录")
        case .appGroups: L("导出分流规则与 Safari 书签")
        case .recordings: L("导出录音、检查离线资源")
        case .pairing: L("为通知声音路径采集配对")
        case .watch: L("表盘、手表预设与配置备份")
        case .logs: L("查看运行情况与排查问题")
        }
    }
    var symbol: String {
        switch self {
        case .gestalt: "slider.horizontal.3"
        case .systemConfig: "lock.iphone"
        case .fileReplacement: "doc.on.doc"
        case .wallpapers: "photo.on.rectangle.angled"
        case .keypads: "circle.grid.3x3"
        case .launchImages: "app.badge"
        case .sounds: "bell.badge"
        case .backups: "externaldrive"
        case .cacheCleaner: "sparkles"
        case .power: "battery.75percent"
        case .crashes: "waveform.path.ecg"
        case .appGroups: "network"
        case .recordings: "waveform"
        case .pairing: "link"
        case .watch: "applewatch"
        case .logs: "text.alignleft"
        }
    }
    var category: ToolCategory {
        switch self {
        case .gestalt, .systemConfig, .fileReplacement: .system
        case .wallpapers, .keypads, .launchImages, .sounds: .appearance
        case .backups, .cacheCleaner: .data
        case .power, .crashes, .appGroups, .recordings, .logs: .diagnostics
        case .pairing, .watch: .connections
        }
    }
    var isAvailable: Bool { self != .gestalt || raveSupported() || weOnADebugBuild }
}

struct AppToolDestination: View {
    let tool: AppTool
    @EnvironmentObject private var launchCatalog: LaunchArtworkCatalogModel
    var body: some View {
        switch tool {
        case .gestalt: GestaltView()
        case .systemConfig: ConfigView()
        case .fileReplacement: OperationsView()
        case .wallpapers: PosterBoardView()
        case .keypads: KeypadView()
        case .launchImages: LaunchArtworkApplicationsView(catalog: launchCatalog)
        case .sounds: AppSoundApplicationsView()
        case .backups: AppDataBackupView()
        case .cacheCleaner: CacheCleanerView()
        case .power: PowerTelemetryView()
        case .crashes: CrashDiagnosticsView()
        case .appGroups: AppGroupHubView()
        case .recordings: VoiceMemosAIView()
        case .pairing: DeviceConnectionView()
        case .watch: WatchWorkspaceView()
        case .logs: RuntimeLogScreen()
        }
    }
}
