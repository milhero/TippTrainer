import SwiftData
import SwiftUI

/// Startbildschirm: Übungslektionen, freie Diktate und eigene Lektionen
/// samt kompakter Trainingsoptionen.
struct HomeView: View {
    let onStart: (TrainingRequest) -> Void

    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \OwnLesson.createdAt, order: .reverse) private var ownLessons: [OwnLesson]

    @State private var category: Category = .practice
    @State private var practiceLessons: [PracticeLesson] = []
    @State private var dictations: [Dictation] = []
    @State private var editingOwnLesson: OwnLesson?
    @State private var showsOptions = false

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

    var body: some View {
        @Bindable var settings = settings
        VStack(alignment: .leading, spacing: 16) {
            header

            Picker("", selection: $category) {
                ForEach(Category.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            ScrollView {
                switch category {
                case .practice: practiceGrid
                case .dictation: dictationGrid
                case .own: ownList
                }
            }
        }
        .padding(24)
        .onAppear(perform: load)
        .onChange(of: settings.language) { load() }
        .sheet(isPresented: $showsOptions) {
            TrainingOptionsView()
        }
        .sheet(item: $editingOwnLesson) { lesson in
            OwnLessonEditor(lesson: lesson)
        }
    }

    private var header: some View {
        @Bindable var settings = settings
        return HStack(alignment: .firstTextBaseline) {
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
                showsOptions = true
            } label: {
                Label("Optionen", systemImage: "slider.horizontal.3")
            }
        }
    }

    // MARK: - Übungslektionen

    private var practiceGrid: some View {
        LazyVGrid(columns: cardColumns, spacing: 14) {
            ForEach(practiceLessons) { lesson in
                LessonCard(
                    tag: "Lektion \(lesson.number)",
                    title: lesson.title,
                    subtitle: lesson.subtitle,
                    icon: icon(for: lesson.unit)
                ) {
                    startPractice(lesson)
                }
            }
        }
        .padding(.bottom, 20)
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
                .frame(maxWidth: .infinity, minHeight: 96)
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
        let intelligenceAllowed = lesson.unit != .numpad
        var segments = lesson.segments
        var intro = lesson.intro
        if lesson.number == 18 {
            segments = practiceLessons
                .filter { (7...17).contains($0.number) }
                .flatMap(\.segments)
            intro = segments.first ?? ""
        }
        onStart(TrainingRequest(
            title: "Lektion \(lesson.number): \(lesson.title)",
            language: settings.language,
            unit: lesson.unit,
            kind: .practice,
            intro: intro,
            segments: segments,
            configuration: settings.configuration(intelligenceAllowed: intelligenceAllowed),
            assistance: settings.assistance,
            tickerSpeedLevel: settings.tickerSpeedLevel
        ))
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

/// Wiederverwendbare Lektionskarte.
private struct LessonCard: View {
    let tag: String
    let title: String
    let subtitle: String
    let icon: String
    let onStart: () -> Void
    var onEdit: (() -> Void)?
    var onDelete: (() -> Void)?

    var body: some View {
        Button(action: onStart) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(tag)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
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
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.background.secondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06))
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
