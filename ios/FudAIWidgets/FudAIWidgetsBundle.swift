import WidgetKit
import SwiftUI

@main
struct FudAIWidgetsBundle: WidgetBundle {
    var body: some Widget {
        CalorieWidget()
        ProteinWidget()
        WaterWidget()
        LogFoodWidget()
        FastingWidget()
        FastingLiveActivityWidget()
        if #available(iOS 18.0, *) {
            VoiceAssistantControl()
        }
    }
}
