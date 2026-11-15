import SwiftUI
import UniformTypeIdentifiers

struct WatchBackupsView: View {
    @EnvironmentObject private var model: WatchViewModel
    @State private var importsBackup = false
    @State private var restore: WatchBackup?
    @State private var removal: WatchBackup?
    var body: some View {
        List {
            Section {
                Button { Task { await model.createBackup() } } label: { Label("备份手表当前配置", systemImage: "plus.circle") }
                Button { importsBackup = true } label: { Label("导入备份", systemImage: "square.and.arrow.down") }
            }.disabled(model.isBusy)

            Section {
                ForEach(model.backups) { backup in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(backup.date, format: .dateTime.year().month().day().hour().minute()).font(.subheadline.weight(.medium))
                                Text(ByteCountFormatter.string(fromByteCount: Int64(backup.size), countStyle: .file)).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if model.isInitialBackup(backup) { Text("初始备份").font(.caption).foregroundStyle(.tint) }
                        }
                        HStack(spacing: 20) {
                            Button("恢复") { restore = backup }.buttonStyle(.borderless)
                            ShareLink(item: backup.url) { Text("导出") }.buttonStyle(.borderless)
                            Spacer()
                            if !model.isInitialBackup(backup) {
                                Button(role: .destructive) { removal = backup } label: { Image(systemName: "trash") }
                                    .buttonStyle(.borderless).accessibilityLabel("删除备份")
                            }
                        }.font(.subheadline)
                    }.padding(.vertical, 5)
                }
            } footer: {
                Text("备份按手表分别保存。初始备份用于预设原值恢复，其他历史备份可删除。")
            }
            .disabled(model.isBusy)
        }
        .navigationTitle("手表备份")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented: $importsBackup, allowedContentTypes: [.propertyList, .data]) { result in
            switch result {
            case .success(let url): model.importBackup(url)
            case .failure(let error): model.message = error.localizedDescription
            }
        }
        .confirmationDialog("恢复此备份？", isPresented: Binding(get: { restore != nil }, set: { if !$0 { restore = nil } }), titleVisibility: .visible) {
            Button("检查恢复内容") {
                guard let backup = restore else { return }
                do { model.pendingPreview = try model.preview(restoring: backup) }
                catch { model.message = error.localizedDescription }
                restore = nil
            }
        } message: { Text("确认写入后，备份内容将替换手表配置和当前暂存修改。") }
        .confirmationDialog("删除此备份？", isPresented: Binding(get: { removal != nil }, set: { if !$0 { removal = nil } }), titleVisibility: .visible) {
            Button("删除", role: .destructive) { if let removal { model.deleteBackup(removal) }; removal = nil }
        }
    }
}
