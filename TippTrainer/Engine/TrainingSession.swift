import Foundation
import Observation

/// Sonderzeichen im Diktattext.
enum DictationToken {
    /// Zeilenumbruch — wird mit der Eingabetaste getippt.
    static let newline: Character = "¶"
    /// Tabulator — wird mit der Tab-Taste getippt.
    static let tab: Character = "→"
    /// Maximale Zeilenlänge im Wortdiktat, bevor umgebrochen wird.
    static let charactersUntilNewline = 35
    /// Mindestvorrat an Zeichen vor der Schreibposition.
    static let charactersUntilRefresh = 25
}

/// Dauerbegrenzung eines Trainings.
enum TrainingLimit: Equatable {
    case time(minutes: Int)
    case characters(Int)
    /// Nur ohne Intelligenz möglich: die Lektion einmal von vorn bis hinten.
    case entireLesson
}

struct TrainingConfiguration {
    var limit: TrainingLimit = .time(minutes: 5)
    var blockOnError = true
    var requireBackspaceCorrection = false
    var beepOnError = true
    var intelligence = true
}

/// Ein geführter Lernschritt zu Beginn einer Lektion: eine Übungszeile mit
/// Erklärung, welche Finger gefragt sind. Jede Schrittzeile endet im Diktat
/// mit der Eingabetaste.
struct LessonStep: Equatable, Sendable {
    let title: String
    let hint: String
    let drill: String
    let fingers: [Finger]
}

/// Tastatureingabe aus Sicht der Engine.
enum KeyInput: Equatable {
    case character(Character)
    case backspace
    case enter
    case tab
}

enum SessionState: Equatable {
    case ready
    case running
    case paused
    case finished
}

/// Der UI-freie Kern einer Trainingseinheit: verwaltet Diktattext,
/// Schreibposition, Fehlerregeln, Zeit- und Zeichenlimits sowie die
/// Zeichenstatistik für die Intelligenz-Funktion. `@Observable`, weil die
/// Trainingsansicht den Sitzungszustand direkt liest — sonst zeichnet
/// SwiftUI nach einem Anschlag nicht neu.
@Observable
final class TrainingSession {
    let unit: LessonUnit
    let configuration: TrainingConfiguration
    let steps: [LessonStep]

    private(set) var state: SessionState = .ready
    private(set) var strokes = 0
    private(set) var errors = 0
    private(set) var elapsedSeconds = 0
    private(set) var cursorIndex = 0
    private(set) var characterStats = CharacterStats()
    private(set) var awaitingCorrection = false
    /// Protokoll aller Anschläge für den Auswertungsbericht:
    /// (getipptes Zeichen, war es ein Fehler).
    private(set) var typedLog: [(character: Character, isError: Bool)] = []

    /// Ausgelöst bei jedem (erstmaligen) Tippfehler, z. B. für den Fehlerton.
    var onError: (() -> Void)?
    var onFinish: (() -> Void)?

    private var picker: SegmentPicker
    private var dictationCharacters: [Character] = []
    private var oneErrorFlag = false
    private var lineLength = 0
    /// Zeichenbereiche der Lernschritte im Diktattext (inklusive Zeilenende).
    private var stepRanges: [Range<Int>] = []

    /// Fehlerwissen aus früheren Sitzungen — fließt in die Intelligenz ein,
    /// wird aber nicht erneut gespeichert (nur `characterStats` = Delta).
    private let baselineStats: CharacterStats

    init(
        segments: [TextSegment],
        unit: LessonUnit,
        configuration: TrainingConfiguration,
        steps: [LessonStep] = [],
        initialStats: CharacterStats = CharacterStats(),
        seed: UInt64 = UInt64.random(in: UInt64.min...UInt64.max)
    ) {
        self.unit = unit
        self.configuration = configuration
        self.steps = steps
        self.baselineStats = initialStats
        self.picker = SegmentPicker(
            segments: segments,
            intelligence: configuration.intelligence,
            seed: seed
        )
        assembleInitialText(from: segments)
    }

    // MARK: - Abgeleitete Werte

    var dictationText: String { String(dictationCharacters) }

    /// Aktuell zu tippendes Zeichen.
    var currentCharacter: Character? {
        guard cursorIndex < dictationCharacters.count else { return nil }
        return dictationCharacters[cursorIndex]
    }

    /// Anzahl der bereits korrekt getippten Zeichen (= Schreibposition).
    var typedCharacters: Int { cursorIndex }

    var points: Int {
        Scorer.points(strokes: strokes, errors: errors, seconds: elapsedSeconds)
    }

    var strokesPerMinute: Double {
        Scorer.strokesPerMinute(strokes: strokes, seconds: elapsedSeconds)
    }

    /// Index des laufenden Lernschritts; `nil` im freien Üben.
    var currentStepIndex: Int? {
        stepRanges.firstIndex { $0.contains(cursorIndex) }
    }

    var currentStep: LessonStep? {
        currentStepIndex.map { steps[$0] }
    }

    // MARK: - Steuerung

    func handleKey(_ input: KeyInput) {
        switch state {
        case .ready, .paused:
            if input == .character(" ") {
                state = .running
                if strokes == 0 && errors == 0 && cursorIndex == 0 {
                    recordCurrentCharacterOccurrence()
                }
            }
        case .running:
            processKeyWhileRunning(input)
        case .finished:
            break
        }
    }

    func pause() {
        guard state == .running else { return }
        state = .paused
    }

    /// Eine Sekunde Trainingszeit ist vergangen.
    func tick() {
        guard state == .running else { return }
        elapsedSeconds += 1
        checkLimits()
    }

    func finish() {
        guard state != .finished else { return }
        state = .finished
        onFinish?()
    }

    // MARK: - Eingabeverarbeitung

    private func processKeyWhileRunning(_ input: KeyInput) {
        if awaitingCorrection {
            if input == .backspace {
                awaitingCorrection = false
                oneErrorFlag = false
            }
            return
        }
        guard let expected = currentCharacter else {
            // Kein Text mehr: die Lektion ist zu Ende.
            finish()
            return
        }

        if matches(input, expected: expected) {
            oneErrorFlag = false
            strokes += 1
            typedLog.append((expected, false))
            advanceCursor()
        } else {
            guard let typed = typedCharacter(for: input) else { return }
            if !oneErrorFlag {
                errors += 1
                oneErrorFlag = true
                characterStats.recordTargetError(expected)
                characterStats.recordMistake(typed)
                typedLog.append((typed, true))
                onError?()
            }
            if !configuration.blockOnError {
                oneErrorFlag = false
                strokes += 1
                advanceCursor()
            }
            if configuration.requireBackspaceCorrection {
                awaitingCorrection = true
            }
        }
        checkLimits()
    }

    private func matches(_ input: KeyInput, expected: Character) -> Bool {
        switch input {
        case .character(let c): return c == expected
        case .enter: return expected == DictationToken.newline
        case .tab: return expected == DictationToken.tab
        case .backspace: return false
        }
    }

    private func typedCharacter(for input: KeyInput) -> Character? {
        switch input {
        case .character(let c): return c
        case .enter: return DictationToken.newline
        case .tab: return DictationToken.tab
        case .backspace: return nil
        }
    }

    private func advanceCursor() {
        cursorIndex += 1
        refreshDictationIfNeeded()
        recordCurrentCharacterOccurrence()
    }

    private func recordCurrentCharacterOccurrence() {
        if let current = currentCharacter {
            characterStats.recordOccurrence(current)
        }
    }

    // MARK: - Textversorgung

    private func assembleInitialText(from segments: [TextSegment]) {
        for step in steps {
            let start = dictationCharacters.count
            appendLine(step.drill)
            stepRanges.append(start..<dictationCharacters.count)
        }
        if configuration.limit == .entireLesson {
            // Ganze Lektion: alle Bausteine einmal in fester Reihenfolge,
            // ohne unsichtbares Leerzeichen am Schluss.
            for segment in segments {
                appendSegment(segment.text)
            }
            if dictationCharacters.last == " " {
                dictationCharacters.removeLast()
            }
        } else {
            if let intro = picker.firstSegment() {
                appendSegment(intro.text)
            }
            refreshDictationIfNeeded()
        }
    }

    /// Hält – außer bei »ganze Lektion« – stets einen Vorrat von mindestens
    /// `charactersUntilRefresh` Zeichen vor der Schreibposition, unabhängig
    /// davon, ob die Intelligenz aktiv ist. (Früher gab es Nachschub nur
    /// mit Intelligenz; ohne sie blieb die Sitzung nach dem letzten Zeichen
    /// ohne Eingabemöglichkeit hängen.)
    private func refreshDictationIfNeeded() {
        guard configuration.limit != .entireLesson else { return }
        while dictationCharacters.count - cursorIndex
            <= DictationToken.charactersUntilRefresh {
            guard let next = picker.nextSegment(
                stats: baselineStats.merged(with: characterStats)
            ) else { return }
            appendSegment(next.text)
        }
    }

    /// Hängt eine ganze Zeile an, die mit der Eingabetaste abgeschlossen wird.
    private func appendLine(_ text: String) {
        dictationCharacters.append(contentsOf: sanitized(text))
        dictationCharacters.append(DictationToken.newline)
        lineLength = 0
    }

    private func appendSegment(_ text: String) {
        let sanitized = sanitized(text)
        dictationCharacters.append(contentsOf: sanitized)
        switch unit {
        case .sentence:
            dictationCharacters.append(DictationToken.newline)
            lineLength = 0
        case .word, .numpad:
            lineLength += sanitized.count
            if lineLength > DictationToken.charactersUntilNewline {
                dictationCharacters.append(DictationToken.newline)
                lineLength = 0
            } else {
                dictationCharacters.append(" ")
                lineLength += 1
            }
        }
    }

    private func sanitized(_ text: String) -> String {
        text.replacingOccurrences(of: "\t", with: String(DictationToken.tab))
    }

    // MARK: - Limits

    private func checkLimits() {
        switch configuration.limit {
        case .time(let minutes):
            if elapsedSeconds >= minutes * 60 { finish() }
        case .characters(let count):
            if cursorIndex >= count { finish() }
        case .entireLesson:
            break
        }
        // Sicherheitsnetz: Ist kein Text mehr da, ist die Lektion vorbei —
        // sonst bliebe die Sitzung ohne Eingabemöglichkeit hängen.
        if state == .running, cursorIndex >= dictationCharacters.count {
            finish()
        }
    }
}
