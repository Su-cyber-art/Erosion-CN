import SwiftUI
import UniformTypeIdentifiers

struct WatchWorkspaceView: View {
    @EnvironmentObject private var model: WatchViewModel
    var body: some View { WatchWorkspaceContent(model: model, connection: model.connection) }
}

private struct WatchWorkspaceContent: View {
    @ObservedObject var model: WatchViewModel
    @ObservedObject var connection: WatchConnection
    @State private var asksReload = false

    var body: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    ToolIcon(symbol: "applewatch", tint: .indigo, size: 58)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(connection.name).font(.headline)
                        Text(statusText).font(.subheadline).foregroundStyle(.secondary)
                        if !connection.version.isEmpty {
                            Text("watchOS \(connection.version)").font(.caption).foregroundStyle(.tertiary)
                        }
                    }
                    Spacer()
                    if model.isBusy { ProgressView() }
                }.padding(.vertical, 8)
                Button {
                    if model.hasChanges { asksReload = true }
                    else { Task { await model.load() } }
                } label: {
                    Label(model.document == nil ? L("读取手表配置") : L("重新读取"), systemImage: "arrow.clockwise")
                }
                .disabled(model.isBusy || !connection.isReachable)
            } footer: {
                Text("在 Apple Watch 上打开 Erosion Plus，并让手表保持在 iPhone 附近。")
            }

            if !connection.isPaired || !connection.isInstalled {
                Section {
                    Label("安装与连接", systemImage: "link").font(.headline)
                    Text(connection.isPaired
                         ? L("请在 iPhone 的 Watch 应用中安装 Erosion Plus 手表端。签名时需要保留安装包内的 Watch 应用。")
                         : L("先在 iPhone 的 Watch 应用中配对 Apple Watch，再安装 Erosion Plus 手表端。"))
                        .font(.subheadline).foregroundStyle(.secondary)
                    Button("打开 Watch 应用") { UIApplication.shared.open(URL(string: "itms-watchs://")!) }
                }
            }

            Section("手表工具") {
                NavigationLink { WatchPresetsView() } label: {
                    ToolRow(title: L("表盘与功能预设"), subtitle: L("Hermès、Ultra、显示与手表能力"), symbol: "applewatch.watchface", tint: .indigo)
                }
                NavigationLink { WatchFieldsView() } label: {
                    ToolRow(title: L("字段编辑"), subtitle: L("查看和编辑手表 CacheExtra"), symbol: "slider.horizontal.3", tint: .orange)
                }
                NavigationLink { WatchBackupsView() } label: {
                    ToolRow(title: L("备份与恢复"), subtitle: L("按手表保存、导入和导出配置"), symbol: "clock.arrow.circlepath", tint: .blue)
                }
            }
            .disabled(model.document == nil || model.isBusy)

            if let document = model.document {
                Section("当前配置") {
                    LabeledContent("缓存字段", value: "\(document.cacheExtra.count)")
                    LabeledContent("系统构建", value: connection.build)
                    LabeledContent("硬件标识", value: connection.hardwareIdentifier)
                }.font(.subheadline)
            }
        }
        .navigationTitle("Apple Watch")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { WatchApplyBar() }
        .task { await model.loadIfReachable() }
        .confirmationDialog("放弃暂存修改并重新读取？", isPresented: $asksReload, titleVisibility: .visible) {
            Button("放弃并重新读取", role: .destructive) { Task { await model.load() } }
        }
    }

    private var statusText: String {
        if !connection.isPaired { return L("尚未配对 Apple Watch") }
        if !connection.isInstalled { return L("需要安装手表端") }
        return connection.isReachable ? L("手表端在线") : L("等待打开手表端")
    }
}

struct WatchApplyBar: View {
    @EnvironmentObject private var model: WatchViewModel
    var body: some View {
        if model.hasChanges {
            HStack(spacing: 12) {
                Button("放弃") { model.discard() }.disabled(model.isBusy)
                Button {
                    do { model.pendingPreview = try model.preview() }
                    catch { model.message = error.localizedDescription }
                } label: {
                    Text("检查 \(model.changes.count) 项更改")
                        .fontWeight(.semibold).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!model.canApply)
            }
            .padding().background(.bar)
        }
    }
}

struct WatchChangesView: View {
    let preview: WatchWritePreview
    @EnvironmentObject private var model: WatchViewModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label(model.connection.name, systemImage: "applewatch")
                } footer: { Text("写入前会备份，完成后读回核验并刷新手表界面。") }
                if preview.changes.isEmpty {
                    ContentUnavailableView("配置已经一致", systemImage: "checkmark.circle", description: Text("这份备份与当前配置一致，无需重复写入。"))
                }
                ForEach(preview.changes) { change in
                    Section {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(change.title).font(.subheadline.weight(.semibold)).textSelection(.enabled)
                            Text(change.before).font(.caption.monospaced()).foregroundStyle(.secondary)
                            Label(change.after, systemImage: "arrow.turn.down.right")
                                .font(.caption.monospaced()).foregroundStyle(.tint)
                        }.padding(.vertical, 5)
                    }
                }
            }
            .navigationTitle("确认手表修改")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() }.disabled(model.isBusy) } }
            .safeAreaInset(edge: .bottom) {
                Button {
                    Task { await model.commit(preview); dismiss() }
                } label: {
                    HStack {
                        if model.isBusy { ProgressView().tint(.white) }
                        Text(model.isBusy ? L("正在写入…") : L("确认写入手表")).fontWeight(.semibold)
                    }.frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isBusy || preview.changes.isEmpty)
                .padding().background(.bar)
            }
            .interactiveDismissDisabled(model.isBusy)
        }
    }
}
