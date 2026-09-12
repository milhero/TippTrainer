import SwiftData
import SwiftUI

/// Oberste Navigation: wechselt zwischen Start, Training, Statistik und
/// dem Buchstabenregen-Spiel und zeigt das Einstellungsfenster.
struct RootView: View {
    enum Screen: Hashable {
        case home, statistics, game
    }

    @Environment(AppSettings.self) private var settings
    @Environment(AppNavigation.self) private var navigation
    @Environment(\.modelContext) private var modelContext
    @State private var screen: Screen = .home
    @State private var activeTraining: TrainingViewModel?
    @State private var showsRecordConfetti = false

    var body: some View {
        @Bindable var navigation = navigation
        ZStack {
            if let training = activeTraining {
                TrainingView(viewModel: training) { outcome in
                    finishTraining(training, outcome: outcome)
                }
                .transition(.opacity)
            } else {
                navigationShell
                    .sheet(isPresented: $navigation.showsSettings) {
                        SettingsSheet()
                    }
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
    /// `--auto-type` simuliert Anschläge inklusive eines Fehlers
    /// (`--auto-keys <n>` begrenzt die Anzahl, `--auto-full` tippt bis zum
    /// Limit), `--screen statistics|game|settings` öffnet direkt einen
    /// Bereich, `--seed-demo` legt Beispieldaten an (nur mit `--memory-store`
    /// sinnvoll).
    private func autoStartForScreenshotIfRequested() {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--seed-demo") {
            seedDemoData()
        }
        if let screenIndex = arguments.firstIndex(of: "--screen"),
            arguments.indices.contains(screenIndex + 1) {
            switch arguments[screenIndex + 1] {
            case "statistics": screen = .statistics
            case "game": screen = .game
            case "settings": navigation.showSettings(.training)
            default: break
            }
        }
        guard let flagIndex = arguments.firstIndex(of: "--auto-training"),
            arguments.indices.contains(flagIndex + 1),
            let number = Int(arguments[flagIndex + 1]),
            let lessons = try? ContentStore.practiceLessons(for: settings.language),
            let lesson = lessons.first(where: { $0.number == number })
        else { return }

        onStartAutoTraining(
            lesson: lesson, allLessons: lessons,
            autoType: arguments.contains("--auto-type")
        )
    }

    private func onStartAutoTraining(
        lesson: PracticeLesson, allLessons: [PracticeLesson], autoType: Bool
    ) {
        let training = TrainingViewModel(
            request: .practice(lesson, allLessons: allLessons, settings: settings)
        )
        activeTraining = training
        guard autoType else { return }
        let session = training.session
        session.handleKey(.character(" "))
        let arguments = ProcessInfo.processInfo.arguments
        let full = arguments.contains("--auto-full")
        var maxKeys = full ? 5000 : 8
        if let keysIndex = arguments.firstIndex(of: "--auto-keys"),
            arguments.indices.contains(keysIndex + 1),
            let count = Int(arguments[keysIndex + 1]) {
            maxKeys = count
        }
        var typed = 0
        while typed < maxKeys, let expected = session.currentCharacter,
            session.state == .running {
            // Bei --auto-full alle 30 Zeichen absichtlich einen Fehler tippen.
            if full, typed > 0, typed % 30 == 0, expected != DictationToken.newline {
                session.handleKey(.character("q"))
            }
            switch expected {
            case DictationToken.newline: session.handleKey(.enter)
            case DictationToken.tab: session.handleKey(.tab)
            default: session.handleKey(.character(expected))
            }
            if full { session.tick() } // Zeit vorspulen für A/min und Limit
            typed += 1
        }
        if !full {
            session.handleKey(.character("q")) // ein absichtlicher Fehler
        }
    }

    /// Beispieldaten für die visuelle Verifikation der Statistik und der
    /// Startseite: mehrere Lektionen über gut eine Woche verteilt.
    private func seedDemoData() {
        guard (try? modelContext.fetchCount(FetchDescriptor<LessonRecord>())) == 0 else {
            return
        }
        let samples: [(title: String, strokes: Int, errors: Int, seconds: Int, daysAgo: Int)] = [
            ("Lektion 1: Die Grundstellung", 210, 6, 300, 9),
            ("Lektion 1: Die Grundstellung", 250, 4, 300, 8),
            ("Lektion 2: Die häufigsten Buchstaben", 262, 5, 300, 7),
            ("Lektion 2: Die häufigsten Buchstaben", 300, 3, 300, 6),
            ("Lektion 3: Hinauf zur oberen Reihe", 315, 5, 300, 5),
            ("Wandrers Nachtlied", 340, 2, 240, 4),
            ("Lektion 4: Die Zeigefinger greifen", 352, 3, 300, 3),
            ("Lektion 5: Unten und oben", 380, 4, 300, 1),
        ]
        for sample in samples {
            let kind: LessonKind = sample.title.hasPrefix("Lektion") ? .practice : .dictation
            modelContext.insert(LessonRecord(
                lessonTitle: sample.title,
                language: .german,
                kind: kind,
                strokes: sample.strokes,
                errors: sample.errors,
                characters: sample.strokes,
                seconds: sample.seconds,
                points: Scorer.points(
                    strokes: sample.strokes, errors: sample.errors, seconds: sample.seconds
                ),
                date: Date.now.addingTimeInterval(-Double(sample.daysAgo) * 86_400)
            ))
        }
        let errorRates: [Character: (occurrences: Int, errors: Int)] = [
            "a": (120, 2), "s": (90, 4), "d": (95, 1), "f": (110, 0),
            "j": (100, 1), "k": (80, 6), "l": (85, 2), "ö": (30, 7),
            "e": (140, 5), "n": (90, 3), "r": (70, 9), "i": (75, 2),
            "t": (60, 4), "h": (55, 8), "c": (20, 6), "u": (35, 3), " ": (200, 1),
        ]
        for (character, entry) in errorRates {
            guard let scalar = character.unicodeScalars.first else { continue }
            modelContext.insert(CharRecord(
                unicode: Int(scalar.value),
                occurrences: entry.occurrences,
                targetErrors: entry.errors,
                mistakes: entry.errors
            ))
        }
        try? modelContext.save()
    }

    private var navigationShell: some View {
        VStack(spacing: 0) {
            TopBar(screen: $screen) {
                navigation.showSettings(.training)
            }
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
        // Der Inhalt muss die volle Höhe einnehmen, sonst zentriert der
        // Frame den Stapel und die Auswahlleiste rutscht zur Fenstermitte.
        .frame(
            minWidth: 940, maxWidth: .infinity,
            minHeight: 660, maxHeight: .infinity,
            alignment: .top
        )
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func startTraining(_ request: TrainingRequest) {
        navigation.showsSettings = false
        let store = StatisticsStore(context: modelContext)
        activeTraining = TrainingViewModel(
            request: request,
            settings: settings,
            initialStats: settings.intelligence
                ? store.accumulatedCharacterStats() : CharacterStats(),
            previousBestPoints: store.bestPoints(forLessonTitle: request.title)
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
            characters: session.typedCharacters,
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

/// Kopfzeile mit den Hauptbereichen und dem Zugang zu den Einstellungen.
private struct TopBar: View {
    @Binding var screen: RootView.Screen
    let onSettings: () -> Void

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
            Button(action: onSettings) {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help("Einstellungen (⌘,)")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}
