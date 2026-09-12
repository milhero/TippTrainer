import SwiftUI

/// Das Trainingsfenster: Schritt-Banner und Laufschrift oben, virtuelle
/// Tastatur in der Mitte, Statusleiste mit Fingerhinweis unten — plus Pause
/// und Abbruch.
struct TrainingView: View {
    @State var viewModel: TrainingViewModel
    let onClose: (TrainingOutcome) -> Void

    @FocusState private var isFocused: Bool
    @State private var showsCancelDialog = false

    var body: some View {
        VStack(spacing: 16) {
            header

            if !viewModel.session.steps.isEmpty {
                stepBanner
            }

            TickerView(
                text: viewModel.session.dictationText,
                cursorIndex: viewModel.session.cursorIndex,
                isError: viewModel.errorFlash,
                speedLevel: viewModel.tickerSpeedLevel,
                isPausedOverlay: pauseOverlayText
            )

            if viewModel.assistance.showKeyboard {
                if viewModel.unit == .numpad {
                    NumpadView(
                        currentCharacter: viewModel.currentCharacter,
                        showsBackspaceHint: viewModel.session.awaitingCorrection,
                        assistance: viewModel.assistance
                    )
                    .frame(maxWidth: .infinity)
                } else {
                    KeyboardView(
                        layout: viewModel.layout,
                        currentCharacter: viewModel.session.state == .running
                            ? viewModel.currentCharacter : nil,
                        showsBackspaceHint: viewModel.session.awaitingCorrection,
                        assistance: viewModel.assistance
                    )
                }
            }

            Spacer(minLength: 0)

            statusBar
        }
        .padding(24)
        .frame(
            minWidth: 860, maxWidth: .infinity,
            minHeight: 560, maxHeight: .infinity,
            alignment: .top
        )
        .background(Color(nsColor: .windowBackgroundColor))
        .focusable()
        .focused($isFocused)
        .focusEffectDisabled()
        .onKeyPress(phases: .down) { press in
            viewModel.handle(press)
        }
        .onAppear { isFocused = true }
        .sheet(isPresented: $viewModel.showsResult) {
            ResultSummaryView(
                lessonTitle: viewModel.lessonTitle,
                session: viewModel.session,
                previousBestPoints: viewModel.previousBestPoints,
                onDone: { save in
                    onClose(save ? .finished : .discarded)
                }
            )
        }
        .confirmationDialog(
            "Lektion vorzeitig beenden?",
            isPresented: $showsCancelDialog
        ) {
            Button("Beenden und Ergebnis ansehen") {
                viewModel.cancel()
            }
            Button("Beenden ohne Speichern", role: .destructive) {
                onClose(.discarded)
            }
            Button("Weiter üben", role: .cancel) {}
        }
    }

    // MARK: - Kopf

    private var header: some View {
        HStack {
            Text(viewModel.lessonTitle)
                .font(.title2.bold())
            Spacer()
            Button {
                viewModel.pause()
            } label: {
                Label("Pause", systemImage: "pause.fill")
            }
            .keyboardShortcut("p", modifiers: .option)
            .disabled(viewModel.session.state != .running)

            Button(role: .cancel) {
                requestClose()
            } label: {
                Label("Beenden", systemImage: "xmark")
            }
            .keyboardShortcut(.cancelAction)
        }
        .buttonStyle(.bordered)
    }

    /// Solange noch nichts getippt wurde, gibt es nichts zu verlieren:
    /// dann schließt »Beenden« ohne Rückfrage.
    private func requestClose() {
        let session = viewModel.session
        if session.strokes == 0 && session.errors == 0 {
            onClose(.discarded)
        } else {
            viewModel.pause()
            showsCancelDialog = true
        }
    }

    // MARK: - Lernschritte

    @ViewBuilder
    private var stepBanner: some View {
        let session = viewModel.session
        if let step = session.currentStep, let index = session.currentStepIndex {
            StepBanner(step: step, index: index, total: session.steps.count)
        } else {
            FreePracticeBanner(intelligence: session.configuration.intelligence)
        }
    }

    private var pauseOverlayText: String? {
        switch viewModel.session.state {
        case .ready: String(localized: "Leertaste startet das Diktat")
        case .paused: String(localized: "Pause – Leertaste setzt fort")
        default: nil
        }
    }

    // MARK: - Statusleiste

    private var statusBar: some View {
        HStack(spacing: 22) {
            statusItem(
                icon: "exclamationmark.triangle",
                label: "Fehler",
                value: "\(viewModel.session.errors)"
            )
            statusItem(
                icon: "speedometer",
                label: "A/min",
                value: "\(Int(viewModel.session.strokesPerMinute))"
            )
            Spacer()
            if viewModel.assistance.showStatusHints {
                HandsView(
                    highlighted: viewModel.currentFinger.map { [$0] } ?? [],
                    secondary: viewModel.currentShiftFinger.map { [$0] } ?? []
                )
                .frame(height: 40)
                .animation(.snappy(duration: 0.15), value: viewModel.currentFinger)
            }
            Text(viewModel.statusHint)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(minWidth: 220, alignment: .leading)
            Spacer()
            statusItem(
                icon: "clock",
                label: "Zeit",
                value: viewModel.elapsedTimeText
            )
            statusItem(
                icon: "character.cursor.ibeam",
                label: "Zeichen",
                value: "\(viewModel.session.typedCharacters)"
            )
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.background.secondary)
        )
    }

    private func statusItem(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .font(.system(size: 12))
            Text(value)
                .font(.system(.body, design: .rounded).weight(.semibold))
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .animation(.snappy, value: value)
    }
}

enum TrainingOutcome {
    case finished
    case discarded
}

// MARK: - Banner

/// Erklärt den laufenden Lernschritt und zeigt die beteiligten Finger.
private struct StepBanner: View {
    let step: LessonStep
    let index: Int
    let total: Int

    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Text("Schritt \(index + 1) von \(total)")
                        .font(.caption.weight(.semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(.tint)
                    HStack(spacing: 3) {
                        ForEach(0..<total, id: \.self) { position in
                            Capsule()
                                .fill(position <= index
                                    ? Color.accentColor : Color.primary.opacity(0.12))
                                .frame(width: 16, height: 4)
                        }
                    }
                }
                Text(step.title)
                    .font(.headline)
                Text(step.hint)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            HandsView(highlighted: Set(step.fingers))
                .frame(width: 150)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.accentColor.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.accentColor.opacity(0.2))
        )
        .animation(.smooth(duration: 0.25), value: index)
    }
}

/// Kompakter Hinweis nach den Lernschritten.
private struct FreePracticeBanner: View {
    let intelligence: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: intelligence ? "brain.head.profile" : "list.number")
                .foregroundStyle(.tint)
            Text("Freies Üben")
                .font(.headline)
            Text(intelligence
                ? "Die Intelligenz wählt jetzt bevorzugt Wörter mit deinen Fehlerzeichen."
                : "Die Lektion wird jetzt der Reihe nach diktiert.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.background.secondary)
        )
    }
}
