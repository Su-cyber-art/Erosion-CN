import Foundation

nonisolated func watchLocalized(_ key: String) -> String {
    #if os(iOS)
    return LocalizationManager.activeBundle.localizedString(forKey: key, value: key, table: nil)
    #else
    return Bundle.main.localizedString(forKey: key, value: key, table: nil)
    #endif
}
