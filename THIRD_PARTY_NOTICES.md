# GestaltX 功能移植来源

本次移植来源于 [huamidev/GestaltX](https://github.com/huamidev/GestaltX)，固定提交为 `72bf625befdb5e9e16d52c663e123f9fbc8ec7bf`。

Copyright © 2026 huamidev。GestaltX 应用代码采用 GPL-3.0；完整许可证包含在 `Erosion/Licenses/GestaltX-GPL-3.0.txt`。

移植范围：

- `Erosion/Tweaks/AppCustomization`：应用启动图、通知铃声、原文件备份与恢复、应用列表，以及相关页面。
- `Erosion/Exploits/Customization`：应用容器归属核验与 LaunchServices 元数据解析。
- `Erosion/Helpers/DeviceConsole`：设备配对、通知声音日志解析与采集结果管理。
- `Erosion/Tweaks/MobileGestalt/MGExtraPreset.swift`：额外预设的键值定义与原值恢复语义。
- `tests`：与上述功能对应的主机端回归测试。移除了仅适用于 GestaltX 旧版记录的迁移测试；铃声备份冲突测试验证实际写入被拒绝、目标和无关备份保持完整。

Erosion 的适配包括：复用现有 App Group 探测与 worse_query 入口，独立的本地数据命名空间，中文／英文切换，明确后台模型的 actor 隔离，以及接入现有 MG 变更预览与写入流程。新功能没有 GestaltX 旧版备份记录，因此不包含其旧记录迁移代码。

启动图和铃声的 `.bak` 原件及其扩展属性记录文件归属和原件摘要，用于判断是否可恢复，避免接管其他工具留下的同名备份。相关校验属于文件恢复协议的一部分。

## 本机配对与通知路径采集

`Native/DeviceConsole` 保留 GestaltX 的 Rust 库、C 接口、依赖锁定文件和第三方许可证。它复用了以下 MIT 组件：

- [AirCard-iOS](https://github.com/Mak5er/AirCard-iOS)，Johnny Franks：设备连接和配对工作流参考；许可证为 `Erosion/Licenses/AirCard-MIT.txt`。
- [idevice / idevice-ffi](https://github.com/jkcoxson/idevice)，Jackson Coxson：固定版本 `7bd551c16c6dd2e058740d85a2d9399a51a776e9`，保留上游 OPACK 解码修正；许可证为 `Erosion/Licenses/idevice-MIT.txt` 及 vendored 目录中的 LICENSE。

详细组件说明见 `Native/DeviceConsole/NOTICE.md`。Rust 库用于配对与日志采集，不包含 AirCard 的文件注入组件。
