import Foundation

enum AppTab: String, CaseIterable, Identifiable, Sendable {
    case today
    case wardrobe
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: "Today"
        case .wardrobe: "Wardrobe"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .today: "sparkles"
        case .wardrobe: "square.grid.2x2"
        case .settings: "gearshape"
        }
    }

    var accessibilityIdentifier: String {
        "tab.\(rawValue)"
    }
}
