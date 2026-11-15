import SwiftUI

struct TweaksView: View {
    @State private var search = ""
    @State private var category: ToolCategory?
    @EnvironmentObject private var watchModel: WatchViewModel
    #if targetEnvironment(simulator)
    @State private var showsWatchPreview = ProcessInfo.processInfo.arguments.contains("--preview-watch")
    #endif

    private var visibleTools: [AppTool] {
        AppTool.allCases.filter {
            ($0 != .watch || !isPad()) &&
            (category == nil || $0.category == category) &&
            (search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) || $0.subtitle.localizedCaseInsensitiveContains(search))
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if !isPad() {
                    Section {
                        NavigationLink { WatchWorkspaceView() } label: { WatchConnectionRow(connection: watchModel.connection) }
                    }
                }
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            categoryButton(nil, title: L("全部"))
                            ForEach(ToolCategory.allCases) { group in categoryButton(group, title: group.title) }
                        }.padding(.vertical, 4)
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                if visibleTools.isEmpty {
                    ContentUnavailableView.search(text: search)
                        .listRowBackground(Color.clear)
                }
                ForEach(ToolCategory.allCases) { group in
                    let tools = visibleTools.filter { $0.category == group }
                    if !tools.isEmpty {
                        Section(group.title) {
                            ForEach(tools) { tool in
                                NavigationLink { AppToolDestination(tool: tool) } label: {
                                    ToolRow(title: tool.title,
                                            subtitle: tool.isAvailable ? tool.subtitle : L("需要 iOS 27 或更高版本"),
                                            symbol: tool.symbol, tint: group.tint)
                                }
                                .disabled(!tool.isAvailable)
                            }
                        }
                    }
                }
            }
            .navigationTitle("工具")
            .searchable(text: $search, prompt: "搜索功能或用途")
            .listSectionSpacing(18)
            #if targetEnvironment(simulator)
            .navigationDestination(isPresented: $showsWatchPreview) { WatchWorkspaceView() }
            #endif
        }
    }

    private func categoryButton(_ value: ToolCategory?, title: String) -> some View {
        Button { category = value } label: {
            Text(title).font(.subheadline.weight(category == value ? .semibold : .regular))
                .padding(.horizontal, 14).padding(.vertical, 9)
                .background(category == value ? Color.accentColor.opacity(0.14) : AppDesign.card, in: Capsule())
                .foregroundStyle(category == value ? Color.accentColor : Color.secondary)
        }
        .buttonStyle(.plain)
    }
}
