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
                } header: {
                    HeaderLabel("上游项目作者 (jailbreak.party)", symbol: "star")
                }

                Section {
                    LinkCreditCell(name: "frs0n — GestaltEdit", description: "Apple Watch 通信、手表预设与配套应用的移植来源", url: "https://github.com/frs0n/GestaltEdit")
                    LinkCreditCell(name: "huamidev — GestaltX", description: "应用启动图、通知铃声、设备配对及额外 MG 预设的移植来源；动态解析与写入流程参考", url: "https://github.com/huamidev/GestaltX")
                    LinkCreditCell(name: "kolbicz — WQFiles", description: "LaunchServices CSStore2 (bdsl) 容器快速映射与跨容器只读遥测架构设计参考", url: "https://github.com/kolbicz/WQFiles")
                    LinkCreditCell(name: "KirbySD", description: "MobileGestalt CacheData 布尔槽位偏移研究思路分享", url: "https://www.v2ex.com/t/1246550")
                    LinkCreditCell(name: "PoomSmart — MGKeys", description: "MobileGestalt 混淆键值映射表维护与整理", url: "https://github.com/PoomSmart/MGKeys")
                } header: {
                    HeaderLabel("特别致谢与特性参考", symbol: "heart")
                }
        }
        .navigationTitle("关于与开源")
        .navigationBarTitleDisplayMode(.inline)
    }
}
