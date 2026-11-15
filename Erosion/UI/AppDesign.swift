import SwiftUI

enum AppDesign {
    static let spacing: CGFloat = 16
    static let radius: CGFloat = 22
    static let page = Color(uiColor: .systemGroupedBackground)
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
}

struct ToolIcon: View {
    let symbol: String
    var tint: Color = .accentColor
    var size: CGFloat = 42
    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.43, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: size * 0.29, style: .continuous))
            .accessibilityHidden(true)
    }
}

struct ToolRow: View {
    let title: String
    let subtitle: String
    let symbol: String
    var tint: Color = .accentColor
    var body: some View {
        HStack(spacing: 14) {
            ToolIcon(symbol: symbol, tint: tint)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.body.weight(.medium)).foregroundStyle(.primary)
                Text(subtitle).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

struct DashboardHeading: View {
    let title: String
    var body: some View {
        Text(title).font(.title3.weight(.semibold)).frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension View {
    func appCard() -> some View {
        padding(AppDesign.spacing)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppDesign.card, in: RoundedRectangle(cornerRadius: AppDesign.radius, style: .continuous))
    }
}
