// Temporary-file replacement for non-system files.
import Foundation
import Darwin

func writeFileTemp(_ data: Data, to url: URL) -> (Bool, String) {
    guard !data.isEmpty else {
        return (false, L("拒绝写入 0 字节空数据！"))
    }
    do {
        var statBuf = stat()
        let hasOriginal = (stat(url.path, &statBuf) == 0)

        let tempURL = url.deletingLastPathComponent().appendingPathComponent(".\(url.lastPathComponent).\(UUID().uuidString).tmp")
        try data.write(to: tempURL, options: [.withoutOverwriting])
        defer { try? fm.removeItem(at: tempURL) }

        if hasOriginal {
            _ = chmod(tempURL.path, statBuf.st_mode & 0o7777)
            _ = chown(tempURL.path, statBuf.st_uid, statBuf.st_gid)
            let _ = try fm.replaceItemAt(url, withItemAt: tempURL)
            _ = chmod(url.path, statBuf.st_mode & 0o7777)
            _ = chown(url.path, statBuf.st_uid, statBuf.st_gid)
        } else {
            try fm.moveItem(at: tempURL, to: url)
        }

        return (true, "succeeded")
    } catch {
        print("(fm) failed to write file: \(error.localizedDescription)")
        return (false, error.localizedDescription)
    }
}
