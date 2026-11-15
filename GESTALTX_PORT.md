# Erosion Plus：独立版与 GestaltX 移植功能

移植基线：GestaltX `72bf625`，工程版本 1.1.1。

## 独立安装

| 项目 | 独立版配置 |
| --- | --- |
| 桌面名称 | Erosion Plus |
| Bundle ID | `io.github.su-cyber-art.ErosionPlus` |
| App Group | `group.io.github.su-cyber-art.ErosionPlus` |
| 安装包 | `ErosionPlus_v<版本>_Bilingual.ipa` |
| 系统金库 | `.erosion_plus_factory_vault.plist` / `.erosion_plus_factory_vault.sha256` |

可与原版 Erosion-CN 同时安装，应用沙盒、偏好设置、App Group 和系统金库文件名分开。重签时保留独立标识；签名工具若将 Bundle ID 改回原版，仍会按原版应用处理。两款应用操作的是同一台设备上的系统配置，独立安装不会隔离这些系统修改。

Xcode 项目和 scheme 仍名为 `Erosion`，构建产品名为 `ErosionPlus`。更新源只收录经 Bundle ID 核验的独立版安装包；原版历史下载记录已从本分支源文件移除。首次发布前源列表为空。

## 应用启动图

入口：**功能修改 → 外观与桌面定制 → 应用启动图**。

支持搜索应用、查看现有启动图、选择照片、按原图尺寸裁切、保存当前图到照片，以及恢复原图。原图备份保存在目标文件旁，应用重新安装后仍可核验并恢复。系统重新生成的启动图不会被当成旧的修改结果覆盖。操作前请关闭目标应用，修改后重新打开。

## 应用通知铃声

入口：**功能修改 → 外观与桌面定制 → 应用通知铃声**。

支持扫描应用与共享组中的通知音频、试听、导入音频、转换为目标格式、替换和还原；对来自应用包的通知声音，可按实际文件名在应用数据容器创建覆盖文件。还原会区分已有原件与原本不存在的文件。

找不到目标应用时，可从页面右上角进入通知声音采集，按照页面指引完成本机配对和 LocalDevVPN 连接，然后触发一次目标应用通知。停止采集后返回列表，查看识别出的声音。配对或采集由用户主动启动，可随时停止；持久化结果包含应用标识、音频名称和来源，不保存完整设备日志。

## 更多 MG 预设

入口：**MobileGestalt 修改 → 外观与显示特征 → 更多功能预设**。

- AOD 翻页组件数量（3）
- 关闭壁纸视差
- HDR 照片显示
- DisplayPort 视频输出
- iPad 应用兼容性
- Siri AI 模式
- 还原端侧 Siri 能力（仅恢复原值及类型）
- 持续监听 Hey Siri
- Apple 内部设置面板

这些预设先暂存到内存，返回 MG 主页面点击“应用”后进入现有变更预览、写入与校验流程。预设恢复保留原来的类型，原本不存在的键会被移除。功能标记的实际效果仍取决于设备硬件与系统。

## 构建与验证

完整 IPA 构建需要完整 Xcode 和 iOS SDK、Rust、CMake。原生库支持 arm64 iOS 设备与 arm64 模拟器。

```sh
rustup target add aarch64-apple-ios aarch64-apple-ios-sim
./ipabuild.sh
```

`ipabuild.sh` 先从源码生成 `Native/DeviceConsole/build/GXDeviceConsole.xcframework`。直接在 Xcode 构建前，也应先运行 `Native/DeviceConsole/build-xcframework.sh`。不提交生成的二进制库。

主机端回归测试使用临时文件和合成图片／音频，不修改真机容器：

```sh
python3 scripts/test_gestaltx_ports.py
cargo test --locked --no-default-features --manifest-path Native/DeviceConsole/Cargo.toml
```

测试覆盖原文件恢复、重复替换、缓存重新生成、过期选择、符号链接、同名备份冲突、音频格式、通知事件关联、采集结果持久化、MG 暂存与类型保留。主机测试不能验证 iOS 私有 API、真实设备配对或目标应用对修改后资源的加载行为。

源码与许可证说明见 [THIRD_PARTY_NOTICES.md](./THIRD_PARTY_NOTICES.md)。
