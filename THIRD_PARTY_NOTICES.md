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


## Apple Watch 支持（0.11.0）

来源：[frs0n/GestaltEdit](https://github.com/frs0n/GestaltEdit)，固定提交 `b8b9ce47b4d6582098f7744b412cea3272bf13b9`（2.2.1）。代码按 GPL-3.0-or-later 使用，完整许可位于 `Erosion/Licenses/GestaltEdit-GPL-3.0.txt`。

- `Shared/Watch`、`Erosion/Tweaks/Watch`：手表通信协议、系统布局表和手表专属预设。Erosion Plus 增加变更预览、严格类型核验、按布局恢复和原值还原。
- `ErosionWatch/Access`：手表端 App Group 探测和文件访问。实际写入复用 `Shared/InPlaceWrite.swift`，没有采用源项目的先清空文件写法。
- `ErosionWatch/WatchRespring.*` 与 `respring.html`：手表界面刷新实现。
- `tests/WatchMG`、`tests/WatchTweaks`、`tests/WatchCacheLeaseTests.m`：相应回归测试，并增加类型变更拦截测试。

表盘布局及部分能力键参考 pookjw/HermesEnabler（Copyright © 2026 Jinwoo Kim，MIT）；界面刷新参考 Gester（Copyright © 2026 KAMUI contributors，MIT）。许可文件 `HermesEnabler-MIT.txt` 和 `Gester-MIT.txt` 同时包含在 iPhone 与 Watch 应用中。
