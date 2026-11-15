import SwiftUI

private struct WatchFieldRoute: Identifiable {
    let id = UUID()
    let key: String?
}

struct WatchFieldsView: View {
    @EnvironmentObject private var model: WatchViewModel
    @State private var search = ""
    @State private var editor: WatchFieldRoute?
    private var keys: [String] {
        (model.document?.cacheExtra.keys.sorted() ?? []).filter { key in
            search.isEmpty || key.localizedCaseInsensitiveContains(search) || mgFormatValue(model.document?.cacheExtra[key]).localizedCaseInsensitiveContains(search)
        }
    }
    var body: some View {
        List {
            ForEach(keys, id: \.self) { key in
                Button { editor = WatchFieldRoute(key: key) } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(key).font(.subheadline.monospaced()).lineLimit(1).truncationMode(.middle)
                            if WatchMGDocument.identityKeys.contains(key) { Image(systemName: "lock").font(.caption) }
                        }
                        Text(mgFormatValue(model.document?.cacheExtra[key])).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    }
                    .foregroundStyle(.primary).padding(.vertical, 3)
                }
                .disabled(WatchMGDocument.identityKeys.contains(key) || model.isBusy)
            }
        }
        .navigationTitle("手表字段")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $search, prompt: "搜索键名或值")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { editor = WatchFieldRoute(key: nil) } label: { Image(systemName: "plus") }
                    .disabled(model.isBusy || model.document == nil).accessibilityLabel("添加字段")
            }
        }
        .sheet(item: $editor) { route in WatchFieldEditor(key: route.key, original: route.key.flatMap { model.document?.cacheExtra[$0] }) }
        .safeAreaInset(edge: .bottom) { WatchApplyBar() }
    }
}

private struct WatchFieldEditor: View {
    @EnvironmentObject private var model: WatchViewModel
    @Environment(\.dismiss) private var dismiss
    let initialKey: String?
    let original: Any?
    let initialText: String
    let initialKind: WatchValueKind
    @State private var key: String
    @State private var kind: WatchValueKind
    @State private var text: String
    @State private var error: String?
    @State private var asksDelete = false

    init(key: String?, original: Any?) {
        initialKey = key
        self.original = original
        let detected = original.map(WatchValueKind.detect) ?? .string
        initialKind = detected
        initialText = original.map { detected.text(for: $0) } ?? ""
        _key = State(initialValue: key ?? "")
        _kind = State(initialValue: detected)
        _text = State(initialValue: initialText)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("键名") {
                    TextField("输入键名", text: $key).textInputAutocapitalization(.never).autocorrectionDisabled()
                        .disabled(initialKey != nil)
                }
                Section("类型") {
                    Picker("值类型", selection: $kind) {
                        ForEach(WatchValueKind.allCases) { kind in Text(watchLocalized(kind.rawValue)).tag(kind) }
                    }
                }
                Section {
                    TextEditor(text: $text).font(.body.monospaced()).frame(minHeight: 170)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                } header: {
                    Text("值")
                } footer: {
                    if kind == .array || kind == .dictionary { Text("数组和字典使用 XML Plist 片段，可保留嵌套值的类型。") }
                }
                if let error { Section { Text(error).foregroundStyle(.red) } }
                if initialKey != nil {
                    Section { Button("删除字段", role: .destructive) { asksDelete = true } }
                }
            }
            .navigationTitle(initialKey == nil ? L("添加字段") : L("编辑字段"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("暂存") { save() }.disabled(model.document == nil || model.isBusy) }
            }
            .confirmationDialog("删除此字段？", isPresented: $asksDelete, titleVisibility: .visible) {
                Button("删除", role: .destructive) {
                    if let initialKey { model.setField(initialKey, value: nil) }
                    dismiss()
                }
            }
        }
    }

    private func save() {
        let normalized = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { error = L("键名不能为空。"); return }
        guard !WatchMGDocument.identityKeys.contains(normalized) else { error = L("设备身份字段仅供查看。"); return }
        guard initialKey != nil || model.document?.cacheExtra[normalized] == nil else { error = L("字段已存在，请编辑已有字段。"); return }
        do {
            let value: Any
            if let original, kind == initialKind, text == initialText { value = original }
            else { value = try kind.parse(text) }
            model.setField(normalized, value: value)
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
