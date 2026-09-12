import Foundation
import Observation

/// Wahl des Tastaturlayouts: automatisch vom System übernommen oder fest.
enum KeyboardLayoutChoice: String, CaseIterable {
    case automatic, german, english
}

extension LessonLanguage {
    /// Anzeigename des zugehörigen Tastaturlayouts.
    var layoutName: String {
        switch self {
        case .german: "Deutsch (QWERTZ)"
        case .english: "US-Englisch (QWERTY)"
        }
    }
}

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
    @ObservationIgnored private var layoutObserver: NSObjectProtocol?

    // Tastatur
    var layoutChoice: KeyboardLayoutChoice {
        didSet { defaults.set(layoutChoice.rawValue, forKey: "keyboardLayout") }
    }
    /// Vom System erkanntes Layout (`nil`: nicht unterstützt oder unbekannt).
    private(set) var detectedLayout: LessonLanguage?
    /// Anzeigename der erkannten Eingabequelle, z. B. »German«.
    private(set) var detectedLayoutName = ""

    /// Das wirksame Tastaturlayout. Es bestimmt die Übungslektionen, die
    /// virtuelle Tastatur und die Fingerhinweise — die Übungen müssen zur
    /// Tastatur passen, die vor dem Nutzer liegt.
    var language: LessonLanguage {
        switch layoutChoice {
        case .automatic: detectedLayout ?? .german
        case .german: .german
        case .english: .english
        }
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
        layoutChoice = KeyboardLayoutChoice(rawValue: defaults.string(forKey: "keyboardLayout") ?? "")
            ?? .automatic
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

    // MARK: - Tastaturerkennung

    /// Übernimmt eine Erkennung des Systemlayouts.
    func apply(_ detection: KeyboardLayoutDetector.Detection) {
        detectedLayout = detection.layout
        detectedLayoutName = detection.localizedName
    }

    /// Erkennt das Systemlayout jetzt und folgt künftigen Wechseln.
    func startObservingKeyboardLayout() {
        apply(KeyboardLayoutDetector.current())
        guard layoutObserver == nil else { return }
        layoutObserver = DistributedNotificationCenter.default().addObserver(
            forName: KeyboardLayoutDetector.changeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.apply(KeyboardLayoutDetector.current())
            }
        }
    }

    /// Hinweis für die Oberfläche, wenn Erkennung und Auswahl nicht zusammenpassen.
    var layoutWarning: String? {
        switch layoutChoice {
        case .automatic:
            guard detectedLayout == nil, !detectedLayoutName.isEmpty else { return nil }
            return "Das Tastaturlayout »\(detectedLayoutName)« wird nicht unterstützt. Die Übungen gehen von \(LessonLanguage.german.layoutName) aus – du kannst das Layout hier fest wählen."
        case .german, .english:
            guard let detected = detectedLayout, detected != language else { return nil }
            return "Erkannt wurde \(detected.layoutName). Mit der festen Auswahl \(language.layoutName) passen Tastenhinweise nicht zu deiner Tastatur."
        }
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
