import SwiftUI

/// Zentrale, persistente App-Einstellungen. Bildet die Grundeinstellungen
/// und Standard-Trainingsparameter des klassischen Trainers ab.
@Observable
final class AppSettings {
    // Sprache / Layout
    @ObservationIgnored
    @AppStorage("lessonLanguage") private var storedLanguage = LessonLanguage.german.rawValue

    var language: LessonLanguage {
        get { LessonLanguage(rawValue: storedLanguage) ?? .german }
        set { storedLanguage = newValue.rawValue }
    }

    // Laufschrift
    @ObservationIgnored
    @AppStorage("tickerSpeedLevel") var tickerSpeedLevel = TickerPacing.defaultLevel

    // Dauer
    @ObservationIgnored
    @AppStorage("limitKind") private var storedLimitKind = LimitKind.time.rawValue
    @ObservationIgnored
    @AppStorage("limitMinutes") var limitMinutes = 5
    @ObservationIgnored
    @AppStorage("limitCharacters") var limitCharacters = 500

    var limitKind: LimitKind {
        get { LimitKind(rawValue: storedLimitKind) ?? .time }
        set { storedLimitKind = newValue.rawValue }
    }

    // Fehlerreaktion
    @ObservationIgnored
    @AppStorage("blockOnError") var blockOnError = true
    @ObservationIgnored
    @AppStorage("requireBackspaceCorrection") var requireBackspaceCorrection = false
    @ObservationIgnored
    @AppStorage("beepOnError") var beepOnError = false
    @ObservationIgnored
    @AppStorage("intelligence") var intelligence = true

    // Hilfen
    @ObservationIgnored
    @AppStorage("showKeyboard") var showKeyboard = true
    @ObservationIgnored
    @AppStorage("coloredKeys") var coloredKeys = true
    @ObservationIgnored
    @AppStorage("showHomeRow") var showHomeRow = true
    @ObservationIgnored
    @AppStorage("showFingerPaths") var showFingerPaths = true
    @ObservationIgnored
    @AppStorage("showHandSeparator") var showHandSeparator = true
    @ObservationIgnored
    @AppStorage("showStatusHints") var showStatusHints = true

    // Extras
    @ObservationIgnored
    @AppStorage("celebrateRecords") var celebrateRecords = true

    enum LimitKind: String, CaseIterable {
        case time, characters, entireLesson
    }

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
}
