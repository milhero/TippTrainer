import Foundation

/// Sprache der Übungslektionen (bestimmt zugleich das Ziel-Tastaturlayout).
enum LessonLanguage: String, Codable, CaseIterable, Sendable {
    case german = "de"
    case english = "en"
}

/// Diktatform einer Lektion.
enum LessonUnit: String, Codable, Sendable {
    /// Segmente sind Wörter: mit Leerzeichen verkettet, Zeilenumbruch nach 35 Zeichen.
    case word
    /// Segmente sind Sätze: jedes endet mit einem Zeilenumbruch.
    case sentence
    /// Zahlenreihen für den Ziffernblock (Wortfluss, Numpad-Anzeige).
    case numpad
}

/// Eine der 20 aufeinander aufbauenden Übungslektionen.
struct PracticeLesson: Codable, Identifiable, Sendable {
    let number: Int
    let title: String
    let subtitle: String
    /// Zeichen, die in dieser Lektion neu hinzukommen.
    let newCharacters: String
    let unit: LessonUnit
    /// Feste erste Zeile beim Lektionsstart (Grundstellungs-Drill).
    let intro: String
    let segments: [String]

    var id: Int { number }
}

/// Themenkategorien der freien Lektionen.
enum DictationTheme: String, Codable, CaseIterable, Sendable {
    case english
    case poetry
    case kids
    case health
    case technology
    case knowledge
}

/// Eine freie Lektion (Diktat).
struct Dictation: Codable, Identifiable, Sendable {
    let id: String
    let title: String
    let summary: String
    let theme: DictationTheme
    let language: LessonLanguage
    let unit: LessonUnit
    let segments: [String]
}

/// Lädt die gebündelten Lektionsinhalte.
enum ContentStore {
    enum ContentError: Error {
        case resourceMissing(String)
    }

    static func practiceLessons(
        for language: LessonLanguage, bundle: Bundle = .main
    ) throws -> [PracticeLesson] {
        let file = try data(named: "lessons-\(language.rawValue)", in: bundle)
        return try JSONDecoder().decode([PracticeLesson].self, from: file)
    }

    static func dictations(bundle: Bundle = .main) throws -> [Dictation] {
        let file = try data(named: "dictations", in: bundle)
        return try JSONDecoder().decode([Dictation].self, from: file)
    }

    private static func data(named name: String, in bundle: Bundle) throws -> Data {
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            throw ContentError.resourceMissing(name)
        }
        return try Data(contentsOf: url)
    }
}
