import Charts
import SwiftUI

// MARK: - Bericht

/// Auswertungsbericht der zuletzt absolvierten Lektion.
struct ReportTab: View {
    let record: LessonRecord?
    let charRecords: [CharRecord]

    var body: some View {
        ScrollView {
            if let record {
                VStack(alignment: .leading, spacing: 20) {
                    Text(record.lessonTitle)
                        .font(.title2.bold())
                    Text(record.date.formatted(date: .abbreviated, time: .shortened))
                        .foregroundStyle(.secondary)

                    metricRow(for: record)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Problematische Zeichen")
                            .font(.headline)
                        let worst = charRecords
                            .filter { $0.targetErrors > 0 }
                            .sorted { $0.errorRate > $1.errorRate }
                            .prefix(8)
                        if worst.isEmpty {
                            Text("Keine auffälligen Fehler – weiter so!")
                                .foregroundStyle(.secondary)
                        } else {
                            FlowChips(chars: Array(worst))
                        }
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func metricRow(for record: LessonRecord) -> some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 130), spacing: 12)],
            spacing: 12
        ) {
            StatTile(label: "Punkte", value: "\(record.points)", icon: "star.fill")
            StatTile(label: "Anschläge/min", value: "\(record.strokesPerMinute)", icon: "speedometer")
            StatTile(label: "Anschläge", value: "\(record.strokes)", icon: "keyboard")
            StatTile(label: "Fehler", value: "\(record.errors)", icon: "exclamationmark.triangle")
            StatTile(
                label: "Fehlerquote",
                value: String(format: "%.1f %%", record.errorRate),
                icon: "percent"
            )
            StatTile(
                label: "Dauer",
                value: String(format: "%d:%02d", record.seconds / 60, record.seconds % 60),
                icon: "clock"
            )
        }
    }
}

// MARK: - Lektionenübersicht

struct LessonListTab: View {
    let records: [LessonRecord]
    @State private var filter: LessonKind?

    var body: some View {
        VStack(spacing: 0) {
            Picker("Filter", selection: $filter) {
                Text("Alle").tag(LessonKind?.none)
                ForEach(LessonKind.allCases, id: \.self) { kind in
                    Text(kind.label).tag(LessonKind?.some(kind))
                }
            }
            .pickerStyle(.segmented)
            .padding(12)

            Table(filtered) {
                TableColumn("Datum") { record in
                    Text(record.date.formatted(date: .abbreviated, time: .shortened))
                }
                TableColumn("Lektion", value: \.lessonTitle)
                TableColumn("Punkte") { Text("\($0.points)") }
                TableColumn("A/min") { Text("\($0.strokesPerMinute)") }
                TableColumn("Fehler") { Text("\($0.errors)") }
                TableColumn("Quote") { Text(String(format: "%.1f %%", $0.errorRate)) }
            }
        }
    }

    private var filtered: [LessonRecord] {
        guard let filter else { return records }
        return records.filter { $0.kind == filter }
    }
}

// MARK: - Verlaufsdiagramm

/// Punkte und Anschläge pro Minute je gespeicherter Lektion, in zeitlicher
/// Reihenfolge. Die x-Achse zählt die Lektionen durch — mehrere Übungen am
/// selben Tag bleiben so unterscheidbar.
struct ProgressChartTab: View {
    let records: [LessonRecord]

    private var ordered: [(number: Int, record: LessonRecord)] {
        records
            .sorted { $0.date < $1.date }
            .enumerated()
            .map { (number: $0.offset + 1, record: $0.element) }
    }

    var body: some View {
        let data = ordered
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if data.count < 2 {
                    Text("Ab der zweiten gespeicherten Lektion zeigt die Linie deine Entwicklung. Bisher gespeichert: \(data.count).")
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Punkte")
                        .font(.headline)
                    Chart(data, id: \.number) { item in
                        LineMark(
                            x: .value("Lektion", item.number),
                            y: .value("Punkte", item.record.points)
                        )
                        .foregroundStyle(.tint)
                        .interpolationMethod(.monotone)
                        PointMark(
                            x: .value("Lektion", item.number),
                            y: .value("Punkte", item.record.points)
                        )
                        .foregroundStyle(by: .value("Art", item.record.kind.label))
                        .symbolSize(70)
                    }
                    .chartForegroundStyleScale([
                        LessonKind.practice.label: Color.primary,
                        LessonKind.dictation.label: Color.blue,
                        LessonKind.own.label: Color.green,
                    ])
                    .chartXScale(domain: 1...max(2, data.count))
                    .chartXAxisLabel("Gespeicherte Lektionen, chronologisch")
                    .chartYAxisLabel("Punkte")
                    .frame(height: 260)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Anschläge pro Minute und Fehlerquote")
                        .font(.headline)
                    Chart(data, id: \.number) { item in
                        BarMark(
                            x: .value("Lektion", item.number),
                            y: .value("A/min", item.record.strokesPerMinute)
                        )
                        .foregroundStyle(.tint.opacity(0.45))
                    }
                    .chartXScale(domain: 0.5...(Double(max(2, data.count)) + 0.5))
                    .chartYAxisLabel("A/min")
                    .frame(height: 160)
                    Chart(data, id: \.number) { item in
                        LineMark(
                            x: .value("Lektion", item.number),
                            y: .value("Fehlerquote", item.record.errorRate)
                        )
                        .foregroundStyle(.orange)
                        .interpolationMethod(.monotone)
                        PointMark(
                            x: .value("Lektion", item.number),
                            y: .value("Fehlerquote", item.record.errorRate)
                        )
                        .foregroundStyle(.orange)
                    }
                    .chartXScale(domain: 1...max(2, data.count))
                    .chartYAxisLabel("Fehler in %")
                    .frame(height: 140)
                }

                if let latest = data.last {
                    Text("Zuletzt: \(latest.record.lessonTitle), \(latest.record.date.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Schriftzeichen

struct CharacterTableTab: View {
    let charRecords: [CharRecord]

    var body: some View {
        Table(sorted) {
            TableColumn("Zeichen") { record in
                Text(displayCharacter(record.character))
                    .font(.body.monospaced())
            }
            TableColumn("Diktiert") { Text("\($0.occurrences)") }
            TableColumn("Fehler") { Text("\($0.targetErrors)") }
            TableColumn("Fehlerquote") { record in
                HStack {
                    ProgressView(value: min(record.errorRate, 100), total: 100)
                        .frame(width: 80)
                    Text(String(format: "%.1f %%", record.errorRate))
                        .monospacedDigit()
                }
            }
        }
    }

    private var sorted: [CharRecord] {
        charRecords
            .filter { $0.occurrences > 0 }
            .sorted { $0.errorRate > $1.errorRate }
    }

    private func displayCharacter(_ character: Character) -> String {
        character == " " ? "␣ (Leer)" : String(character)
    }
}

// MARK: - Bausteine

struct StatTile: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon).foregroundStyle(.tint)
            Text(value)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.background.secondary)
        )
    }
}

struct FlowChips: View {
    let chars: [CharRecord]

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 90), spacing: 8)],
            spacing: 8
        ) {
            ForEach(chars, id: \.unicode) { record in
                HStack(spacing: 6) {
                    Text(record.character == " " ? "␣" : String(record.character))
                        .font(.body.monospaced().bold())
                    Text(String(format: "%.0f %%", record.errorRate))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(Color.orange.opacity(0.15))
                )
            }
        }
    }
}
