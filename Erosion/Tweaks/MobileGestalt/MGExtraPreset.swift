// SPDX-License-Identifier: GPL-3.0-only
// Preset values adapted from huamidev/GestaltX, commit 72bf625.
import Foundation

nonisolated enum MGExtraPreset: String, CaseIterable, Identifiable {
    case flipbookCount, parallax, hdrPhotos, displayPort, iPadApps
    case siriAIMode, onDeviceSiri, alwaysListeningSiri, internalSettings

    var id: String { rawValue }
    var key: String {
        switch self {
        case .flipbookCount: "qqrspu7CpuPdZwSDxNY+Fg"
        case .parallax: "UIParallaxCapability"
        case .hdrPhotos: "a1r7npIrhXsZ7SmKRKC1eA"
        case .displayPort: "CoWnN4xo783YGn4wLrUatA"
        case .iPadApps: "9MZ5AdH43csAUajl/dU+IQ"
        case .siriAIMode: "a3n5T9sFtlyQ74NEp9ESxg"
        case .onDeviceSiri: "K/R1GfGfCkXvEhaPS2Vrng"
        case .alwaysListeningSiri: "TusANsf9Lfe3P/9fIXXSrQ"
        case .internalSettings: "Oji6HRoPi7rH7HPdWVakuw"
        }
    }
    var title: String {
        switch self {
        case .flipbookCount: "AOD 翻页组件数量"
        case .parallax: "关闭壁纸视差"
        case .hdrPhotos: "HDR 照片显示"
        case .displayPort: "DisplayPort 视频输出"
        case .iPadApps: "iPad 应用兼容性"
        case .siriAIMode: "Siri AI 模式"
        case .onDeviceSiri: "还原端侧 Siri 能力"
        case .alwaysListeningSiri: "持续监听 Hey Siri"
        case .internalSettings: "Apple 内部设置面板"
        }
    }
    var detail: String {
        switch self {
        case .flipbookCount: "将 AOD 翻页组件数量设为 3；系统和屏幕需支持该功能。"
        case .parallax: "关闭随设备移动的壁纸视差效果。"
        case .hdrPhotos: "启用照片 HDR 显示能力；实际效果取决于屏幕和系统。"
        case .displayPort: "启用视频输出能力标志；仍需兼容的接口和硬件。"
        case .iPadApps: "添加 iPad 应用兼容类型，部分应用的界面可能不适配。"
        case .siriAIMode: "独立设置 Siri 的 AI 模式，可能需要重启和下载资源。"
        case .onDeviceSiri: "端侧 Siri 使用设备专属值，仅支持恢复原始备份中的值和类型。"
        case .alwaysListeningSiri: "启用持续监听能力标志；实际可用性取决于设备。"
        case .internalSettings: "显示系统内部设置入口，属于实验功能。"
        }
    }
    var canEnable: Bool { self != .onDeviceSiri }

    func applying(to current: NSDictionary, original: NSDictionary, restore: Bool) throws -> NSMutableDictionary {
        guard let currentExtra = current["CacheExtra"] as? NSDictionary,
              let originalExtra = original["CacheExtra"] as? NSDictionary else {
            throw MGExtraPresetError.invalidBackup
        }
        guard restore || canEnable else { throw MGExtraPresetError.restoreOnly }
        let result = current.mutableCopy() as! NSMutableDictionary
        let extra = currentExtra.mutableCopy() as! NSMutableDictionary
        if restore {
            if let value = originalExtra[key] { extra[key] = value }
            else { extra.removeObject(forKey: key) }
        } else {
            switch self {
            case .flipbookCount: extra[key] = NSNumber(value: 3)
            case .parallax: extra[key] = NSNumber(value: 0)
            case .iPadApps: extra[key] = [1, 2]
            case .siriAIMode: extra[key] = NSNumber(value: 2)
            case .hdrPhotos, .displayPort, .alwaysListeningSiri, .internalSettings:
                extra[key] = NSNumber(value: 1)
            case .onDeviceSiri: break // The restore-only contract is enforced above.
            }
        }
        result["CacheExtra"] = extra
        return result
    }
}

nonisolated enum MGExtraPresetError: LocalizedError {
    case invalidBackup, restoreOnly
    var errorDescription: String? {
        switch self {
        case .invalidBackup: customizationLocalized("无法读取有效的原始备份，已停止修改预设。")
        case .restoreOnly: customizationLocalized("此项只支持恢复设备原值。")
        }
    }
}
