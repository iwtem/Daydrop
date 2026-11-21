import WidgetKit
import SwiftUI

struct DaydropWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DaydropCalendarEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallCalendarWidgetView(entry: entry)
        case .systemMedium:
            MediumCalendarWidgetView(entry: entry)
        case .systemLarge:
            LargeCalendarWidgetView(entry: entry)
        default:
            SmallCalendarWidgetView(entry: entry)
        }
    }
}

struct DaydropCalendarWidget: Widget {
    let kind: String = "DaydropCalendarWidget"

    var body: some WidgetConfiguration {
        let l10n = L10n.widgetCurrent
        return StaticConfiguration(kind: kind, provider: DaydropTimelineProvider()) { entry in
            DaydropWidgetEntryView(entry: entry)
        }
        .configurationDisplayName(l10n.widgetDisplayName)
        .description(l10n.widgetDescription)
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

@main
struct DaydropWidgetBundle: WidgetBundle {
    var body: some Widget {
        DaydropCalendarWidget()
    }
}
