// SPDX-License-Identifier: GPL-3.0-only
// Adapted from huamidev/GestaltX, commit 72bf625. See THIRD_PARTY_NOTICES.md.
import SwiftUI
import Combine
import AVFAudio
import UniformTypeIdentifiers

@MainActor
final class AppSoundCatalogModel: ObservableObject {
    @Published private(set) var applications: [LaunchArtworkApp] = []
    @Published private(set) var scanning = false

    private let catalog: LaunchArtworkCatalogStore
    private let captured = CapturedSoundStore.shared
    private let sounds = AppSoundStore(storage: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Erosion/Audio"), device: DeviceConsolePaths.deviceIdentifier)

    // Metadata and the two availability signals are kept separate, per the plan:
    //   installed  — the shared app roster (name + bundle id, cache-first)
    //   observed   — bundle ids with at least one captured notification sound
    //   existing    — bundle ids whose Sound/Sounds directories already hold audio
    //   visible     = installed ∩ (observed ∪ existing)
    private var installed: [String: LaunchArtworkApp] = [:]
    private var observed: Set<String> = []
    private var existing: Set<String> = []
    private var scannedExisting: Set<String> = []
    private let defaults = UserDefaults.standard
    private var existingCacheKey: String { "Erosion.audioLibrary.existing.\(DeviceConsolePaths.deviceIdentifier)" }
    private var scannedCacheKey: String { "Erosion.audioLibrary.scanned.\(DeviceConsolePaths.deviceIdentifier)" }

    private var catalogTask: Task<Void, Never>?
    private var capturedTask: Task<Void, Never>?

    init() {
        let backend = LaunchArtworkCatalogStore.Backend(inventory: LaunchArtworkCatalogStore.Backend.device.inventory, verify: { candidate in
            #if os(iOS) && !targetEnvironment(simulator)
            guard let path = GXCustomizationAccess.applicationContainer(for: candidate.app.id, hint: candidate.container) else {
                return LaunchArtworkAvailability(available: false, retryable: true)
            }
            return LaunchArtworkAvailability(available: !path.isEmpty)
            #else
            return LaunchArtworkAvailability(available: false)
            #endif
        })
        catalog = LaunchArtworkCatalogStore(storage: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Erosion/NotificationSoundCatalog-v2"), device: DeviceConsolePaths.deviceIdentifier, backend: backend)
        existing = Set(defaults.stringArray(forKey: existingCacheKey) ?? [])
        scannedExisting = Set(defaults.stringArray(forKey: scannedCacheKey) ?? [])
    }

    func refresh(force: Bool = false) {
        if capturedTask == nil {
            capturedTask = Task {
                for await event in captured.events() {
                    switch event {
                    case .snapshot(let list): observed = Set(list.map(\.bundleID))
                    case .upsert(let sound): observed.insert(sound.bundleID)
                    case .remove: break
                    }
                    recompute()
                }
            }
        }
        guard catalogTask == nil else { return }
        if force { scannedExisting.removeAll() }
        scanning = true
        catalogTask = Task {
            for await event in catalog.events(force: force) {
                switch event {
                case .snapshot(let apps): installed = Dictionary(apps.map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })
                case .upsert(let app): installed[app.id] = app
                case .remove(let id): installed[id] = nil; existing.remove(id); scannedExisting.remove(id)
                }
                recompute()
            }
            await scanExisting()
            saveScanCache()
            scanning = false
            catalogTask = nil
        }
    }

    /// Directed, ascending-by-size background scan of the four Sound/Sounds
    /// directories (and verified App Groups, inside AppSoundStore.scan). A
    /// temporary read failure leaves an app unscanned so its prior state is kept;
    /// only a confirmed empty scan rules an app out of `existing`.
    private func scanExisting() async {
        let candidates = installed.values
            .filter { !scannedExisting.contains($0.id) }
            .sorted(by: LaunchArtworkAppOrder.before)
        for app in candidates {
            if Task.isCancelled { return }
            do {
                let result = try await sounds.scan(app)
                if result.files.isEmpty { existing.remove(app.id) }
                else { existing.insert(app.id) }
                if !result.partial { scannedExisting.insert(app.id) }
                recompute()
            } catch is CancellationError {
                return
            } catch {
                // leave unscanned; keep whatever we already knew
            }
        }
    }

    private func recompute() {
        var merged = installed
        for id in observed where merged[id] == nil {
            merged[id] = LaunchArtworkApp(id: id, name: id)
        }
        let visible = merged.keys.filter { observed.contains($0) || existing.contains($0) }
        applications = visible.compactMap { merged[$0] }.sorted(by: LaunchArtworkAppOrder.before)
    }

    private func saveScanCache() {
        defaults.set(Array(existing), forKey: existingCacheKey)
        defaults.set(Array(scannedExisting), forKey: scannedCacheKey)
    }

    /// Empty partition: captured apps stay in the captured section even after
    /// the background scan discovers files for them. Otherwise they would jump
    /// from "captured" to "existing" while the list is still scanning.
    var existingApps: [LaunchArtworkApp] {
        applications.filter { existing.contains($0.id) && !observed.contains($0.id) }
    }

    /// Every app with at least one capture record, regardless of whether files
    /// were also found by the scan.
    var capturedApps: [LaunchArtworkApp] {
        applications.filter { observed.contains($0.id) }
    }

    /// Remove every capture clue for an app. Audio files on disk are untouched.
    func forgetCapturedApp(_ app: LaunchArtworkApp) async {
        await captured.forget(bundleIDs: [app.id])
        observed = await captured.observedBundleIDs()
        recompute()
    }
}

@MainActor
final class AppSoundModel: ObservableObject {
    @Published private(set) var files: [AppSoundEntry] = []
    @Published private(set) var clues: [CapturedNotificationSound] = []
    @Published private(set) var partial = false
    @Published private(set) var busy = false
    @Published private(set) var selection: AppSoundSelection?
    @Published private(set) var draft: Data?
    @Published private(set) var draftNamed: Data?
    @Published var message: String?
    private var player: AVAudioPlayer?
    private let store = AppSoundStore(storage: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Erosion/Audio"), device: DeviceConsolePaths.deviceIdentifier)
    private let captured = CapturedSoundStore.shared

    /// Captured bundle-internal filenames with no same-name file already present:
    /// these are candidates for a new same-name override in Library/Sounds.
    var pendingClues: [CapturedNotificationSound] {
        let present = Set(files.map {
            CapturedNotificationSound.normalizedName(($0.path as NSString).lastPathComponent)
        })
        return clues.filter {
            $0.representsReplaceableFile && !present.contains($0.identityFilename)
        }
    }

    func scan(_ app: LaunchArtworkApp) async {
        guard !busy else { return }
        busy = true; defer { busy = false }
        do { let result = try await store.scan(app); files = result.files; partial = result.partial }
        catch { NSLog("Erosion Audio scan failed for \(app.id): \(error)"); message = error.localizedDescription }
        clues = await captured.sounds(for: app.id)
    }

    func deleteClue(_ clue: CapturedNotificationSound) async {
        await captured.remove(id: clue.id)
        clues = await captured.sounds(for: clue.bundleID)
    }
    func select(_ entry: AppSoundEntry, app: LaunchArtworkApp) async {
        guard !busy else { return }
        busy = true; defer { busy = false }
        stop(); draft = nil; selection = nil
        do { selection = try await store.select(entry, app: app) }
        catch { NSLog("Erosion Audio select failed for \(app.id)/\(entry.path): \(error)"); message = error.localizedDescription }
    }
    func choose(_ url: URL) async {
        guard !busy, let selection else { return }
        busy = true; defer { busy = false }
        stop()
        do { draft = try await store.prepare(url, selection: selection) }
        catch { message = error.localizedDescription }
    }
    /// Prepare audio for a captured same-name override (no existing file).
    func chooseNamed(_ url: URL, name: String) async {
        guard !busy else { return }
        busy = true; defer { busy = false }
        stop()
        do { draftNamed = try await store.prepareNamed(url, name: name) }
        catch { message = error.localizedDescription }
    }
    func createNamed(_ name: String, app: LaunchArtworkApp) async -> Bool {
        guard !busy, let data = draftNamed else { return false }
        busy = true; defer { busy = false }
        stop()
        do {
            try await store.createNamed(name, data: data, app: app)
            draftNamed = nil
            message = customizationLocalized("Audio replaced.")
            return true
        } catch { NSLog("Erosion Audio create failed for \(app.id)/\(name): \(error)"); message = error.localizedDescription; return false }
    }
    func play(replacement: Bool) {
        let data: Data?
        if replacement { data = draft ?? draftNamed } else { data = selection?.current.data }
        guard let data else { return }
        do {
            stop()
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            player = try AVAudioPlayer(data: data)
            guard player?.play() == true else { throw CustomizationFailure("This audio format is not supported.") }
        } catch { message = error.localizedDescription }
    }
    func stop() {
        player?.stop(); player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    func discard() { stop(); draft = nil; draftNamed = nil }
    func apply(_ app: LaunchArtworkApp, restore: Bool = false) async {
        guard !busy, let selection else { return }
        busy = true; defer { busy = false }
        stop()
        do {
            if restore { try await store.restore(selection, app: app) }
            else if let draft { try await store.apply(draft, selection: selection, app: app) }
            else { return }
            draft = nil
            let result = try await store.scan(app)
            files = result.files; partial = result.partial
            if let entry = files.first(where: { $0.id == selection.entry.id }) {
                self.selection = try await store.select(entry, app: app)
            } else { self.selection = nil }
            message = customizationLocalized(restore ? "Original audio restored." : "Audio replaced.")
        } catch {
            NSLog("Erosion Audio \(restore ? "restore" : "apply") failed for \(app.id)/\(selection.entry.path): \(error)")
            message = error.localizedDescription
        }
    }
}

struct AppSoundApplicationsView: View {
    @StateObject private var catalog = AppSoundCatalogModel()
    @State private var search = ""
    @State private var showsCapture = false
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        List {
            Section {
                Label(customizationLocalized("Apps that already have notification sounds or audio files"), systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if catalog.scanning { HStack { ProgressView(); Text(customizationLocalized("Reading…")) }.foregroundStyle(.secondary) }
            if !filteredExisting.isEmpty {
                Section(customizationLocalized("Existing Audio")) {
                    ForEach(filteredExisting) { app in appRow(app) }
                }
            }
            if !filteredCaptured.isEmpty {
                Section(customizationLocalized("Captured Apps")) {
                    ForEach(filteredCaptured) { app in
                        appRow(app)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task { await catalog.forgetCapturedApp(app) }
                                } label: {
                                    Label(customizationLocalized("Delete Capture"), systemImage: "trash")
                                }
                                .tint(.red)
                            }
                    }
                }
            }
            if !catalog.scanning && catalog.applications.isEmpty { ContentUnavailableView(customizationLocalized("No Notification Sounds"), systemImage: "bell") }
        }
        .navigationTitle(customizationLocalized("App Audio Library"))
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $search)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showsCapture = true } label: {
                    Image(systemName: "dot.radiowaves.left.and.right")
                }
                .accessibilityLabel(customizationLocalized("Capture"))
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { catalog.refresh(force: true) } label: { Image(systemName: "arrow.clockwise") }.disabled(catalog.scanning)
                    .accessibilityLabel(customizationLocalized("Read Again"))
            }
        }
        .sheet(isPresented: $showsCapture) {
            NavigationStack { NotificationCaptureView() }
        }
        .task { catalog.refresh() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { catalog.refresh() } }
        .transaction { $0.animation = nil }
    }

    private var filteredExisting: [LaunchArtworkApp] { filtered(catalog.existingApps) }
    private var filteredCaptured: [LaunchArtworkApp] { filtered(catalog.capturedApps) }

    private func filtered(_ apps: [LaunchArtworkApp]) -> [LaunchArtworkApp] {
        guard !search.isEmpty else { return apps }
        return apps.filter {
            $0.name.localizedCaseInsensitiveContains(search) || $0.id.localizedCaseInsensitiveContains(search)
        }
    }

    private func appRow(_ app: LaunchArtworkApp) -> some View {
        NavigationLink { AppSoundFilesView(app: app) } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(app.name).lineLimit(1)
                Text(app.id).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
        }
    }
}

private struct AppSoundFilesView: View {
    let app: LaunchArtworkApp
    @StateObject private var model = AppSoundModel()
    @State private var search = ""
    var body: some View {
        List {
            if model.busy { HStack { ProgressView(); Text(customizationLocalized("Reading…")) }.foregroundStyle(.secondary) }
            ForEach(model.files.filter { search.isEmpty || $0.path.localizedCaseInsensitiveContains(search) }) { entry in
                NavigationLink { AppSoundEditor(app: app, entry: entry) } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text((entry.path as NSString).lastPathComponent).lineLimit(1)
                        Text(entry.group.map { $0 + "/" + entry.path } ?? entry.path).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    }
                }
            }
            if !model.pendingClues.isEmpty {
                Section {
                    ForEach(model.pendingClues) { clue in
                        NavigationLink { AppSoundCapturedEditor(app: app, clue: clue) } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(clue.cleanFilename).lineLimit(1)
                                Text(clue.relativeLocation ?? clue.origin.rawValue).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                Task { await model.deleteClue(clue) }
                            } label: {
                                Label(customizationLocalized("Delete Capture"), systemImage: "trash")
                            }
                            .tint(.red)
                        }
                    }
                } header: {
                    Text(customizationLocalized("Captured Notification Sounds"))
                } footer: { Text(customizationLocalized("These filenames were captured from notifications. Add a same-name audio to override them.")) }
            }
            if !model.busy && model.files.isEmpty && model.pendingClues.isEmpty {
                ContentUnavailableView(customizationLocalized("No Notification Sounds"), systemImage: "bell")
            }
            if model.partial { Section { Text(customizationLocalized("Some folders could not be read or the scan limit was reached.")).foregroundStyle(.secondary) } }
            if !model.files.isEmpty {
                Section {} footer: { Text(customizationLocalized("Not every sound listed is the current notification sound. Preview the sounds before replacing one.")) }
            }
        }
        .navigationTitle(app.name).navigationBarTitleDisplayMode(.inline)
        .searchable(text: $search)
        .toolbar { ToolbarItem(placement: .topBarTrailing) {
            Button { Task { await model.scan(app) } } label: { Image(systemName: "arrow.clockwise") }.disabled(model.busy)
                .accessibilityLabel(customizationLocalized("Read Again"))
        } }
        .task { await model.scan(app) }
        // Returning from an editor must show a newly added same-name override
        // and the refreshed restore state immediately.
        .onAppear { Task { await model.scan(app) } }
        .alert(customizationLocalized("Erosion Plus"), isPresented: Binding(get: { model.message != nil }, set: { if !$0 { model.message = nil } })) {
            Button(customizationLocalized("OK"), role: .cancel) { model.message = nil }
        } message: { Text(model.message ?? "") }
    }
}

private struct AppSoundEditor: View {
    let app: LaunchArtworkApp
    let entry: AppSoundEntry
    @StateObject private var model = AppSoundModel()
    @State private var importsAudio = false
    @State private var confirmsApply = false
    @State private var confirmsRestore = false
    var body: some View {
        List {
            Section {
                Text(entry.group.map { $0 + "/" + entry.path } ?? entry.path).font(.footnote).textSelection(.enabled)
                Button { model.play(replacement: false) } label: { Label(customizationLocalized("Play Current Audio"), systemImage: "play.fill") }
                    .disabled(model.selection == nil)
                Button { importsAudio = true } label: { Label(customizationLocalized("Choose Audio"), systemImage: "square.and.arrow.down") }
                    .disabled(model.selection == nil)
                if model.draft != nil {
                    Button { model.play(replacement: true) } label: { Label(customizationLocalized("Play Replacement"), systemImage: "play.fill") }
                    Button { model.discard() } label: { Label(customizationLocalized("Discard Changes"), systemImage: "xmark") }.tint(.red)
                }
            }
            Section {
                Button { confirmsApply = true } label: { Label(customizationLocalized("Apply Changes"), systemImage: "checkmark") }.disabled(model.draft == nil)
                Button { confirmsRestore = true } label: { Label(customizationLocalized("Restore Original Audio"), systemImage: "arrow.uturn.backward") }
                    .disabled(model.selection?.canRestore != true)
            }
        }
        .disabled(model.busy)
        .navigationTitle((entry.path as NSString).lastPathComponent).navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { if model.busy { ProgressView() } } }
        .task { await model.select(entry, app: app) }
        .onDisappear { model.stop() }
        .sheet(isPresented: $importsAudio) {
            CustomizationFilePicker(allowedTypes: [.item]) { result in
                importsAudio = false
                switch result {
                case .success(let url): Task { await model.choose(url) }
                case .failure(let error):
                    if (error as NSError).code != CocoaError.userCancelled.rawValue {
                        model.message = error.localizedDescription
                    }
                }
            }
            .ignoresSafeArea()
        }
        .alert(customizationLocalized("Apply these changes?"), isPresented: $confirmsApply) {
            Button(customizationLocalized("Cancel"), role: .cancel) {}
            Button(customizationLocalized("Apply")) { Task { await model.apply(app) } }
        }
        .alert(customizationLocalized("Restore Original Audio"), isPresented: $confirmsRestore) {
            Button(customizationLocalized("Cancel"), role: .cancel) {}
            Button(customizationLocalized("Restore Audio")) { Task { await model.apply(app, restore: true) } }
        }
        .alert(customizationLocalized("Erosion Plus"), isPresented: Binding(get: { model.message != nil }, set: { if !$0 { model.message = nil } })) {
            Button(customizationLocalized("OK"), role: .cancel) { model.message = nil }
        } message: { Text(model.message ?? "") }
    }
}

/// Creates a new same-name override for a captured bundle-internal sound that has
/// no existing file in Library/Sounds. The user never types the filename — it is
/// the captured name. There is no "play original" here because the bundle file is
/// not readable from the sandbox.
private struct AppSoundCapturedEditor: View {
    let app: LaunchArtworkApp
    let clue: CapturedNotificationSound
    @StateObject private var model = AppSoundModel()
    @Environment(\.dismiss) private var dismiss
    @State private var importsAudio = false
    @State private var confirmsCreate = false
    var body: some View {
        List {
            Section {
                LabeledContent(customizationLocalized("File")) { Text(clue.cleanFilename).foregroundStyle(.secondary).textSelection(.enabled) }
                if let location = clue.relativeLocation {
                    LabeledContent(customizationLocalized("Source")) { Text(location).foregroundStyle(.secondary) }
                }
            } footer: {
                Text(customizationLocalized("A same-name audio will be written to this app's Library/Sounds so the system uses it instead of the bundled sound."))
            }
            Section {
                Button { importsAudio = true } label: { Label(customizationLocalized("Choose Audio"), systemImage: "square.and.arrow.down") }
                if model.draftNamed != nil {
                    Button { model.play(replacement: true) } label: { Label(customizationLocalized("Play Replacement"), systemImage: "play.fill") }
                    Button { model.discard() } label: { Label(customizationLocalized("Discard Changes"), systemImage: "xmark") }.tint(.red)
                }
            }
            Section {
                Button { confirmsCreate = true } label: { Label(customizationLocalized("Apply Changes"), systemImage: "checkmark") }.disabled(model.draftNamed == nil)
            }
        }
        .disabled(model.busy)
        .navigationTitle(clue.cleanFilename).navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { if model.busy { ProgressView() } } }
        .onDisappear { model.stop() }
        .sheet(isPresented: $importsAudio) {
            CustomizationFilePicker(allowedTypes: [.item]) { result in
                importsAudio = false
                switch result {
                case .success(let url): Task { await model.chooseNamed(url, name: clue.identityFilename) }
                case .failure(let error):
                    if (error as NSError).code != CocoaError.userCancelled.rawValue {
                        model.message = error.localizedDescription
                    }
                }
            }
            .ignoresSafeArea()
        }
        .alert(customizationLocalized("Apply these changes?"), isPresented: $confirmsCreate) {
            Button(customizationLocalized("Cancel"), role: .cancel) {}
            Button(customizationLocalized("Apply")) { Task { if await model.createNamed(clue.identityFilename, app: app) { dismiss() } } }
        }
        .alert(customizationLocalized("Erosion Plus"), isPresented: Binding(get: { model.message != nil }, set: { if !$0 { model.message = nil } })) {
            Button(customizationLocalized("OK"), role: .cancel) { model.message = nil }
        } message: { Text(model.message ?? "") }
    }
}
