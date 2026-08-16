import Foundation

enum AppTab: String, CaseIterable, Identifiable, Sendable {
    case today
    case wardrobe
    case history
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: "Today"
        case .wardrobe: "Wardrobe"
        case .history: "History"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .today: "sparkles"
        case .wardrobe: "square.grid.2x2"
        case .history: "clock.arrow.circlepath"
        case .settings: "gearshape"
        }
    }

    var accessibilityIdentifier: String {
        "tab.\(rawValue)"
    }
}
