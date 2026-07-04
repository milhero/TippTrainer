import SwiftData
import SwiftUI

/// Die Lernstatistik mit den sechs Auswertungsansichten des Vorbilds:
/// Bericht, Lektionenübersicht, Verlauf, Schriftzeichen, Finger, Vergleich.
struct StatisticsView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case report, lessons, progress, characters, fingers, comparison
        var id: String { rawValue }
        var title: LocalizedStringKey {
            switch self {
            case .report: "Bericht"
            case .lessons: "Lektionen"
            case .progress: "Verlauf"
            case .characters: "Schriftzeichen"
            case .fingers: "Finger"
            case .comparison: "Vergleich"
            }
        }
        var icon: String {
            switch self {
            case .report: "doc.text"
            case .lessons: "list.bullet.rectangle"
            case .progress: "chart.xyaxis.line"
            case .characters: "character"
            case .fingers: "hand.raised"
            case .comparison: "chart.bar"
            }
        }
    }

    @Environment(AppSettings.self) private var settings
    @Query(sort: \LessonRecord.date, order: .reverse) private var records: [LessonRecord]
    @Query private var charRecords: [CharRecord]
    @State private var tab: Tab = .report

    private static var launchTab: Tab? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--tab"),
            arguments.indices.contains(index + 1)
        else { return nil }
        return Tab(rawValue: arguments[index + 1])
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                ForEach(Tab.allCases) { tab in
                    Label(tab.title, systemImage: tab.icon).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelStyle(.titleAndIcon)
            .padding(16)

            Divider()

            if records.isEmpty && tab != .comparison && tab != .fingers {
                ContentUnavailableView(
                    "Noch keine Daten",
                    systemImage: "chart.line.downtrend.xyaxis",
                    description: Text("Absolviere eine Lektion, um deine Fortschritte zu sehen.")
                )
            } else {
                content
            }
        }
        .onAppear {
            if let launchTab = Self.launchTab { tab = launchTab }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .report:
            ReportTab(record: records.first, charRecords: charRecords)
        case .lessons:
            LessonListTab(records: records)
        case .progress:
            ProgressChartTab(records: records)
        case .characters:
            CharacterTableTab(charRecords: charRecords)
        case .fingers:
            FingerHeatmapTab(charRecords: charRecords, language: settings.language)
        case .comparison:
            ComparisonTab(records: records)
        }
    }
}
