import SwiftUI

/// Kurz-Auswertung direkt nach einer Trainingseinheit: Kennzahlen,
/// Vergleich mit dem bisherigen Bestwert und die schwächsten Zeichen.
struct ResultSummaryView: View {
    let lessonTitle: String
    let session: TrainingSession
    /// Bester bisher gespeicherter Punktwert dieser Lektion.
    let previousBestPoints: Int?
    let onDone: (_ save: Bool) -> Void

    private var isRecord: Bool {
        session.strokes > 0 && (previousBestPoints.map { session.points > $0 } ?? true)
    }

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: isRecord ? "trophy.fill" : "checkmark.seal.fill")
                .font(.system(size: 42))
                .foregroundStyle(isRecord ? AnyShapeStyle(.yellow) : AnyShapeStyle(.tint))
                .symbolEffect(.bounce, value: session.points)

            VStack(spacing: 4) {
                Text(lessonTitle)
                    .font(.title2.bold())
                Text(comparisonText)
                    .font(.callout)
                    .foregroundStyle(isRecord ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
            }

            Grid(horizontalSpacing: 36, verticalSpacing: 12) {
                GridRow {
                    metric("Punkte", "\(session.points)")
                    metric("Anschläge/min", "\(Int(session.strokesPerMinute))")
                }
                GridRow {
                    metric("Anschläge", "\(session.strokes)")
                    metric("Fehler", "\(session.errors)")
                }
                GridRow {
                    metric(
                        "Fehlerquote",
                        String(
                            format: "%.1f %%",
                            Scorer.errorRate(
                                errors: session.errors,
                                characters: max(1, session.typedCharacters)
                            )
                        )
                    )
                    metric(
                        "Dauer",
                        String(
                            format: "%d:%02d",
                            session.elapsedSeconds / 60,
                            session.elapsedSeconds % 60
                        )
                    )
                }
            }
            .padding(.vertical, 4)

            let worst = session.characterStats.worstCharacters(limit: 5)
            if !worst.isEmpty {
                VStack(spacing: 8) {
                    Text("Schwierige Zeichen in dieser Lektion")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        ForEach(Array(worst.enumerated()), id: \.offset) { _, character in
                            HStack(spacing: 5) {
                                KeyChip(character: character)
                                Text(String(format: "%.0f %%", session.characterStats.errorRate(of: character)))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            HStack {
                Button("Verwerfen", role: .cancel) { onDone(false) }
                Button("Speichern") { onDone(true) }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(32)
        .frame(minWidth: 440)
    }

    private var comparisonText: String {
        guard session.strokes > 0 else { return "Keine Anschläge – nichts zu speichern." }
        guard let best = previousBestPoints else { return "Dein erstes Ergebnis in dieser Lektion." }
        if session.points > best {
            return "Neuer Bestwert! Bisher \(best) Punkte."
        }
        if session.points == best {
            return "Bestwert eingestellt (\(best) Punkte)."
        }
        return "Bestwert: \(best) Punkte – noch \(best - session.points) Punkte dahinter."
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 120)
    }
}
