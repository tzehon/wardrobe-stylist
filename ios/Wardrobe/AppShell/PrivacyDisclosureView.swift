import SwiftUI

struct PrivacyDisclosureView: View {
    let disclosure: PrivacyDisclosure

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(disclosure.title, systemImage: "hand.raised.fill")
                .font(.headline)

            Text(disclosure.summary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                Text("Data used")
                    .font(.subheadline.weight(.semibold))
                ForEach(disclosure.dataShared, id: \.self) { detail in
                    Label(detail, systemImage: "circle.fill")
                        .labelStyle(PrivacyBulletLabelStyle())
                }
            }

            Text(disclosure.destination)
                .fixedSize(horizontal: false, vertical: true)

            Text(disclosure.result)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .contain)
    }
}

private struct PrivacyBulletLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            configuration.icon
                .font(.system(size: 5))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            configuration.title
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct StylingPrivacySettingsView: View {
    let settings: DevicePrivacySettings

    private var preferences: AccountPrivacyPreferences? {
        settings.controls.preferences
    }

    private var isAllowed: Bool {
        settings.controls.decision(for: .aiStyling).isAllowed
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PrivacyDisclosureView(disclosure: .wardrobeStyling)

            switch settings.controls.state {
            case .idle, .loading:
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Loading your styling choice…")
                        .foregroundStyle(.secondary)
                }
            case .unavailable(let failure):
                privacyError(failure.userMessage)
                Button("Try loading again") {
                    Task { await settings.controls.load() }
                }
                .buttonStyle(.bordered)
            case .loaded:
                if isAllowed {
                    Label("AI styling allowed", systemImage: "checkmark.shield.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.green)
                        .accessibilityIdentifier("settings.styling.allowed")

                    Toggle(
                        "Daily styling reminder",
                        isOn: Binding(
                            get: { preferences?.dailyReminderEnabled ?? false },
                            set: { isEnabled in
                                Task { @MainActor in
                                    _ = await settings.setReminderEnabled(isEnabled)
                                }
                            }
                        )
                    )
                    .disabled(settings.isUpdating)
                    .accessibilityHint("Schedules a daily prompt to open Today. It does not generate a look in the background.")
                    .accessibilityIdentifier("settings.styling.reminder")

                    Text("The reminder only prompts you to open Today. No styling request is sent until you tap a styling action.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Button("Withdraw AI styling permission", role: .destructive) {
                        Task { _ = await settings.withdrawStyling() }
                    }
                    .disabled(settings.isUpdating)
                    .accessibilityIdentifier("settings.styling.withdraw")
                } else {
                    Button {
                        Task { _ = await settings.grantStyling() }
                    } label: {
                        Label("Allow AI styling", systemImage: "checkmark.shield")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(settings.isUpdating)
                    .accessibilityIdentifier("settings.styling.allow")

                    Text("Off by default. You can add and browse wardrobe items without allowing styling.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if let errorMessage = settings.errorMessage {
                privacyError(errorMessage)
            }
        }
        .task { await settings.load() }
    }

    private func privacyError(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.footnote)
            .foregroundStyle(.red)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("settings.styling.error")
    }
}
