import SwiftUI

/// Vergleichstabelle: ordnet die eigene Schreibleistung in Erfahrungswerte
/// ein (Anschläge pro Minute).
struct ComparisonTab: View {
    let records: [LessonRecord]

    private struct Level: Identifiable {
        let id = UUID()
        let name: String
        let range: String
        let lowerBound: Int
        let detail: String
    }

    private let levels: [Level] = [
        Level(name: "Anfänger", range: "unter 100 A/min",
              lowerBound: 0, detail: "Die Grundstellung sitzt, der Blick löst sich von der Tastatur."),
        Level(name: "Geübt", range: "100–200 A/min",
              lowerBound: 100, detail: "Flüssiges Schreiben ohne Suchen – alltagstauglich."),
        Level(name: "Fortgeschritten", range: "200–300 A/min",
              lowerBound: 200, detail: "Schnelles, sicheres Zehnfingerschreiben."),
        Level(name: "Profi", range: "300–400 A/min",
              lowerBound: 300, detail: "Bürotempo auf professionellem Niveau."),
        Level(name: "Experte", range: "über 400 A/min",
              lowerBound: 400, detail: "Schreibmaschinen-Wettkampfklasse."),
    ]

    private var bestSpeed: Int {
        records.map(\.strokesPerMinute).max() ?? 0
    }

    private var currentLevelIndex: Int {
        levels.lastIndex { bestSpeed >= $0.lowerBound } ?? 0
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Deine Bestleistung")
                        .font(.headline)
                    Spacer()
                    Text("\(bestSpeed) A/min")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(.tint)
                }

                ForEach(Array(levels.enumerated()), id: \.element.id) { index, level in
                    levelRow(index: index, level: level)
                }
            }
            .padding(24)
        }
    }

    private func levelRow(index: Int, level: Level) -> some View {
        let isCurrent = index == currentLevelIndex
        let reached = index <= currentLevelIndex
        return HStack(spacing: 14) {
            Image(systemName: reached ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isCurrent ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(level.name).font(.headline)
                Text(level.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(level.range)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isCurrent
                    ? Color.accentColor.opacity(0.12)
                    : Color(nsColor: .controlBackgroundColor).opacity(0.5))
        )
    }
}
