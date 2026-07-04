import SwiftUI

/// Kurz-Auswertung direkt nach einer Trainingseinheit.
struct ResultSummaryView: View {
    let lessonTitle: String
    let session: TrainingSession
    let onDone: (_ save: Bool) -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 42))
                .foregroundStyle(.tint)
                .symbolEffect(.bounce, value: session.points)

            Text(lessonTitle)
                .font(.title2.bold())

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
                                characters: max(1, session.dictatedCharacters - 1)
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
            .padding(.vertical, 8)

            HStack {
                Button("Verwerfen", role: .cancel) { onDone(false) }
                Button("Speichern") { onDone(true) }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(32)
        .frame(minWidth: 420)
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
