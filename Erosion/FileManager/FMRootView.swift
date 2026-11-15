//
//  FMRootView.swift
//  Erosion
//
//  Created by lunginspector on 8/26/26.
//

import SwiftUI

enum FSPaths {
    static let appContainers = "/var/mobile/Containers/Data/Application"
    static var appBundles = "/var/containers/Bundle/Application"
}

enum FSURL {
    static let appContainers = URL(fileURLWithPath: FSPaths.appContainers)
    static var sysGroup = URL(fileURLWithPath: "/var/containers/Shared/SystemGroup")
    static var configProfiles = FSURL.sysGroup.appendingPathComponent("systemgroup.com.apple.configurationprofiles/Library/ConfigurationProfiles")
    static var internalDaemons = URL(fileURLWithPath: "/var/mobile/Containers/Data/InternalDaemon")
    static var appPlugins = URL(fileURLWithPath: "/var/mobile/Containers/Data/PluginKitPlugin")
    static var appGroup = URL(fileURLWithPath: "/var/mobile/Containers/Shared/AppGroup")
    static var systemData = URL(fileURLWithPath: "/var/containers/Data/System")
}

struct FMRootView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("快捷访问") {
                    NavigationLink { FileBrowserView(path: URL.documentsDirectory) } label: {
                        ToolRow(title: L("本应用文件"), subtitle: L("文档、导出文件与配置备份"), symbol: "folder", tint: .blue)
                    }
                    NavigationLink { FileBrowserView(path: MGURL.fsGestaltURL.deletingLastPathComponent(), shouldGrant: true) } label: {
                        ToolRow(title: L("MobileGestalt 缓存"), subtitle: L("查看系统能力缓存目录"), symbol: "slider.horizontal.3")
                    }
                    NavigationLink { FileBrowserView(path: FSURL.configProfiles, shouldGrant: true) } label: {
                        ToolRow(title: L("系统配置文件"), subtitle: L("配置描述与锁屏信息"), symbol: "doc.badge.gearshape", tint: .indigo)
                    }
                }
                Section("应用程序") {
                    container("应用数据", subtitle: "各应用的文档与偏好设置", symbol: "square.stack.3d.up", path: FSURL.appContainers)
                    container("插件数据", subtitle: "应用扩展的独立容器", symbol: "puzzlepiece.extension", path: FSURL.appPlugins)
                    container("共享应用组", subtitle: "应用与扩展共用的文件", symbol: "folder.badge.person.crop", path: FSURL.appGroup)
                }
                Section("系统容器") {
                    container("守护进程", subtitle: "后台服务的数据目录", symbol: "gearshape.2", path: FSURL.internalDaemons)
                    container("系统数据", subtitle: "系统组件的数据容器", symbol: "internaldrive", path: FSURL.systemData)
                    container("系统共享组", subtitle: "系统服务共用的容器", symbol: "folder.badge.gearshape", path: FSURL.sysGroup)
                }
            }
            .navigationTitle("文件")
            .listSectionSpacing(18)
        }
    }

    private func container(_ title: String, subtitle: String, symbol: String, path: URL) -> some View {
        NavigationLink { FileBrowserView(path: path, isContainer: true) } label: {
            ToolRow(title: title.loc, subtitle: subtitle.loc, symbol: symbol, tint: .blue)
        }
    }
}
