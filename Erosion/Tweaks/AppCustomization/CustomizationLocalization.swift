import Foundation

/// Erosion's dynamic English keys use the same catalog and language selection
/// as Erosion's Chinese-source strings.
nonisolated func customizationLocalized(_ key: String) -> String {
    LocalizationManager.activeBundle.localizedString(forKey: key, value: key, table: nil)
}
