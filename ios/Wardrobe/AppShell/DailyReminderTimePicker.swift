import SwiftUI

/// Self-contained Settings control. Integrate immediately below the enabled
/// reminder toggle; it remains disabled unless the persisted reminder switch
/// is on and reverts visibly if rescheduling fails.
struct DailyReminderTimePicker: View {
    let settings: DevicePrivacySettings

    @State private var selectedDate = Self.date(for: .defaultMorning)
    @State private var lastSavedTime = DailyReminderTime.defaultMorning

    private var reminderIsEnabled: Bool {
        settings.controls.preferences?.dailyReminderEnabled ?? false
    }

    var body: some View {
        DatePicker(
            "Reminder time",
            selection: Binding(
                get: { selectedDate },
                set: { selectedDate = $0; apply($0) }
            ),
            displayedComponents: .hourAndMinute
        )
        .disabled(!reminderIsEnabled || settings.isUpdating)
        .accessibilityHint("Changes the time of the enabled daily prompt to open Today.")
        .accessibilityIdentifier("settings.styling.reminderTime")
        .task {
            lastSavedTime = settings.reminderTime
            selectedDate = Self.date(for: lastSavedTime)
        }
    }

    private func apply(_ date: Date) {
        guard reminderIsEnabled, let chosen = Self.time(from: date) else {
            selectedDate = Self.date(for: lastSavedTime)
            return
        }
        Task { @MainActor in
            if await settings.setReminderTime(chosen) {
                lastSavedTime = chosen
                selectedDate = Self.date(for: chosen)
            } else {
                selectedDate = Self.date(for: lastSavedTime)
            }
        }
    }

    static func time(
        from date: Date,
        calendar: Calendar = .current
    ) -> DailyReminderTime? {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        guard let hour = components.hour, let minute = components.minute else { return nil }
        return DailyReminderTime(hour: hour, minute: minute)
    }

    static func date(
        for time: DailyReminderTime,
        calendar: Calendar = .current
    ) -> Date {
        calendar.date(from: DateComponents(hour: time.hour, minute: time.minute)) ?? .now
    }
}
