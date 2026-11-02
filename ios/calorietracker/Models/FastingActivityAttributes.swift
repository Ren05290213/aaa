import ActivityKit
import Foundation

/// The payload of the fasting Live Activity (Dynamic Island + Lock Screen).
///
/// The app target and the `FudAIWidgetsExtension` target compile this file
/// separately; `ios/FudAIWidgets/FastingActivityAttributes.swift` is a copy.
/// Keep both copies identical — the project does not share source files
/// between targets (see `WidgetSnapshot.swift`).
struct FastingActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// When the fast started. Drives the self-updating `Text(_, style: .timer)`.
        var startedAt: Date
        /// Goal length in minutes, used for the "Goal 16h" label.
        var goalMinutes: Int
    }

    /// Identity of the fasting session this activity belongs to, so a stale
    /// activity from a previous fast can be replaced instead of duplicated.
    var sessionID: UUID
}
