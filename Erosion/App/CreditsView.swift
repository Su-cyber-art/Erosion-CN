import SwiftUI

struct CreditsView: View {
    var body: some View {
        List {
            Section { AppInfoCell(build: build) }
                Section {
                    LinkCreditCell(image: Image("lunginspector"), name: "lunginspector", description: "主要开发者与项目维护者", url: "https://github.com/lunginspector")
                    LinkCreditCell(image: Image("forcequit"), name: "forcequit", description: "worse_query 沙盒逃逸漏洞作者", url: "https://github.com/forcequitOS")
                    LinkCreditCell(image: Image("0xjohnny"), name: "0xjohnny", description: "worse_query 沙盒逃逸漏洞作者", url: "https://github.com/0xjohnnydev")
                    LinkCreditCell(image: Image("skadz108"), name: "Skadz", description: "漏洞集成、后端核心功能与项目维护", url: "https://github.com/skadz108")
                    LinkCreditCell(image: Image("rooootdev"), name: "rooootdev", description: "多项后端组件支持", url: "https://github.com/rooootdev")
                    LinkCreditCell(image: Image("neonmodder123"), name: "neonmodder123", description: "WebView 免越狱注销方案作者", url: "https://github.com/neonmodder123")
                    LinkCreditCell(name: "Kianuni — Erosion-CN", description: "中英双语、系统配置与文件管理功能的直接上游", url: "https://github.com/Kianuni/Erosion-CN")
                    LinkCreditCell(name: "frs0n — GestaltEdit", description: "Apple Watch 通信、手表预设与配套应用的移植来源", url: "https://github.com/frs0n/GestaltEdit")
                    LinkCreditCell(name: "huamidev — GestaltX", description: "应用启动图、通知铃声、设备配对及额外 MG 预设的移植来源；动态解析与写入流程参考", url: "https://github.com/huamidev/GestaltX")
                    LinkCreditCell(name: "kolbicz — WQFiles", description: "LaunchServices CSStore2 (bdsl) 容器快速映射与跨容器只读遥测架构设计参考", url: "https://github.com/kolbicz/WQFiles")
                    LinkCreditCell(name: "yangokok886 — WCMigrate", description: "APFS 应用数据暂存与恢复的设计参考", url: "https://github.com/yangokok886/WCMigrate")
                    LinkCreditCell(name: "KirbySD", description: "MobileGestalt CacheData 布尔槽位偏移研究思路分享", url: "https://www.v2ex.com/t/1246550")
                    LinkCreditCell(name: "PoomSmart — MGKeys", description: "MobileGestalt 混淆键值映射表维护与整理", url: "https://github.com/PoomSmart/MGKeys")
                } header: {
                    HeaderLabel("致谢与开源参考", symbol: "star")
                }
                Section {
                    LinkCreditCell(name: "AppleFlow", description: "零 MitM 的 Apple 智能、PCC 与中文 Siri 极简分流方案 & 在线配置体检台", url: "https://github.com/Kianuni/AppleFlow")
                    LinkCreditCell(name: "WQGuard", description: "100% 只读开源的 iOS 沙盒越权检测、侧载 IPA 审查与固件 CVE 防护工具", url: "https://github.com/Kianuni/WQGuard")
                    LinkCreditCell(name: "Camlo · 开幕", description: "免电脑一键换上滑动解锁变身、裸眼 3D 与动态锁屏壁纸", url: "https://github.com/Kianuni/Camlo")
                    LinkCreditCell(name: "Enkard", description: "纯离线、零云同步、绑定 Secure Enclave 的 iPhone 银行级加密卡包", url: "https://github.com/Kianuni/Enkard")
                } header: {
                    HeaderLabel("更多开源项目 (Kianuni)", symbol: "sparkles")
                }
        }
        .navigationTitle("关于与开源")
        .navigationBarTitleDisplayMode(.inline)
    }
}
