import AppKit
import SwiftUI

/// Hilfen-Einstellungen für das Training (alle einzeln abschaltbar).
struct AssistanceOptions {
    var showKeyboard = true
    var coloredKeys = true
    var showHomeRow = true
    var showFingerPaths = true
    var showHandSeparator = true
    var showStatusHints = true
}

/// Beschreibt eine zu startende Trainingseinheit — unabhängig davon, ob
/// es eine Übungs-, freie oder eigene Lektion ist.
struct TrainingRequest {
    let title: String
    let language: LessonLanguage
    let unit: LessonUnit
    let kind: LessonKind
    let intro: String
    let segments: [String]
    /// Geführte Lernschritte vor dem freien Üben (nur Übungslektionen).
    var steps: [LessonStep] = []
    let configuration: TrainingConfiguration
    let assistance: AssistanceOptions
    let tickerSpeedLevel: Int
}

extension TrainingRequest {
    /// Baut die Anfrage für eine Übungslektion — inklusive des Sammelpools
    /// für Lektion 18 und der generierten Lernschritte.
    static func practice(
        _ lesson: PracticeLesson, allLessons: [PracticeLesson], settings: AppSettings
    ) -> TrainingRequest {
        var segments = lesson.segments
        var intro = lesson.intro
        if lesson.number == 18 {
            segments = allLessons
                .filter { (7...17).contains($0.number) }
                .flatMap(\.segments)
            intro = segments.first ?? ""
        }
        let steps = settings.guidedSteps
            ? LessonCurriculum.steps(for: lesson, language: settings.language)
            : []
        return TrainingRequest(
            title: "Lektion \(lesson.number): \(lesson.title)",
            language: settings.language,
            unit: lesson.unit,
            kind: .practice,
            intro: intro,
            segments: segments,
            steps: steps,
            configuration: settings.configuration(intelligenceAllowed: lesson.unit != .numpad),
            assistance: settings.assistance,
            tickerSpeedLevel: settings.tickerSpeedLevel
        )
    }
}

/// Bindeglied zwischen Trainings-Engine und SwiftUI.
@Observable
final class TrainingViewModel {
    let lessonTitle: String
    let language: LessonLanguage
    let unit: LessonUnit
    let kind: LessonKind
    let layout: KeyboardModel
    let assistance: AssistanceOptions
    let tickerSpeedLevel: Int

    private(set) var session: TrainingSession
    private(set) var errorFlash = false
    var showsResult = false
    /// Bester bisher gespeicherter Punktwert dieser Lektion (für die Auswertung).
    let previousBestPoints: Int?

    private var timer: Timer?

    init(
        request: TrainingRequest,
        settings: AppSettings? = nil,
        initialStats: CharacterStats = CharacterStats(),
        previousBestPoints: Int? = nil
    ) {
        self.lessonTitle = request.title
        self.previousBestPoints = previousBestPoints
        self.language = request.language
        self.unit = request.unit
        self.kind = request.kind
        self.layout = KeyboardModel.layout(for: request.language)
        self.assistance = request.assistance
        self.tickerSpeedLevel = request.tickerSpeedLevel

        var segments = request.segments.enumerated().map {
            TextSegment(id: $0.offset + 1, text: $0.element)
        }
        // Mit Lernschritten ist die Intro-Zeile bereits der letzte Schritt.
        if !request.intro.isEmpty && request.steps.isEmpty {
            segments.insert(TextSegment(id: 0, text: request.intro), at: 0)
        }
        session = TrainingSession(
            segments: segments,
            unit: request.unit,
            configuration: request.configuration,
            steps: request.steps,
            initialStats: initialStats
        )
        let beepOnError = request.configuration.beepOnError
        session.onError = { [weak self] in
            guard let self else { return }
            if beepOnError { NSSound.beep() }
            self.errorFlash = true
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(180))
                self.errorFlash = false
            }
        }
        session.onFinish = { [weak self] in
            self?.stopClock()
            self?.showsResult = true
        }
    }

    // MARK: - Eingabe

    func handle(_ press: KeyPress) -> KeyPress.Result {
        if press.modifiers.contains(.command) { return .ignored }
        let wasReady = session.state == .ready || session.state == .paused

        switch press.key {
        case .return: session.handleKey(.enter)
        case .tab: session.handleKey(.tab)
        case .delete: session.handleKey(.backspace)
        case .escape: return .ignored
        default:
            guard let character = press.characters.first,
                Self.isTypable(character)
            else { return .ignored }
            session.handleKey(.character(character))
        }

        if wasReady && session.state == .running {
            startClock()
        }
        return .handled
    }

    /// Steuer- und Funktionstasten (Pfeile, Escape, F-Tasten …) sind keine
    /// Anschläge und dürfen nicht als Tippfehler zählen. AppKit liefert
    /// Funktionstasten als Zeichen im Private-Use-Bereich U+F700–U+F8FF.
    static func isTypable(_ character: Character) -> Bool {
        guard let scalar = character.unicodeScalars.first else { return false }
        if scalar.value < 0x20 || scalar.value == 0x7F { return false }
        if (0xF700...0xF8FF).contains(scalar.value) { return false }
        return true
    }

    func pause() {
        session.pause()
        stopClock()
    }

    func cancel() {
        stopClock()
        session.finish()
    }

    // MARK: - Uhr

    private func startClock() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) {
            [weak self] _ in
            Task { @MainActor in
                self?.session.tick()
            }
        }
    }

    private func stopClock() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Abgeleitete Anzeigen

    var currentCharacter: Character? { session.currentCharacter }

    /// Der Finger für das aktuelle Zeichen (Rücktaste und Eingabe: kleiner
    /// Finger rechts, Tabulator: kleiner Finger links).
    var currentFinger: Finger? {
        guard session.state == .running, let character = currentCharacter else { return nil }
        if session.awaitingCorrection { return .rightPinky }
        if character == DictationToken.newline { return .rightPinky }
        if character == DictationToken.tab { return .leftPinky }
        if unit == .numpad { return KeyboardModel.numpadFinger(for: character) }
        return layout.finger(for: character)
    }

    /// Der kleine Finger, der für das aktuelle Zeichen Umschalt hält.
    var currentShiftFinger: Finger? {
        guard session.state == .running, !session.awaitingCorrection,
            unit != .numpad, let character = currentCharacter,
            let side = layout.shiftSide(for: character)
        else { return nil }
        return side == .left ? .leftPinky : .rightPinky
    }

    var statusHint: String {
        guard assistance.showStatusHints else { return "" }
        switch session.state {
        case .ready: return String(localized: "Grundstellung einnehmen – Leertaste startet")
        case .paused: return String(localized: "Pause – Leertaste setzt fort")
        case .finished: return String(localized: "Lektion beendet")
        case .running:
            guard let character = currentCharacter else { return "" }
            if session.awaitingCorrection {
                return String(localized: "Fehler mit der Rücktaste löschen")
            }
            return fingerHint(for: character)
        }
    }

    private func fingerHint(for character: Character) -> String {
        if character == DictationToken.newline {
            return unit == .numpad
                ? String(localized: "Eingabetaste – kleiner Finger")
                : String(localized: "Eingabetaste – kleiner Finger rechts")
        }
        if character == DictationToken.tab {
            return String(localized: "Tabulator – kleiner Finger links")
        }
        if unit == .numpad {
            return KeyboardModel.numpadFinger(for: character)?.germanName ?? ""
        }
        guard let finger = layout.finger(for: character) else { return "" }
        var hint = finger.germanName
        if layout.stroke(for: character)?.needsShift == true,
            let side = layout.shiftSide(for: character) {
            hint += side == .left
                ? String(localized: " + Umschalt links")
                : String(localized: " + Umschalt rechts")
        }
        return hint
    }

    var elapsedTimeText: String {
        let minutes = session.elapsedSeconds / 60
        let seconds = session.elapsedSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

extension Finger {
    var germanName: String {
        switch self {
        case .leftPinky: String(localized: "Kleiner Finger links")
        case .leftRing: String(localized: "Ringfinger links")
        case .leftMiddle: String(localized: "Mittelfinger links")
        case .leftIndex: String(localized: "Zeigefinger links")
        case .thumb: String(localized: "Daumen")
        case .rightIndex: String(localized: "Zeigefinger rechts")
        case .rightMiddle: String(localized: "Mittelfinger rechts")
        case .rightRing: String(localized: "Ringfinger rechts")
        case .rightPinky: String(localized: "Kleiner Finger rechts")
        }
    }

    /// Fingerfarben nach dem bewährten Schema: Zeigefinger rot,
    /// Mittelfinger blau, Ringfinger grün, kleiner Finger gelb.
    var color: Color {
        switch self {
        case .leftIndex, .rightIndex: .red
        case .leftMiddle, .rightMiddle: .blue
        case .leftRing, .rightRing: .green
        case .leftPinky, .rightPinky: .yellow
        case .thumb: .gray
        }
    }
}
