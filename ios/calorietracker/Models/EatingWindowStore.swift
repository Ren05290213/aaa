import Foundation

/// The daily eating window (e.g. 08:00–16:00), read from the shared App Group
/// container so a background App Intent can use it without the app's UI.
///
/// Keys must match `EatingWindow` in `ios/FudAIWidgets/FastingWidget.swift` and
/// `FastingSettings` in `Models/FastingSession.swift`.
enum EatingWindowStore {
    static let enabledKey = "fudai_eating_window_enabled"
    static let startMinutesKey = "fudai_eating_window_start_minutes"
    static let endMinutesKey = "fudai_eating_window_end_minutes"

    struct Window: Equatable {
        let startMinutes: Int
        let endMinutes: Int

        /// Minutes from midnight that this window leaves for fasting.
        var fastingMinutes: Int {
            let eating = endMinutes > startMinutes
                ? endMinutes - startMinutes
                : 24 * 60 - startMinutes + endMinutes
            return max(60, 24 * 60 - eating)
        }

        func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
            let parts = calendar.dateComponents([.hour, .minute], from: date)
            let now = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            if startMinutes < endMinutes {
                return now >= startMinutes && now < endMinutes
            }
            // Window wraps past midnight.
            return now >= startMinutes || now < endMinutes
        }
    }

    static func load() -> Window? {
        let defaults = WidgetSnapshot.sharedDefaults ?? .standard
        guard defaults.bool(forKey: enabledKey) else { return nil }
        let start = defaults.object(forKey: startMinutesKey) as? Int ?? 8 * 60
        let end = defaults.object(forKey: endMinutesKey) as? Int ?? 16 * 60
        guard start != end else { return nil }
        return Window(startMinutes: start, endMinutes: end)
    }
}
