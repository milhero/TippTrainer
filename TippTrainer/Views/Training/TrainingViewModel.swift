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

/// Bindeglied zwischen Trainings-Engine und SwiftUI.
@Observable
final class TrainingViewModel {
    let lessonTitle: String
    let language: LessonLanguage
    let unit: LessonUnit
    let layout: KeyboardModel
    let assistance: AssistanceOptions
    let tickerSpeedLevel: Int

    private(set) var session: TrainingSession
    private(set) var errorFlash = false
    var showsResult = false

    private var timer: Timer?

    init(
        lesson: PracticeLesson,
        language: LessonLanguage,
        configuration: TrainingConfiguration,
        assistance: AssistanceOptions = AssistanceOptions(),
        tickerSpeedLevel: Int = TickerPacing.defaultLevel,
        beepOnError: Bool = true
    ) {
        self.lessonTitle = lesson.title
        self.language = language
        self.unit = lesson.unit
        self.layout = KeyboardModel.layout(for: language)
        self.assistance = assistance
        self.tickerSpeedLevel = tickerSpeedLevel

        var segments = lesson.segments.enumerated().map {
            TextSegment(id: $0.offset + 1, text: $0.element)
        }
        if !lesson.intro.isEmpty {
            segments.insert(TextSegment(id: 0, text: lesson.intro), at: 0)
        }
        session = TrainingSession(
            segments: segments,
            unit: lesson.unit,
            configuration: configuration
        )
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
        default:
            guard let character = press.characters.first else { return .ignored }
            session.handleKey(.character(character))
        }

        if wasReady && session.state == .running {
            startClock()
        }
        return .handled
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
