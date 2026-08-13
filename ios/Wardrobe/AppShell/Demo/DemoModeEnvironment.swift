import SwiftUI

private struct DemoModeEnvironmentKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var isDemoMode: Bool {
        get { self[DemoModeEnvironmentKey.self] }
        set { self[DemoModeEnvironmentKey.self] = newValue }
    }
}

struct DemoFictionalDataNotice: View {
    var body: some View {
        Label(
            "Demo Mode · Fictional data · Changes are discarded on exit",
            systemImage: "sparkles.rectangle.stack"
        )
        .font(.footnote.weight(.semibold))
        .foregroundStyle(.indigo)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier("demo.fictionalDataNotice")
    }
}
