import SwiftUI

/// Das Trainingsfenster: Laufschrift oben, virtuelle Tastatur in der
/// Mitte, Statusleiste unten — plus Pause und Abbruch.
struct TrainingView: View {
    @State var viewModel: TrainingViewModel
    let onClose: (TrainingOutcome) -> Void

    @FocusState private var isFocused: Bool
    @State private var showsCancelDialog = false

    var body: some View {
        VStack(spacing: 18) {
            header

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
            } else {
                Spacer(minLength: 0)
            }

            statusBar
        }
        .padding(24)
        .frame(minWidth: 860, minHeight: 560)
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
                viewModel.pause()
                showsCancelDialog = true
            } label: {
                Label("Beenden", systemImage: "xmark")
            }
            .keyboardShortcut("b", modifiers: .option)
        }
        .buttonStyle(.bordered)
    }

    private var pauseOverlayText: String? {
        switch viewModel.session.state {
        case .ready: String(localized: "Leertaste startet das Diktat")
        case .paused: String(localized: "Pause – Leertaste setzt fort")
        default: nil
        }
    }

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
            Text(viewModel.statusHint)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
            statusItem(
                icon: "clock",
                label: "Zeit",
                value: viewModel.elapsedTimeText
            )
            statusItem(
                icon: "character.cursor.ibeam",
                label: "Zeichen",
                value: "\(max(0, viewModel.session.dictatedCharacters - 1))"
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
