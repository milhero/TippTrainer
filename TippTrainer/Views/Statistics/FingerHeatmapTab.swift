import SwiftUI

/// Finger-Auswertung: Tastatur-Heatmap und beide Hände, jeweils nach
/// Fehlerquote gefärbt — so sieht man sofort, welche Finger noch Mühe machen.
struct FingerHeatmapTab: View {
    let charRecords: [CharRecord]
    let language: LessonLanguage

    private var layout: KeyboardModel { KeyboardModel.layout(for: language) }

    private var errorRateByKey: [String: Double] {
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
            VStack(alignment: .leading, spacing: 24) {
                if charRecords.isEmpty {
                    emptyHint
                }
                fingerSection
                keySection
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var emptyHint: some View {
        Text("Noch keine Anschläge erfasst. Nach der ersten gespeicherten Lektion erscheint hier, welche Finger und Tasten am häufigsten daneben liegen.")
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var fingerSection: some View {
        let rates = errorRateByFinger
        let labels = rates.mapValues { String(format: "%.0f %%", $0) }
        return VStack(alignment: .leading, spacing: 12) {
            Text("Fehlerquote je Finger")
                .font(.headline)
            HStack(alignment: .top, spacing: 32) {
                HandsView(
                    fill: { finger in Self.fingerColor(rates[finger]) },
                    labels: labels
                )
                .frame(width: 520)

                VStack(alignment: .leading, spacing: 10) {
                    fingerSummary(rates: rates)
                    legend
                }
                .padding(.top, 8)
            }
        }
    }

    private var keySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Fehlerquote je Taste")
                .font(.headline)
            HeatmapKeyboard(layout: layout, errorRateByKey: errorRateByKey)
        }
    }

    private static func fingerColor(_ rate: Double?) -> Color {
        guard let rate else { return Color.primary.opacity(0.08) }
        return HeatColor.color(forErrorRate: rate)
    }

    /// Die drei schwächsten Finger als Text — als Ergänzung zur Grafik.
    @ViewBuilder
    private func fingerSummary(rates: [Finger: Double]) -> some View {
        let worst = rates
            .filter { $0.value > 0 }
            .sorted { $0.value > $1.value }
            .prefix(3)
        if worst.isEmpty {
            Text(rates.isEmpty ? "Keine Daten." : "Keine Fehler – alle Finger sitzen.")
                .foregroundStyle(.secondary)
        } else {
            Text("Übungsbedarf")
                .font(.subheadline.weight(.semibold))
            ForEach(Array(worst), id: \.key) { finger, rate in
                HStack(spacing: 8) {
                    Circle()
                        .fill(HeatColor.color(forErrorRate: rate))
                        .frame(width: 10, height: 10)
                    Text(finger.germanName)
                    Spacer(minLength: 12)
                    Text(String(format: "%.1f %%", rate))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .font(.callout)
            }
        }
    }

    private var legend: some View {
        HStack(spacing: 8) {
            Text("0 %").font(.caption).foregroundStyle(.secondary)
            LinearGradient(
                colors: [
                    HeatColor.color(forErrorRate: 0),
                    HeatColor.color(forErrorRate: 10),
                    HeatColor.color(forErrorRate: 20),
                ],
                startPoint: .leading, endPoint: .trailing
            )
            .frame(width: 140, height: 10)
            .clipShape(Capsule())
            Text("20 %+").font(.caption).foregroundStyle(.secondary)
        }
        .padding(.top, 8)
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
        let rate = key.kind == .character ? errorRateByKey[key.id] : nil
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(rate.map { HeatColor.color(forErrorRate: $0) } ?? Color.primary.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08))
            )
            .overlay(
                VStack(spacing: 1) {
                    Text(key.label)
                        .font(.system(size: 11, weight: .medium))
                    if let rate {
                        Text(String(format: "%.0f", rate))
                            .font(.system(size: 8))
                            .opacity(0.8)
                    }
                }
                .foregroundStyle((rate ?? 0) > 8 ? .white : .primary)
            )
            .help(rate.map { String(format: "%@: %.1f %% Fehler", key.label, $0) } ?? key.label)
    }
}

enum HeatColor {
    /// Grün (0 %) → Gelb (10 %) → Rot (20 %+).
    static func color(forErrorRate rate: Double) -> Color {
        let clamped = min(max(rate, 0), 20) / 20
        let hue = (1 - clamped) * 0.33 // 0.33 = Grün, 0 = Rot
        return Color(hue: hue, saturation: 0.7, brightness: 0.85)
    }
}
