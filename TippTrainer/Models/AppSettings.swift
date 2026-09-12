import Foundation
import Observation

/// Zentrale, persistente App-Einstellungen.
///
/// Die Werte sind gewöhnliche beobachtbare Eigenschaften, die sich bei jeder
/// Änderung selbst in `UserDefaults` sichern. (Früher hingen sie an
/// `@ObservationIgnored @AppStorage`; `@AppStorage` meldet Änderungen aber
/// nur innerhalb einer View. Sprachwahl, Dauer-Auswahl und alle Schalter
/// wirkten deshalb erst beim nächsten zufälligen Neuzeichnen.)
@Observable
final class AppSettings {
    enum LimitKind: String, CaseIterable {
        case time, characters, entireLesson
    }

    @ObservationIgnored private let defaults: UserDefaults

    // Sprache / Layout
    var language: LessonLanguage {
        didSet { defaults.set(language.rawValue, forKey: "lessonLanguage") }
    }

    // Laufschrift
    var tickerSpeedLevel: Int {
        didSet { defaults.set(tickerSpeedLevel, forKey: "tickerSpeedLevel") }
    }

    // Dauer
    var limitKind: LimitKind {
        didSet { defaults.set(limitKind.rawValue, forKey: "limitKind") }
    }
    var limitMinutes: Int {
        didSet { defaults.set(limitMinutes, forKey: "limitMinutes") }
    }
    var limitCharacters: Int {
        didSet { defaults.set(limitCharacters, forKey: "limitCharacters") }
    }

    // Fehlerreaktion / Ablauf
    var blockOnError: Bool {
        didSet { defaults.set(blockOnError, forKey: "blockOnError") }
    }
    var requireBackspaceCorrection: Bool {
        didSet { defaults.set(requireBackspaceCorrection, forKey: "requireBackspaceCorrection") }
    }
    var beepOnError: Bool {
        didSet { defaults.set(beepOnError, forKey: "beepOnError") }
    }
    var intelligence: Bool {
        didSet { defaults.set(intelligence, forKey: "intelligence") }
    }
    /// Geführte Lernschritte am Anfang jeder Übungslektion.
    var guidedSteps: Bool {
        didSet { defaults.set(guidedSteps, forKey: "guidedSteps") }
    }

    // Hilfen
    var showKeyboard: Bool {
        didSet { defaults.set(showKeyboard, forKey: "showKeyboard") }
    }
    var coloredKeys: Bool {
        didSet { defaults.set(coloredKeys, forKey: "coloredKeys") }
    }
    var showHomeRow: Bool {
        didSet { defaults.set(showHomeRow, forKey: "showHomeRow") }
    }
    var showFingerPaths: Bool {
        didSet { defaults.set(showFingerPaths, forKey: "showFingerPaths") }
    }
    var showHandSeparator: Bool {
        didSet { defaults.set(showHandSeparator, forKey: "showHandSeparator") }
    }
    var showStatusHints: Bool {
        didSet { defaults.set(showStatusHints, forKey: "showStatusHints") }
    }

    // Extras
    var celebrateRecords: Bool {
        didSet { defaults.set(celebrateRecords, forKey: "celebrateRecords") }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        language = LessonLanguage(rawValue: defaults.string(forKey: "lessonLanguage") ?? "")
            ?? .german
        tickerSpeedLevel = Self.int("tickerSpeedLevel", default: TickerPacing.defaultLevel, in: defaults)
        limitKind = LimitKind(rawValue: defaults.string(forKey: "limitKind") ?? "") ?? .time
        limitMinutes = Self.int("limitMinutes", default: 5, in: defaults)
        limitCharacters = Self.int("limitCharacters", default: 500, in: defaults)
        blockOnError = Self.bool("blockOnError", default: true, in: defaults)
        requireBackspaceCorrection = Self.bool("requireBackspaceCorrection", default: false, in: defaults)
        beepOnError = Self.bool("beepOnError", default: false, in: defaults)
        intelligence = Self.bool("intelligence", default: true, in: defaults)
        guidedSteps = Self.bool("guidedSteps", default: true, in: defaults)
        showKeyboard = Self.bool("showKeyboard", default: true, in: defaults)
        coloredKeys = Self.bool("coloredKeys", default: true, in: defaults)
        showHomeRow = Self.bool("showHomeRow", default: true, in: defaults)
        showFingerPaths = Self.bool("showFingerPaths", default: true, in: defaults)
        showHandSeparator = Self.bool("showHandSeparator", default: true, in: defaults)
        showStatusHints = Self.bool("showStatusHints", default: true, in: defaults)
        celebrateRecords = Self.bool("celebrateRecords", default: true, in: defaults)
    }

    private static func bool(_ key: String, default value: Bool, in defaults: UserDefaults) -> Bool {
        defaults.object(forKey: key) as? Bool ?? value
    }

    private static func int(_ key: String, default value: Int, in defaults: UserDefaults) -> Int {
        defaults.object(forKey: key) as? Int ?? value
    }

    // MARK: - Abgeleitete Trainingsparameter

    var assistance: AssistanceOptions {
        AssistanceOptions(
            showKeyboard: showKeyboard,
            coloredKeys: coloredKeys,
            showHomeRow: showHomeRow,
            showFingerPaths: showFingerPaths,
            showHandSeparator: showHandSeparator,
            showStatusHints: showStatusHints
        )
    }

    func configuration(intelligenceAllowed: Bool = true) -> TrainingConfiguration {
        let limit: TrainingLimit
        switch limitKind {
        case .time: limit = .time(minutes: limitMinutes)
        case .characters: limit = .characters(limitCharacters)
        case .entireLesson: limit = .entireLesson
        }
        // Ganze Lektion ist nur ohne Intelligenz möglich.
        let useIntelligence = intelligence && intelligenceAllowed
            && limitKind != .entireLesson
        return TrainingConfiguration(
            limit: limit,
            blockOnError: blockOnError,
            requireBackspaceCorrection: requireBackspaceCorrection,
            beepOnError: beepOnError,
            intelligence: useIntelligence
        )
    }

    /// Kurzfassung der aktiven Trainingsoptionen für die Startseite.
    var limitSummary: String {
        switch limitKind {
        case .time: "\(limitMinutes) Minuten"
        case .characters: "\(limitCharacters) Zeichen"
        case .entireLesson: "Ganze Lektion"
        }
    }
}
