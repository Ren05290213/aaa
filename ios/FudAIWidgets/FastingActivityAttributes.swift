import ActivityKit
import Foundation

/// Copy of `ios/calorietracker/Models/FastingActivityAttributes.swift`.
///
/// The app target and the `FudAIWidgetsExtension` target compile the file
/// separately, so the two copies must stay identical. The widget is matched to
/// the app's activity by this type's name and its encoded `Codable` keys.
struct FastingActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var startedAt: Date
        var goalMinutes: Int
    }

    var sessionID: UUID
}
