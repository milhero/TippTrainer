import SwiftData
import SwiftUI

/// Oberste Navigation: wechselt zwischen Start, Training, Statistik und
/// dem Buchstabenregen-Spiel.
struct RootView: View {
    enum Screen: Hashable {
        case home, statistics, game
    }

    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @State private var screen: Screen = .home
    @State private var activeTraining: TrainingViewModel?
    @State private var showsRecordConfetti = false

    var body: some View {
        ZStack {
            if let training = activeTraining {
                TrainingView(viewModel: training) { outcome in
                    finishTraining(training, outcome: outcome)
                }
                .transition(.opacity)
            } else {
                navigationShell
            }

            if showsRecordConfetti {
                ConfettiView()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .animation(.smooth(duration: 0.3), value: activeTraining == nil)
        .onAppear(perform: autoStartForScreenshotIfRequested)
    }

    /// Debug-Einstieg für die visuelle Verifikation ohne Mausklick:
    /// `--auto-training <nr>` startet direkt eine Übungslektion,
    /// `--auto-type` simuliert Anschläge inklusive eines Fehlers,
    /// `--screen statistics|game` öffnet direkt einen Bereich.
    private func autoStartForScreenshotIfRequested() {
        let arguments = ProcessInfo.processInfo.arguments
        if let screenIndex = arguments.firstIndex(of: "--screen"),
            arguments.indices.contains(screenIndex + 1) {
            switch arguments[screenIndex + 1] {
            case "statistics": screen = .statistics
            case "game": screen = .game
            default: break
            }
        }
        guard let flagIndex = arguments.firstIndex(of: "--auto-training"),
            arguments.indices.contains(flagIndex + 1),
            let number = Int(arguments[flagIndex + 1]),
            let lesson = (try? ContentStore.practiceLessons(for: settings.language))?
                .first(where: { $0.number == number })
        else { return }

        onStartAutoTraining(lesson: lesson, autoType: arguments.contains("--auto-type"))
    }

    private func onStartAutoTraining(lesson: PracticeLesson, autoType: Bool) {
        var segments = lesson.segments
        var intro = lesson.intro
        if lesson.number == 18 {
            let pool = (try? ContentStore.practiceLessons(for: settings.language))?
                .filter { (7...17).contains($0.number) }
                .flatMap(\.segments) ?? []
            segments = pool
            intro = pool.first ?? ""
        }
        let training = TrainingViewModel(request: TrainingRequest(
            title: "Lektion \(lesson.number): \(lesson.title)",
            language: settings.language,
            unit: lesson.unit,
            kind: .practice,
            intro: intro,
            segments: segments,
            configuration: settings.configuration(
                intelligenceAllowed: lesson.unit != .numpad
            ),
            assistance: settings.assistance,
            tickerSpeedLevel: settings.tickerSpeedLevel
        ))
        activeTraining = training
        guard autoType else { return }
        let session = training.session
        session.handleKey(.character(" "))
        var typed = 0
        while typed < 8, let expected = session.currentCharacter {
            switch expected {
            case DictationToken.newline: session.handleKey(.enter)
            case DictationToken.tab: session.handleKey(.tab)
            default: session.handleKey(.character(expected))
            }
            typed += 1
        }
        session.handleKey(.character("q")) // ein absichtlicher Fehler
    }

    private var navigationShell: some View {
        VStack(spacing: 0) {
            TopBar(screen: $screen)
            Divider()
            switch screen {
            case .home:
                HomeView(onStart: startTraining)
            case .statistics:
                StatisticsView()
            case .game:
                RainGameView()
            }
        }
        .frame(minWidth: 940, minHeight: 660)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func startTraining(_ request: TrainingRequest) {
        let store = StatisticsStore(context: modelContext)
        activeTraining = TrainingViewModel(
            request: request,
            settings: settings,
            initialStats: settings.intelligence
                ? store.accumulatedCharacterStats() : CharacterStats()
        )
    }

    private func finishTraining(_ training: TrainingViewModel, outcome: TrainingOutcome) {
        defer { activeTraining = nil }
        guard outcome == .finished else { return }
        let session = training.session
        let store = StatisticsStore(context: modelContext)
        let result = store.save(
            lessonTitle: training.lessonTitle,
            language: training.language,
            kind: training.kind,
            strokes: session.strokes,
            errors: session.errors,
            characters: max(0, session.dictatedCharacters - 1),
            seconds: session.elapsedSeconds,
            characterStats: session.characterStats
        )
        if result.isPersonalRecord, settings.celebrateRecords, session.strokes > 0 {
            triggerConfetti()
        }
    }

    private func triggerConfetti() {
        withAnimation { showsRecordConfetti = true }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.2))
            withAnimation { showsRecordConfetti = false }
        }
    }
}

/// Kopfzeile mit den Hauptbereichen.
private struct TopBar: View {
    @Binding var screen: RootView.Screen

    var body: some View {
        HStack(spacing: 8) {
            Label("TippTrainer", systemImage: "keyboard.fill")
                .font(.headline)
                .labelStyle(.titleAndIcon)
            Spacer()
            Picker("", selection: $screen) {
                Label("Üben", systemImage: "graduationcap").tag(RootView.Screen.home)
                Label("Statistik", systemImage: "chart.xyaxis.line")
                    .tag(RootView.Screen.statistics)
                Label("Spiel", systemImage: "gamecontroller").tag(RootView.Screen.game)
            }
            .pickerStyle(.segmented)
            .labelStyle(.titleAndIcon)
            .fixedSize()
            Spacer()
            SettingsLink {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}
