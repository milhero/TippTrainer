import SwiftUI

/// Finger-Auswertung als Heatmap: färbt jede Taste nach ihrer Fehlerquote
/// ein — so sieht man sofort, welche Finger noch Mühe machen.
struct FingerHeatmapTab: View {
    let charRecords: [CharRecord]
    let language: LessonLanguage

    private var errorRateByKey: [String: Double] {
        let layout = KeyboardModel.layout(for: language)
        var rates: [String: (errors: Int, total: Int)] = [:]
        for record in charRecords where record.occurrences > 0 {
            guard let stroke = layout.stroke(for: record.character) else { continue }
            var entry = rates[stroke.keyID] ?? (0, 0)
            entry.errors += record.targetErrors
            entry.total += record.occurrences
            rates[stroke.keyID] = entry
        }
        return rates.mapValues { $0.total > 0 ? Double($0.errors) * 100 / Double($0.total) : 0 }
    }

    private var errorRateByFinger: [Finger: Double] {
        let layout = KeyboardModel.layout(for: language)
        var rates: [Finger: (errors: Int, total: Int)] = [:]
        for record in charRecords where record.occurrences > 0 {
            guard let finger = layout.finger(for: record.character) else { continue }
            var entry = rates[finger] ?? (0, 0)
            entry.errors += record.targetErrors
            entry.total += record.occurrences
            rates[finger] = entry
        }
        return rates.mapValues { $0.total > 0 ? Double($0.errors) * 100 / Double($0.total) : 0 }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Fehlerquote je Taste")
                    .font(.headline)
                HeatmapKeyboard(
                    layout: KeyboardModel.layout(for: language),
                    errorRateByKey: errorRateByKey
                )

                legend

                Text("Fehlerquote je Finger")
                    .font(.headline)
                fingerBars
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var legend: some View {
        HStack(spacing: 8) {
            Text("0 %").font(.caption).foregroundStyle(.secondary)
            LinearGradient(
                colors: [.green.opacity(0.35), .yellow.opacity(0.6), .red.opacity(0.85)],
                startPoint: .leading, endPoint: .trailing
            )
            .frame(width: 160, height: 10)
            .clipShape(Capsule())
            Text("20 %+").font(.caption).foregroundStyle(.secondary)
        }
    }

    private var fingerBars: some View {
        let rates = errorRateByFinger
        return VStack(spacing: 8) {
            ForEach(Finger.allCases, id: \.self) { finger in
                HStack {
                    Text(finger.germanName)
                        .font(.callout)
                        .frame(width: 180, alignment: .leading)
                    GeometryReader { geo in
                        let rate = rates[finger] ?? 0
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.primary.opacity(0.08))
                            Capsule()
                                .fill(HeatColor.color(forErrorRate: rate))
                                .frame(width: geo.size.width * min(rate / 20, 1))
                        }
                    }
                    .frame(height: 14)
                    Text(String(format: "%.1f %%", rates[finger] ?? 0))
                        .font(.caption.monospacedDigit())
                        .frame(width: 60, alignment: .trailing)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// Statische Tastatur, deren Tasten nach Fehlerquote gefärbt sind.
/// Feste Tastengröße (kein GeometryReader) — robust in der ScrollView.
private struct HeatmapKeyboard: View {
    let layout: KeyboardModel
    let errorRateByKey: [String: Double]

    private let unit: CGFloat = 42
    private let keyHeight: CGFloat = 38
    private let gap: CGFloat = 5

    var body: some View {
        VStack(alignment: .leading, spacing: gap) {
            ForEach(Array(layout.rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: gap) {
                    ForEach(row) { key in
                        keyCap(for: key)
                            .frame(
                                width: unit * key.width + gap * (key.width - 1),
                                height: keyHeight
                            )
                    }
                }
            }
        }
        .fixedSize()
    }

    @ViewBuilder
    private func keyCap(for key: KeyboardKey) -> some View {
        let rate = errorRateByKey[key.id]
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(
                key.kind == .character && rate != nil
                    ? HeatColor.color(forErrorRate: rate!)
                    : Color.primary.opacity(0.05)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08))
            )
            .overlay(
                Text(key.label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(rate ?? 0 > 8 ? .white : .primary)
            )
    }
}

enum HeatColor {
    /// Grün (0 %) → Gelb (10 %) → Rot (20 %+).
    static func color(forErrorRate rate: Double) -> Color {
        let clamped = min(max(rate, 0), 20) / 20
        let hue = (1 - clamped) * 0.33 // 0.33 = Grün, 0 = Rot
        return Color(hue: hue, saturation: 0.75, brightness: 0.85)
    }
}
