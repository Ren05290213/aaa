import ActivityKit
import AppIntents
import Foundation
import UserNotifications
import WidgetKit

extension Notification.Name {
    /// Posted when a background App Intent changed the fasting state, so a live
    /// scene can reload the store it already holds in memory.
    static let fastingStateChangedByIntent = Notification.Name("FudAI.fastingStateChangedByIntent")
}

/// "Apply Fasting Schedule": reads the eating window and starts the fast the
/// schedule calls for, without opening the app.
///
/// Point two Shortcuts personal automations at this intent — one at the time the
/// eating window opens, one at the time it closes. Each run works out the phase
/// itself, so both automations can call the same shortcut.
///
/// iOS only allows a Live Activity to be started while the app is in the
/// foreground. A background intent often is allowed, but when the system refuses
/// it the intent posts a notification instead of failing silently.
struct ApplyFastingScheduleIntent: AppIntent {
    static let title: LocalizedStringResource = "Apply Fasting Schedule"
    static let description = IntentDescription(
        "Starts or ends the fast that matches your daily eating window, and refreshes the fasting countdown.",
        categoryName: "Fasting"
    )
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let window = EatingWindowStore.load() else {
            return .result()
        }

        let store = FastingStore()
        let now = Date()

        if window.contains(now) {
            // Eating window: close the fast if one is running.
            if store.activeSession != nil {
                _ = store.endActive(at: now)
            }
        } else if store.activeSession == nil {
            // Fasting phase: start a fast long enough to reach the next window.
            _ = store.start(goalMinutes: window.fastingMinutes, at: now)
        }

        let active = store.activeSession
        FastingLiveActivity.sync(with: active)
        FastingLiveActivity.publishSnapshot(active: active)

        if active != nil, Activity<FastingActivityAttributes>.activities.isEmpty {
            await notifyNeedsOneTap()
        }

        NotificationCenter.default.post(name: .fastingStateChangedByIntent, object: nil)
        return .result()
    }

    /// The system refused the Live Activity: tell the user, since the schedule
    /// itself already ran.
    private func notifyNeedsOneTap() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        let allowed = settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
            || settings.authorizationStatus == .ephemeral
        guard allowed else { return }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "Fasting countdown is waiting")
        content.body = String(localized: "iOS blocked the background start. Open Fud AI once to put the countdown back on the Dynamic Island.")
        content.interruptionLevel = .passive

        let request = UNNotificationRequest(
            identifier: "fasting.liveactivity.fallback",
            content: content,
            trigger: nil
        )
        try? await center.add(request)
    }
}
