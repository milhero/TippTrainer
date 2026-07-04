import SwiftUI

/// Startbildschirm: Lektionsauswahl und Einstieg ins Training.
struct HomeView: View {
    @State private var language: LessonLanguage = .german
    @State private var lessons: [PracticeLesson] = []
    @State private var activeTraining: TrainingViewModel?

    var body: some View {
        Group {
            if let training = activeTraining {
                TrainingView(viewModel: training) { _ in
                    activeTraining = nil
                }
            } else {
                lessonBrowser
            }
        }
        .onAppear(perform: loadLessons)
        .onChange(of: language) { loadLessons() }
    }

    private var lessonBrowser: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("TippTrainer")
                        .font(.largeTitle.bold())
                    Text("Zehnfingersystem lernen – Schritt für Schritt")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Picker("Sprache", selection: $language) {
                    Text("Deutsch").tag(LessonLanguage.german)
                    Text("English").tag(LessonLanguage.english)
                }
                .pickerStyle(.segmented)
                .frame(width: 220)
            }

            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 190), spacing: 14)],
                    spacing: 14
                ) {
                    ForEach(lessons) { lesson in
                        Button {
                            startTraining(lesson: lesson)
                        } label: {
                            lessonCard(lesson)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 24)
            }
        }
        .padding(28)
        .frame(minWidth: 900, minHeight: 620)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func lessonCard(_ lesson: PracticeLesson) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Lektion \(lesson.number)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: iconName(for: lesson))
                    .foregroundStyle(.tint)
            }
            Text(lesson.title)
                .font(.headline)
                .lineLimit(1)
            Text(lesson.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.background.secondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06))
        )
    }

    private func iconName(for lesson: PracticeLesson) -> String {
        switch lesson.unit {
        case .word: "textformat.abc"
        case .sentence: "text.alignleft"
        case .numpad: "number.square"
        }
    }

    private func loadLessons() {
        lessons = (try? ContentStore.practiceLessons(for: language)) ?? []
        autoStartForScreenshotIfRequested()
    }

    /// Debug-Einstieg für die visuelle Verifikation ohne Mausklick:
    /// `--auto-training <nr>` startet direkt eine Lektion,
    /// `--auto-type` simuliert einige Anschläge inklusive eines Fehlers.
    private func autoStartForScreenshotIfRequested() {
        let arguments = ProcessInfo.processInfo.arguments
        guard activeTraining == nil,
            let flagIndex = arguments.firstIndex(of: "--auto-training")
        else { return }
        let number = arguments.indices.contains(flagIndex + 1)
            ? Int(arguments[flagIndex + 1]) ?? 1 : 1
        guard let lesson = lessons.first(where: { $0.number == number }) else {
            return
        }
        startTraining(lesson: lesson)
        if arguments.contains("--auto-type"), let training = activeTraining {
            let session = training.session
            session.handleKey(.character(" "))
            var typed = 0
            while typed < 11, let expected = session.currentCharacter {
                if typed == 8 {
                    session.handleKey(.character("q")) // absichtlicher Fehler
                    break
                }
                switch expected {
                case DictationToken.newline: session.handleKey(.enter)
                case DictationToken.tab: session.handleKey(.tab)
                default: session.handleKey(.character(expected))
                }
                typed += 1
            }
        }
    }

    private func startTraining(lesson: PracticeLesson) {
        var lessonForTraining = lesson
        if lesson.number == 18 {
            // Lektion 18 trainiert den Satzpool aus L7–L17
            let pool = lessons
                .filter { (7...17).contains($0.number) }
                .flatMap(\.segments)
            lessonForTraining = PracticeLesson(
                number: lesson.number,
                title: lesson.title,
                subtitle: lesson.subtitle,
                newCharacters: lesson.newCharacters,
                unit: .sentence,
                intro: pool.first ?? "",
                segments: pool
            )
        }
        activeTraining = TrainingViewModel(
            lesson: lessonForTraining,
            language: language,
            configuration: TrainingConfiguration()
        )
    }
}

#Preview {
    HomeView()
}
