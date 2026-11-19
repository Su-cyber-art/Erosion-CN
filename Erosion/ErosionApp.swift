//
//  ErosionApp.swift
//  Erosion
//
//  Created by lunginspector on 8/14/26.
//

import SwiftUI
import Combine
import UniformTypeIdentifiers

let device = UIDevice.current
let fm = FileManager.default
var weOnADebugBuild = false
var pipe = Pipe()
var sema = DispatchSemaphore(value: 0)

@main
struct ErosionApp: App {
    @StateObject private var mgr = ErosionManager.shared
    @StateObject private var langMgr = LocalizationManager.shared
    @StateObject private var watchModel = WatchViewModel()
    @StateObject private var launchCatalog = LaunchArtworkCatalogModel()
    @State private var currentTab = 0
    @State private var didBootstrapLogs = false
    
    init() {
        #if targetEnvironment(simulator)
        if let index = ProcessInfo.processInfo.arguments.firstIndex(of: "--preview-tab"),
           ProcessInfo.processInfo.arguments.indices.contains(index + 1),
           let tab = Int(ProcessInfo.processInfo.arguments[index + 1]), (0...3).contains(tab) {
            _currentTab = State(initialValue: tab)
        }
        #endif
        DeviceConsolePaths.configureIdentity()
        DeviceConsoleBackgroundTask.shared.registerIfNeeded()
        Task {
            let pairing = DevicePairingStore(directory: DeviceConsolePaths.pairing,
                                             device: DeviceConsolePaths.deviceIdentifier)
            _ = await pairing.currentPairingPath()
        }
        UserDefaults.standard.register(defaults: [
            "mgWriteAtomically": true,
            "maxInode": 15000000
        ])
        if !UserDefaults.standard.bool(forKey: "mgAtomicDefaultMigrated") {
            UserDefaults.standard.set(true, forKey: "mgWriteAtomically")
            UserDefaults.standard.set(true, forKey: "mgAtomicDefaultMigrated")
        }
        
        setvbuf(stdout, nil, _IONBF, 0)
        dup2(pipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)
        
        // fix file picker
        let fixMethod = class_getInstanceMethod(UIDocumentPickerViewController.self, #selector(UIDocumentPickerViewController.fix_init(forOpeningContentTypes:asCopy:)))!
        let origMethod = class_getInstanceMethod(UIDocumentPickerViewController.self, #selector(UIDocumentPickerViewController.init(forOpeningContentTypes:asCopy:)))!
        method_exchangeImplementations(origMethod, fixMethod)
        
        #if DEBUG
        weOnADebugBuild = true
        #else
        weOnADebugBuild = false
        #endif
    }
    
    var body: some Scene {
        WindowGroup {
            TabView(selection: $currentTab) {
                ContentView()
                    .tabItem {
                        Label("主页", systemImage: "house")
                    }
                    .tag(0)
                TweaksView()
                    .tabItem {
                        Label("工具", systemImage: "square.grid.2x2")
                    }
                    .tag(1)
                FMRootView()
                    .tabItem {
                        Label("文件", systemImage: "folder")
                    }
                    .tag(2)
                SettingsView()
                    .tabItem { Label("设置", systemImage: "gearshape") }
                    .tag(3)
            }
            .id(langMgr.refreshID)
            .environment(\.locale, langMgr.effectiveLocale)
            .environmentObject(mgr)
            .environmentObject(watchModel)
            .environmentObject(launchCatalog)
            .sheet(item: $watchModel.pendingPreview) { preview in
                WatchChangesView(preview: preview)
                    .environmentObject(watchModel)
                    .environment(\.locale, langMgr.effectiveLocale)
            }
            .alert("Apple Watch", isPresented: Binding(
                get: { watchModel.message != nil && watchModel.pendingPreview == nil },
                set: { if !$0 { watchModel.message = nil } }
            )) {
                Button("好", role: .cancel) { watchModel.message = nil }
            } message: { Text(watchModel.message ?? "") }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("Erosion.worse_query.log"))) { notification in
                if let message = notification.userInfo?["message"] as? String {
                    print("(customization) \(message)")
                }
            }
            .onAppear {
                guard !didBootstrapLogs else { return }
                didBootstrapLogs = true
                pipe.fileHandleForReading.readabilityHandler = { fh in
                    let data = fh.availableData
                    
                    if data.isEmpty {
                        fh.readabilityHandler = nil
                        sema.signal()
                        return
                    }
                    
                    guard let text = String(data: data, encoding: .utf8) else {
                        return
                    }
                    
                    DispatchQueue.main.async {
                        mgr.logOutput.append(text)
                    }
                }
                print("")
                print("[*] \(AppInfo.appName) v\(AppInfo.appVersion) (\(build))")
                print(L("[*] 运行环境：\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)，设备标识符：\(machineName()) (\(buildNumber()))"))
                group = wq.getAppGroup()
                GXCustomizationAccess.configureAppGroup(group)
                print(L("(wq) 当前使用 App Group：\(group)"))
                if isRunningInLiveContainer() {
                    print(LocalizationManager.isEnglish
                        ? "[!] (lc) Currently running inside LiveContainer: if container authorization fails, check host App Group settings in LiveContainer or install standalone."
                        : "[!] (lc) 当前运行在 LiveContainer 内，若遇容器授权失败，请在 LiveContainer 应用设置中检查宿主 App Group 配置，或使用独立侧载安装。")
                }
            }
            .overlay {
                if mgr.shouldRespring {
                    RespringView()
                        .brightness(-1.0)
                        .ignoresSafeArea()
                }
            }
        }
    }
}

extension UIDocumentPickerViewController {
    @objc func fix_init(forOpeningContentTypes contentTypes: [UTType], asCopy: Bool) -> UIDocumentPickerViewController {
        return fix_init(forOpeningContentTypes: contentTypes, asCopy: true)
    }
}
