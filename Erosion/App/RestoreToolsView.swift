import SwiftUI

struct RestoreToolsView: View {
    @EnvironmentObject private var mgr: ErosionManager
    var body: some View {
        List {
            Section {
                ToolRow(title: L("恢复原机配置"), subtitle: L("使用原始备份还原本机 MobileGestalt，并清理已应用的外观修改。"), symbol: "arrow.counterclockwise.shield")
            }
            Section {
                Button("一键恢复原机出厂参数", role: .destructive) { promptGlobalFactoryRestore() }
            } footer: {
                Text("操作前会核对原始备份与当前设备；确认恢复后才会写入。")
            }
        }
        .navigationTitle("恢复与重建")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func promptGlobalFactoryRestore() {
        Alertinator.shared.alert(
            title: "确认一键恢复原机出厂参数？",
            body: MGMsg.globalFactoryRestoreConfirm,
            actionLabel: "确认恢复出厂参数",
            action: {
                switch mgExecuteFactoryRestore(alsoResetConfigAndKeypad: true) {
                case .restoredSuccessfully(let details):
                    Haptic.shared.play(.soft)
                    Alertinator.shared.alert(
                        title: "已恢复原机出厂参数！",
                        body: details,
                        actionLabel: "立即注销",
                        action: { mgr.shouldRespring = true }
                    )
                case .blockedNeedsCleanRebuild(let title, let reason):
                    Alertinator.shared.alert(
                        title: title,
                        body: reason,
                        actionLabel: "重建系统纯净原厂缓存",
                        action: {
                            switch mgExecuteCleanCacheRebuild(alsoResetConfigAndKeypad: true) {
                            case .success:
                                Alertinator.shared.alert(
                                    title: "已准备原厂缓存重建！",
                                    body: MGMsg.mgResetComp,
                                    showCancel: false,
                                    actionLabel: "退出并手动重启",
                                    action: { exitinator() }
                                )
                            case .failure(let err):
                                Alertinator.shared.alert(title: "重建缓存失败！", body: err.localizedDescription)
                            }
                        }
                    )
                case .failed(let reason):
                    Alertinator.shared.alert(title: "恢复原机出厂参数失败！", body: reason)
                }
            }
        )
    }
}
