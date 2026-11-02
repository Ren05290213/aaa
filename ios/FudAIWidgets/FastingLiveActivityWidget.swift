import ActivityKit
import SwiftUI
import WidgetKit

/// Fasting Live Activity: the running fast on the Dynamic Island and the Lock
/// Screen. Started and updated by `FastingLiveActivity` in the app target.
struct FastingLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FastingActivityAttributes.self) { context in
            FastingLockScreenView(state: context.state)
                .activityBackgroundTint(Color.black.opacity(0.35))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text("Fasting")
                            .font(.headline)
                    } icon: {
                        Image(systemName: "timer")
                    }
                    .foregroundStyle(WidgetPalette.calorie)
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    FastingElapsedText(startedAt: context.state.startedAt)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(WidgetPalette.calorie)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    FastingProgress(state: context.state)
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(WidgetPalette.calorie)
            } compactTrailing: {
                FastingElapsedText(startedAt: context.state.startedAt)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(WidgetPalette.calorie)
                    .frame(width: 48)
            } minimal: {
                Image(systemName: "timer")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(WidgetPalette.calorie)
            }
            .keylineTint(WidgetPalette.calorie)
        }
    }
}

/// Counts up past `startedAt`, redrawn by the system — no timeline refresh needed.
private struct FastingElapsedText: View {
    let startedAt: Date

    var body: some View {
        Text(startedAt, style: .timer)
            .monospacedDigit()
    }
}

private struct FastingProgress: View {
    let state: FastingActivityAttributes.ContentState

    var body: some View {
        let goalDate = state.startedAt.addingTimeInterval(TimeInterval(max(1, state.goalMinutes) * 60))
        VStack(spacing: 6) {
            ProgressView(timerInterval: state.startedAt...goalDate, countsDown: false) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .tint(WidgetPalette.calorie)

            HStack(spacing: 6) {
                Text("Started \(state.startedAt.formatted(date: .omitted, time: .shortened))")
                Spacer(minLength: 4)
                Text("Goal \(FastingGoalText.short(minutes: state.goalMinutes))")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 2)
    }
}

private struct FastingLockScreenView: View {
    let state: FastingActivityAttributes.ContentState

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: "timer")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(WidgetPalette.calorie)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Fasting")
                        .font(.headline)
                    Text("Goal \(FastingGoalText.short(minutes: state.goalMinutes))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                FastingElapsedText(startedAt: state.startedAt)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(WidgetPalette.calorie)
                    .frame(maxWidth: 96, alignment: .trailing)
            }

            FastingProgress(state: state)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

private enum FastingGoalText {
    static func short(minutes: Int) -> String {
        let hours = minutes / 60
        let remainder = minutes % 60
        if hours == 0 { return "\(remainder)m" }
        if remainder == 0 { return "\(hours)h" }
        return "\(hours)h \(remainder)m"
    }
}
