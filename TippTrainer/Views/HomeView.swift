import SwiftData
import SwiftUI

/// Startbildschirm: Übungslektionen mit Lernfortschritt und Empfehlung,
/// freie Diktate und eigene Lektionen samt Zugang zu den Trainingsoptionen.
struct HomeView: View {
    let onStart: (TrainingRequest) -> Void

    @Environment(AppSettings.self) private var settings
    @Environment(AppNavigation.self) private var navigation
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \OwnLesson.createdAt, order: .reverse) private var ownLessons: [OwnLesson]
    @Query(sort: \LessonRecord.date, order: .reverse) private var records: [LessonRecord]

    @State private var category: Category = .practice
    @State private var practiceLessons: [PracticeLesson] = []
    @State private var dictations: [Dictation] = []
    @State private var editingOwnLesson: OwnLesson?

    enum Category: String, CaseIterable {
        case practice, dictation, own
        var label: LocalizedStringKey {
            switch self {
            case .practice: "Übungslektionen"
            case .dictation: "Freie Diktate"
            case .own: "Eigene Lektionen"
            }
        }
    }

    /// Lernstand einer Übungslektion aus den gespeicherten Ergebnissen.
    struct LessonProgress {
        var runs = 0
        var bestPoints = 0
        var lastDate = Date.distantPast
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            Picker("", selection: $category) {
                ForEach(Category.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            ScrollView {
                switch category {
                case .practice: practiceSection
                case .dictation: dictationGrid
                case .own: ownList
                }
            }
        }
        .padding(24)
        .onAppear(perform: load)
        .onChange(of: settings.language) { load() }
        .sheet(item: $editingOwnLesson) { lesson in
            OwnLessonEditor(lesson: lesson)
        }
    }

    // MARK: - Kopf

    private var header: some View {
        @Bindable var settings = settings
        return HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Was möchtest du üben?")
                    .font(.title.bold())
                Text("Wähle eine Lektion und leg los.")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Picker("Sprache", selection: $settings.language) {
                Text("Deutsch").tag(LessonLanguage.german)
                Text("English").tag(LessonLanguage.english)
            }
            .pickerStyle(.segmented)
            .fixedSize()
            Button {
                navigation.showSettings(.training)
            } label: {
                Label(optionsSummary, systemImage: "slider.horizontal.3")
            }
            .help("Trainingsoptionen ändern")
        }
    }

    /// Die aktiven Trainingsoptionen auf einen Blick — der Knopf führt
    /// direkt zum passenden Reiter der Einstellungen.
    private var optionsSummary: String {
        var parts = [settings.limitSummary]
        parts.append(settings.blockOnError ? "Fehler blockieren" : "Fehler durchlassen")
        if settings.intelligence && settings.limitKind != .entireLesson {
            parts.append("Intelligenz")
        }
        if settings.guidedSteps {
            parts.append("Lernschritte")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Übungslektionen

    private var practiceSection: some View {
        let progress = progressByLesson
        let recommended = recommendedLesson(progress: progress)
        return VStack(alignment: .leading, spacing: 16) {
            if let recommended {
                RecommendationCard(
                    lesson: recommended,
                    progress: progress[recommended.number],
                    completedCount: progress.count,
                    totalCount: practiceLessons.count
                ) {
                    startPractice(recommended)
                }
            }
            LazyVGrid(columns: cardColumns, spacing: 14) {
                ForEach(practiceLessons) { lesson in
                    LessonCard(
                        tag: "Lektion \(lesson.number)",
                        title: lesson.title,
                        subtitle: lesson.subtitle,
                        icon: icon(for: lesson.unit),
                        progress: progress[lesson.number],
                        isRecommended: lesson.number == recommended?.number
                    ) {
                        startPractice(lesson)
                    }
                }
            }
        }
        .padding(.bottom, 20)
    }

    private var progressByLesson: [Int: LessonProgress] {
        var result: [Int: LessonProgress] = [:]
        for record in records
        where record.kind == .practice && record.language == settings.language
            && record.strokes > 0 {
            guard let number = Self.lessonNumber(in: record.lessonTitle) else { continue }
            var entry = result[number, default: LessonProgress()]
            entry.runs += 1
            entry.bestPoints = max(entry.bestPoints, record.points)
            entry.lastDate = max(entry.lastDate, record.date)
            result[number] = entry
        }
        return result
    }

    /// Lektionsnummer aus dem gespeicherten Titel »Lektion 3: r i«.
    static func lessonNumber(in title: String) -> Int? {
        guard title.hasPrefix("Lektion ") else { return nil }
        return Int(title.dropFirst("Lektion ".count).prefix { $0.isNumber })
    }

    /// Die erste noch nicht absolvierte Lektion; sind alle absolviert, die
    /// mit dem niedrigsten Bestwert.
    private func recommendedLesson(progress: [Int: LessonProgress]) -> PracticeLesson? {
        practiceLessons.first { progress[$0.number] == nil }
            ?? practiceLessons.min {
                (progress[$0.number]?.bestPoints ?? 0) < (progress[$1.number]?.bestPoints ?? 0)
            }
    }

    // MARK: - Freie Diktate

    private var dictationGrid: some View {
        LazyVGrid(columns: cardColumns, spacing: 14) {
            ForEach(dictations) { dictation in
                LessonCard(
                    tag: themeLabel(dictation.theme),
                    title: dictation.title,
                    subtitle: dictation.summary,
                    icon: "text.quote"
                ) {
                    startDictation(dictation)
                }
            }
        }
        .padding(.bottom, 20)
    }

    // MARK: - Eigene Lektionen

    private var ownList: some View {
        LazyVGrid(columns: cardColumns, spacing: 14) {
            Button {
                let lesson = OwnLesson(
                    title: "", summary: "", isSentenceMode: true, body: ""
                )
                editingOwnLesson = lesson
            } label: {
                VStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                    Text("Neue Lektion")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity, minHeight: 104)
                .foregroundStyle(.tint)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.tint.opacity(0.08))
                )
            }
            .buttonStyle(.plain)

            ForEach(ownLessons) { lesson in
                LessonCard(
                    tag: lesson.isSentenceMode ? "Satzdiktat" : "Wortdiktat",
                    title: lesson.title.isEmpty ? "Ohne Titel" : lesson.title,
                    subtitle: lesson.summary,
                    icon: "doc.text"
                ) {
                    startOwn(lesson)
                } onEdit: {
                    editingOwnLesson = lesson
                } onDelete: {
                    modelContext.delete(lesson)
                }
            }
        }
        .padding(.bottom, 20)
    }

    // MARK: - Start

    private func startPractice(_ lesson: PracticeLesson) {
        onStart(.practice(lesson, allLessons: practiceLessons, settings: settings))
    }

    private func startDictation(_ dictation: Dictation) {
        onStart(TrainingRequest(
            title: dictation.title,
            language: dictation.language,
            unit: dictation.unit,
            kind: .dictation,
            intro: dictation.segments.first ?? "",
            segments: dictation.segments,
            configuration: settings.configuration(),
            assistance: settings.assistance,
            tickerSpeedLevel: settings.tickerSpeedLevel
        ))
    }

    private func startOwn(_ lesson: OwnLesson) {
        let lines = lesson.lines
        onStart(TrainingRequest(
            title: lesson.title.isEmpty ? "Eigene Lektion" : lesson.title,
            language: settings.language,
            unit: lesson.isSentenceMode ? .sentence : .word,
            kind: .own,
            intro: lines.first ?? "",
            segments: lines,
            configuration: settings.configuration(),
            assistance: settings.assistance,
            tickerSpeedLevel: settings.tickerSpeedLevel
        ))
    }

    // MARK: - Laden

    private func load() {
        practiceLessons = (try? ContentStore.practiceLessons(for: settings.language)) ?? []
        dictations = (try? ContentStore.dictations()) ?? []
    }

    private let cardColumns = [GridItem(.adaptive(minimum: 210), spacing: 14)]

    private func icon(for unit: LessonUnit) -> String {
        switch unit {
        case .word: "textformat.abc"
        case .sentence: "text.alignleft"
        case .numpad: "number.square"
        }
    }

    private func themeLabel(_ theme: DictationTheme) -> String {
        switch theme {
        case .english: "English"
        case .poetry: "Lyrik"
        case .kids: "Kinder & Schule"
        case .health: "Gesundheit"
        case .technology: "Technik"
        case .knowledge: "Wissenswertes"
        }
    }
}

// MARK: - Empfehlung

/// Hervorgehobene Karte für die nächste sinnvolle Lektion.
private struct RecommendationCard: View {
    let lesson: PracticeLesson
    let progress: HomeView.LessonProgress?
    let completedCount: Int
    let totalCount: Int
    let onStart: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text(progress == nil ? "Als Nächstes" : "Weiter üben")
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(.tint)
                Text("Lektion \(lesson.number): \(lesson.title)")
                    .font(.title2.bold())
                Text(lesson.subtitle)
                    .foregroundStyle(.secondary)
                if !lesson.newCharacters.isEmpty {
                    HStack(spacing: 6) {
                        Text("Neue Tasten")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize()
                        ForEach(Array(lesson.newCharacters.prefix(8).enumerated()), id: \.offset) { _, character in
                            KeyChip(character: character)
                        }
                        if lesson.newCharacters.count > 8 {
                            Text("…").foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 2)
                }
            }
            .layoutPriority(1)
            Spacer(minLength: 16)
            VStack(alignment: .trailing, spacing: 10) {
                if let progress {
                    Text("Bestwert \(progress.bestPoints) Punkte · \(progress.runs)× geübt")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else if totalCount > 0 {
                    Text("\(completedCount) von \(totalCount) Lektionen absolviert")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Button(action: onStart) {
                    Label("Lektion starten", systemImage: "play.fill")
                        .padding(.horizontal, 6)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.accentColor.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.accentColor.opacity(0.25))
        )
    }
}

/// Kleine Tastenkappe für die Anzeige neuer Zeichen.
struct KeyChip: View {
    let character: Character

    var body: some View {
        Text(character == " " ? "␣" : String(character))
            .font(.system(.callout, design: .rounded).weight(.semibold))
            .frame(minWidth: 26, minHeight: 26)
            .padding(.horizontal, 3)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(.background.secondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.12))
            )
    }
}

/// Wiederverwendbare Lektionskarte.
private struct LessonCard: View {
    let tag: String
    let title: String
    let subtitle: String
    let icon: String
    var progress: HomeView.LessonProgress?
    var isRecommended = false
    let onStart: () -> Void
    var onEdit: (() -> Void)?
    var onDelete: (() -> Void)?

    var body: some View {
        Button(action: onStart) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(tag)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    if progress != nil {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                            .help("Bereits absolviert")
                    }
                    Spacer()
                    Image(systemName: icon).foregroundStyle(.tint)
                }
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let progress {
                    Spacer(minLength: 2)
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                        Text("\(progress.bestPoints) Punkte · \(progress.runs)×")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.background.secondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        isRecommended ? Color.accentColor.opacity(0.6) : Color.primary.opacity(0.06),
                        lineWidth: isRecommended ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let onEdit {
                Button("Bearbeiten", systemImage: "pencil", action: onEdit)
            }
            if let onDelete {
                Button("Löschen", systemImage: "trash", role: .destructive, action: onDelete)
            }
        }
    }
}
