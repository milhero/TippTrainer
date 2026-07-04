import Foundation
import SwiftData

/// Art der absolvierten Lektion — für Filter und Verlaufsfarben.
enum LessonKind: Int, Codable, CaseIterable {
    case practice = 0
    case dictation = 1
    case own = 2

    var label: String {
        switch self {
        case .practice: String(localized: "Übungslektion")
        case .dictation: String(localized: "Freie Lektion")
        case .own: String(localized: "Eigene Lektion")
        }
    }
}

/// Ergebnis einer absolvierten Trainingseinheit (Lernstatistik).
@Model
final class LessonRecord {
    var lessonTitle: String
    var languageRaw: String
    var kindRaw: Int
    var strokes: Int
    var errors: Int
    var characters: Int
    var seconds: Int
    var points: Int
    var date: Date

    init(
        lessonTitle: String,
        language: LessonLanguage,
        kind: LessonKind,
        strokes: Int,
        errors: Int,
        characters: Int,
        seconds: Int,
        points: Int,
        date: Date = .now
    ) {
        self.lessonTitle = lessonTitle
        self.languageRaw = language.rawValue
        self.kindRaw = kind.rawValue
        self.strokes = strokes
        self.errors = errors
        self.characters = characters
        self.seconds = seconds
        self.points = points
        self.date = date
    }

    var kind: LessonKind { LessonKind(rawValue: kindRaw) ?? .practice }
    var language: LessonLanguage { LessonLanguage(rawValue: languageRaw) ?? .german }

    var strokesPerMinute: Int {
        Int(Scorer.strokesPerMinute(strokes: strokes, seconds: seconds))
    }

    var errorRate: Double {
        Scorer.errorRate(errors: errors, characters: characters)
    }
}

/// Kumulierte Fehlerstatistik je Schriftzeichen über alle Trainings.
@Model
final class CharRecord {
    @Attribute(.unique) var unicode: Int
    var occurrences: Int
    var targetErrors: Int
    var mistakes: Int

    init(unicode: Int, occurrences: Int = 0, targetErrors: Int = 0, mistakes: Int = 0) {
        self.unicode = unicode
        self.occurrences = occurrences
        self.targetErrors = targetErrors
        self.mistakes = mistakes
    }

    var character: Character {
        Character(UnicodeScalar(unicode) ?? " ")
    }

    var errorRate: Double {
        occurrences > 0 ? Double(targetErrors) * 100 / Double(occurrences) : 0
    }
}

/// Eigene Lektion (vom Nutzer erstellt).
@Model
final class OwnLesson {
    var title: String
    var summary: String
    var isSentenceMode: Bool
    var body: String
    var createdAt: Date

    init(
        title: String, summary: String, isSentenceMode: Bool,
        body: String, createdAt: Date = .now
    ) {
        self.title = title
        self.summary = summary
        self.isSentenceMode = isSentenceMode
        self.body = body
        self.createdAt = createdAt
    }

    var lines: [String] {
        body.split(whereSeparator: \.isNewline).map(String.init)
    }
}

enum PersistenceController {
    static let schema = Schema([
        LessonRecord.self, CharRecord.self, OwnLesson.self,
    ])

    @MainActor
    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema, isStoredInMemoryOnly: inMemory
        )
        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            fatalError("SwiftData-Container fehlgeschlagen: \(error)")
        }
    }
}
