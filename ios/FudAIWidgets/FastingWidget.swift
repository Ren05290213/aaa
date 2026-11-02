import SwiftUI
import WidgetKit

// MARK: - Eating window (read straight from the shared App Group)

/// The daily eating window, e.g. 08:00–16:00. Stored in the App Group by
/// Settings → Notifications → Eating Window, so the widget can compute the
/// current phase without the app running.
enum EatingWindow {
    static let enabledKey = "fudai_eating_window_enabled"
    static let startKey = "fudai_eating_window_start_minutes"
    static let endKey = "fudai_eating_window_end_minutes"

    static let defaultStartMinutes = 8 * 60
    static let defaultEndMinutes = 16 * 60

    struct Schedule: Equatable {
        let startMinutes: Int
        let endMinutes: Int
    }

    static func load() -> Schedule? {
        let defaults = WidgetSnapshot.sharedDefaults ?? .standard
        guard defaults.bool(forKey: enabledKey) else { return nil }
        let start = defaults.object(forKey: startKey) as? Int ?? defaultStartMinutes
        let end = defaults.object(forKey: endKey) as? Int ?? defaultEndMinutes
        guard start != end else { return nil }
        return Schedule(startMinutes: start, endMinutes: end)
    }

    /// When the current phase ends, so the timeline knows when to redraw.
    static func boundary(now: Date, schedule: Schedule, calendar: Calendar) -> (phase: Phase, end: Date) {
        let dayStart = calendar.startOfDay(for: now)
        func date(_ minutes: Int, plusDays days: Int = 0) -> Date {
            let day = calendar.date(byAdding: .day, value: days, to: dayStart) ?? dayStart
            return calendar.date(byAdding: .minute, value: minutes, to: day) ?? day
        }
        let startToday = date(schedule.startMinutes)
        let endToday = date(schedule.endMinutes)

        if schedule.startMinutes < schedule.endMinutes {
            if now >= startToday && now < endToday {
                return (.eating, endToday)
            }
            let nextStart = now < startToday ? startToday : date(schedule.startMinutes, plusDays: 1)
            return (.fasting, nextStart)
        }

        // Window wraps past midnight (e.g. 20:00–04:00).
        if now >= startToday {
            return (.eating, date(schedule.endMinutes, plusDays: 1))
        }
        if now < endToday {
            return (.eating, endToday)
        }
        return (.fasting, startToday)
    }

    enum Phase { case eating, fasting }

    static func timeText(minutes: Int) -> String {
        String(format: "%02d:%02d", (minutes / 60) % 24, minutes % 60)
    }
}

// MARK: - Timeline

enum FastingWidgetState: Equatable {
    /// A fast the user started by hand: elapsed counts up from `startedAt`.
    case manual(startedAt: Date, goalMinutes: Int)
    case eating(until: Date, schedule: EatingWindow.Schedule)
    case fasting(until: Date, schedule: EatingWindow.Schedule, since: Date)
    case idle
}

struct FastingWidgetEntry: TimelineEntry {
    let date: Date
    let state: FastingWidgetState
}

struct FastingWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> FastingWidgetEntry {
        FastingWidgetEntry(
            date: Date(),
            state: .manual(startedAt: Date().addingTimeInterval(-6 * 3600), goalMinutes: 16 * 60)
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (FastingWidgetEntry) -> Void) {
        completion(entry(at: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FastingWidgetEntry>) -> Void) {
        let now = Date()
        let entry = entry(at: now)
        let calendar = Calendar.current

        // Redraw exactly when the phase flips (or the manual fast hits its goal).
        let refresh: Date
        switch entry.state {
        case .manual(let startedAt, let goalMinutes):
            let goalDate = startedAt.addingTimeInterval(TimeInterval(goalMinutes * 60))
            refresh = goalDate > now ? goalDate : calendar.date(byAdding: .minute, value: 30, to: now) ?? now.addingTimeInterval(1_800)
        case .eating(let until, _), .fasting(let until, _, _):
            refresh = until > now ? until : calendar.date(byAdding: .minute, value: 30, to: now) ?? now.addingTimeInterval(1_800)
        case .idle:
            refresh = calendar.date(byAdding: .minute, value: 30, to: now) ?? now.addingTimeInterval(1_800)
        }
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }

    private func entry(at now: Date) -> FastingWidgetEntry {
        // A hand-started fast always wins: it has a goal and an exact start.
        if let snapshot = WidgetSnapshot.read(),
           snapshot.fastingActive == true,
           let startedAt = snapshot.fastingStartedAt {
            let goalMinutes = snapshot.fastingGoalMinutes ?? 16 * 60
            let goalDate = startedAt.addingTimeInterval(TimeInterval(goalMinutes * 60))
            // A fast left running past its 12-hour Live Activity window is stale.
            if now < goalDate.addingTimeInterval(4 * 3600) {
                return FastingWidgetEntry(date: now, state: .manual(startedAt: startedAt, goalMinutes: goalMinutes))
            }
        }

        if let schedule = EatingWindow.load() {
            let calendar = Calendar.current
            let result = EatingWindow.boundary(now: now, schedule: schedule, calendar: calendar)
            switch result.phase {
            case .eating:
                return FastingWidgetEntry(date: now, state: .eating(until: result.end, schedule: schedule))
            case .fasting:
                let since = result.end.addingTimeInterval(-TimeInterval(fastingLength(schedule) * 60))
                return FastingWidgetEntry(date: now, state: .fasting(until: result.end, schedule: schedule, since: since))
            }
        }

        return FastingWidgetEntry(date: now, state: .idle)
    }

    /// Length of the fasting phase implied by a schedule (24 h minus the window).
    private func fastingLength(_ schedule: EatingWindow.Schedule) -> Int {
        let window = schedule.endMinutes > schedule.startMinutes
            ? schedule.endMinutes - schedule.startMinutes
            : 24 * 60 - schedule.startMinutes + schedule.endMinutes
        return max(60, 24 * 60 - window)
    }
}

// MARK: - Widget

struct FastingWidget: Widget {
    let kind = "FastingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FastingWidgetProvider()) { entry in
            FastingWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(.systemBackground)
                }
        }
        .configurationDisplayName("Fud AI Fasting")
        .description("Your fasting or eating window countdown, all day.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .systemSmall,
        ])
    }
}

// MARK: - Views

struct FastingWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: FastingWidgetEntry

    var body: some View {
        switch family {
        case .accessoryInline:
            Text(inlineText)
        case .accessoryCircular:
            circularBody
        case .accessoryRectangular:
            rectangularBody
        default:
            smallBody
        }
    }

    // MARK: Text

    private var title: String {
        switch entry.state {
        case .manual: return "Fasting"
        case .eating: return "Eating"
        case .fasting: return "Fasting"
        case .idle: return "No fast"
        }
    }

    private var inlineText: String {
        switch entry.state {
        case .manual(let startedAt, let goalMinutes):
            let goalDate = startedAt.addingTimeInterval(TimeInterval(goalMinutes * 60))
            return "Fasting until \(goalDate.formatted(date: .omitted, time: .shortened))"
        case .eating(let until, _):
            return "Eating until \(until.formatted(date: .omitted, time: .shortened))"
        case .fasting(let until, _, _):
            return "Fasting until \(until.formatted(date: .omitted, time: .shortened))"
        case .idle:
            return "No fast running"
        }
    }

    private var subtitle: String {
        switch entry.state {
        case .manual(_, let goalMinutes):
            return "Goal \(goalText(goalMinutes))"
        case .eating(_, let schedule):
            return "\(EatingWindow.timeText(minutes: schedule.startMinutes)) – \(EatingWindow.timeText(minutes: schedule.endMinutes))"
        case .fasting(_, let schedule, _):
            return "\(EatingWindow.timeText(minutes: schedule.startMinutes)) – \(EatingWindow.timeText(minutes: schedule.endMinutes))"
        case .idle:
            return "Set an eating window"
        }
    }

    private func goalText(_ minutes: Int) -> String {
        let hours = minutes / 60
        let remainder = minutes % 60
        if hours == 0 { return "\(remainder)m" }
        if remainder == 0 { return "\(hours)h" }
        return "\(hours)h \(remainder)m"
    }

    // MARK: Progress

    private var progress: Double {
        switch entry.state {
        case .manual(let startedAt, let goalMinutes):
            let total = TimeInterval(max(60, goalMinutes) * 60)
            return min(1, max(0, entry.date.timeIntervalSince(startedAt) / total))
        case .eating(_, let schedule):
            let window = schedule.endMinutes > schedule.startMinutes
                ? schedule.endMinutes - schedule.startMinutes
                : 24 * 60 - schedule.startMinutes + schedule.endMinutes
            let elapsed = eatingElapsed(schedule)
            return min(1, max(0, Double(elapsed) / Double(max(1, window))))
        case .fasting(_, _, let since):
            let total = max(1, entry.date.timeIntervalSince(since))
            let boundary = boundaryDate
            let whole = max(total, boundary.timeIntervalSince(since))
            return min(1, max(0, total / whole))
        case .idle:
            return 0
        }
    }

    private var boundaryDate: Date {
        switch entry.state {
        case .manual(let startedAt, let goalMinutes):
            return startedAt.addingTimeInterval(TimeInterval(goalMinutes * 60))
        case .eating(let until, _), .fasting(let until, _, _):
            return until
        case .idle:
            return entry.date
        }
    }

    private func eatingElapsed(_ schedule: EatingWindow.Schedule) -> Int {
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.hour, .minute], from: entry.date)
        let now = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        if schedule.startMinutes < schedule.endMinutes {
            return max(0, now - schedule.startMinutes)
        }
        return now >= schedule.startMinutes
            ? now - schedule.startMinutes
            : 24 * 60 - schedule.startMinutes + now
    }

    // MARK: Layouts

    private var circularBody: some View {
        Gauge(value: progress) {
            Image(systemName: entry.state.isEating ? "fork.knife" : "timer")
        } currentValueLabel: {
            switch entry.state {
            case .manual(let startedAt, _):
                Text(startedAt, style: .timer)
                    .monospacedDigit()
            case .eating(let until, _), .fasting(let until, _, _):
                Text(until, style: .relative)
            case .idle:
                Image(systemName: "timer")
            }
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .tint(WidgetPalette.calorie)
    }

    private var rectangularBody: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: entry.state.isEating ? "fork.knife" : "timer")
                Text(title)
                    .font(.headline)
                Spacer(minLength: 2)
                countdownView
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .monospacedDigit()
            }
            ProgressView(value: progress)
                .tint(WidgetPalette.calorie)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var smallBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: entry.state.isEating ? "fork.knife" : "timer")
                    .foregroundStyle(WidgetPalette.calorie)
                Text(title)
                    .font(.headline)
                Spacer(minLength: 0)
            }
            countdownView
                .font(.system(.title2, design: .rounded, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(WidgetPalette.calorie)
            ProgressView(value: progress)
                .tint(WidgetPalette.calorie)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    /// A manual fast counts up from its start; a schedule counts down to the
    /// next boundary. Both styles are redrawn by the system, so the widget stays
    /// live between timeline refreshes.
    @ViewBuilder
    private var countdownView: some View {
        switch entry.state {
        case .manual(let startedAt, _):
            Text(startedAt, style: .timer)
        case .eating(let until, _), .fasting(let until, _, _):
            Text(until, style: .relative)
        case .idle:
            Text("—")
        }
    }
}

private extension FastingWidgetState {
    var isEating: Bool {
        if case .eating = self { return true }
        return false
    }
}
