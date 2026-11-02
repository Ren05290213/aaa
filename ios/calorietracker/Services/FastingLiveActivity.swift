import ActivityKit
import Foundation
import WidgetKit

/// Drives the fasting Live Activity that shows up on the Dynamic Island and the
/// Lock Screen while a fast is running.
///
/// Everything the widget renders travels through `ActivityAttributes` /
/// `ContentState`, so the extension never reads the app's `UserDefaults`.
enum FastingLiveActivity {
    /// When the current activity was requested. The system stops showing an
    /// activity on the Dynamic Island after 8 hours, so an older one is retired
    /// and rebuilt the next time the app comes to the foreground (which is what
    /// tapping the Lock Screen widget does).
    private static let startedAtKey = "fudai_fasting_activity_started_at"
    private static let refreshAfter: TimeInterval = 7.5 * 3600

    /// Reconciles the running activity with the store's active session.
    ///
    /// Safe to call often: it updates the existing activity in place, replaces an
    /// activity left over from a previous session, and ends everything when there
    /// is no active fast.
    static func sync(with session: FastingSession?) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            // The user turned Live Activities off; do not leave a stale card behind.
            endAll()
            return
        }

        guard let session else {
            endAll()
            return
        }

        let content = ActivityContent(
            state: FastingActivityAttributes.ContentState(
                startedAt: session.startedAt,
                goalMinutes: session.goalMinutes
            ),
            staleDate: session.goalDate
        )
        let attributes = FastingActivityAttributes(sessionID: session.id)
        let running = Activity<FastingActivityAttributes>.activities

        if let existing = running.first(where: { $0.attributes.sessionID == session.id }),
           !needsRefresh {
            Task { await existing.update(content) }
            return
        }

        // Either a different session is on screen, or this one has used up its
        // 8-hour Dynamic Island budget: retire everything and build it again.
        for activity in running {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }

        _ = try? Activity.request(attributes: attributes, content: content, pushType: nil)
        UserDefaults.standard.set(Date(), forKey: startedAtKey)
    }

    static func endAll() {
        UserDefaults.standard.removeObject(forKey: startedAtKey)
        let running = Activity<FastingActivityAttributes>.activities
        guard !running.isEmpty else { return }
        Task {
            for activity in running {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    /// Patches the fasting fields of the shared widget snapshot, so the Lock
    /// Screen widget reflects a fast started outside the app's UI (a background
    /// App Intent or a Shortcuts automation).
    static func publishSnapshot(active: FastingSession?) {
        guard let existing = WidgetSnapshot.read() else { return }
        let updated = existing.withFasting(
            active: active != nil,
            startedAt: active?.startedAt,
            goalMinutes: active?.goalMinutes
        )
        guard updated != existing else { return }
        WidgetSnapshot.write(updated)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private static var needsRefresh: Bool {
        guard let startedAt = UserDefaults.standard.object(forKey: startedAtKey) as? Date else {
            return true
        }
        return Date().timeIntervalSince(startedAt) >= refreshAfter
    }
}
