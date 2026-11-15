import SwiftUI

struct RuntimeLogScreen: View {
    @EnvironmentObject private var manager: ErosionManager
    var body: some View {
        ScrollView {
            Text(manager.logOutput.isEmpty ? L("暂无运行日志") : manager.logOutput)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .background(AppDesign.page)
        .navigationTitle("运行日志")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("复制日志", systemImage: "doc.on.doc") { UIPasteboard.general.string = manager.logOutput }
                    ShareLink(item: manager.logOutput) { Label("导出日志", systemImage: "square.and.arrow.up") }
                    Button("清空日志", systemImage: "trash", role: .destructive) { manager.logOutput = "" }
                } label: { Image(systemName: "ellipsis.circle") }
                .accessibilityLabel("日志操作")
            }
        }
    }
}
