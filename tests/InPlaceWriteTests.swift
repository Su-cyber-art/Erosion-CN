import Foundation
import Darwin

nonisolated func L(_ value: String.LocalizationValue) -> String { String(localized: value) }

@main enum InPlaceWriteTests {
    static func verify(_ condition: Bool) { precondition(condition) }
    static func main() throws {
        let files = FileManager.default
        let root = files.temporaryDirectory.appendingPathComponent("Erosion-write-\(UUID().uuidString)")
        try files.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? files.removeItem(at: root) }
        let url = root.appendingPathComponent("cache.plist")
        let original = Data("original".utf8)
        try original.write(to: url)
        var before = stat()
        verify(stat(url.path, &before) == 0)
        for payload in [Data(repeating: 7, count: 300), Data([1, 2, 3])] {
            verify(writeFileAtomically(payload, to: url).0)
            verify(try Data(contentsOf: url) == payload)
            var after = stat()
            verify(stat(url.path, &after) == 0 && before.st_ino == after.st_ino && before.st_uid == after.st_uid && before.st_mode == after.st_mode)
        }
        verify(!writeFileAtomically(Data(), to: url).0)
        verify(try Data(contentsOf: url) == Data([1, 2, 3]))
        let link = root.appendingPathComponent("link")
        try files.createSymbolicLink(at: link, withDestinationURL: url)
        verify(!writeFileAtomically(original, to: link).0)
        verify(try Data(contentsOf: url) == Data([1, 2, 3]))

        // A real short write followed by EFBIG must restore the original bytes.
        try original.write(to: url)
        var previous = rlimit()
        verify(getrlimit(RLIMIT_FSIZE, &previous) == 0)
        var limited = previous
        limited.rlim_cur = 12
        let oldSignal = signal(SIGXFSZ, SIG_IGN)
        verify(setrlimit(RLIMIT_FSIZE, &limited) == 0)
        let result = writeFileAtomically(Data(repeating: 8, count: 40), to: url)
        verify(setrlimit(RLIMIT_FSIZE, &previous) == 0)
        signal(SIGXFSZ, oldSignal)
        verify(!result.0)
        verify(try Data(contentsOf: url) == original)
        print("PASS: in-place growth/shrink preserves inode and permissions; empty/symlink writes are rejected; partial-write failure restores original bytes.")
    }
}
