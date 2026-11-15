// SPDX-License-Identifier: GPL-3.0-only
// Adapted from huamidev/GestaltX, commit 72bf625. See THIRD_PARTY_NOTICES.md.
import SwiftUI
import UniformTypeIdentifiers

struct CustomizationFilePicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let allowedTypes: [UTType]
    let complete: (Result<URL, Error>) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(complete, cancel: { dismiss() }) }
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: allowedTypes, asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let complete: (Result<URL, Error>) -> Void
        let cancel: () -> Void
        init(_ complete: @escaping (Result<URL, Error>) -> Void, cancel: @escaping () -> Void) {
            self.complete = complete
            self.cancel = cancel
        }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { cancel() }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let source = urls.first else { return }
            Task {
                let result = await Task.detached(priority: .userInitiated) { () -> Result<URL, Error> in
                    let scoped = source.startAccessingSecurityScopedResource()
                    defer { if scoped { source.stopAccessingSecurityScopedResource() } }
                    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Erosion-Audio-\(UUID().uuidString)")
                    do {
                        let size = try source.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
                        guard size.isRegularFile == true, (size.fileSize ?? Int.max) <= AppSoundDirectory.maximumFile else {
                            throw CustomizationFailure("Choose an audio file smaller than 32 MB.")
                        }
                        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
                        let target = directory.appendingPathComponent(source.lastPathComponent)
                        try FileManager.default.copyItem(at: source, to: target)
                        return .success(target)
                    } catch {
                        try? FileManager.default.removeItem(at: directory)
                        return .failure(error)
                    }
                }.value
                complete(result)
            }
        }
    }
}
