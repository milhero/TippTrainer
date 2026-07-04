import Foundation

/// Sonderzeichen im Diktattext.
enum DictationToken {
    /// Zeilenumbruch — wird mit der Eingabetaste getippt.
    static let newline: Character = "¶"
    /// Tabulator — wird mit der Tab-Taste getippt.
    static let tab: Character = "→"
    /// Maximale Zeilenlänge im Wortdiktat, bevor umgebrochen wird.
    static let charactersUntilNewline = 35
    /// Rest-Zeichen im Ticker, ab dem Nachschub angefordert wird.
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
/// Zeichenstatistik für die Intelligenz-Funktion.
final class TrainingSession {
    let unit: LessonUnit
    let configuration: TrainingConfiguration

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

    init(
        segments: [TextSegment],
        unit: LessonUnit,
        configuration: TrainingConfiguration,
        seed: UInt64 = UInt64.random(in: UInt64.min...UInt64.max)
    ) {
        self.unit = unit
        self.configuration = configuration
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

    /// Anzahl der bislang diktierten Zeichen (inklusive des aktuellen).
    var dictatedCharacters: Int {
        min(cursorIndex + 1, dictationCharacters.count)
    }

    var points: Int {
        Scorer.points(strokes: strokes, errors: errors, seconds: elapsedSeconds)
    }

    var strokesPerMinute: Double {
        Scorer.strokesPerMinute(strokes: strokes, seconds: elapsedSeconds)
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
        guard let expected = currentCharacter else { return }

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
        recordCurrentCharacterOccurrence()
        refreshDictationIfNeeded()
    }

    private func recordCurrentCharacterOccurrence() {
        if let current = currentCharacter {
            characterStats.recordOccurrence(current)
        }
    }

    // MARK: - Textversorgung

    private func assembleInitialText(from segments: [TextSegment]) {
        if !configuration.intelligence {
            // Ohne Intelligenz wird die Lektion sequenziell diktiert.
            for segment in segments {
                appendSegment(segment.text)
            }
        } else if let intro = picker.firstSegment() {
            appendSegment(intro.text)
        }
    }

    private func refreshDictationIfNeeded() {
        guard configuration.limit != .entireLesson,
            configuration.intelligence,
            dictationCharacters.count - cursorIndex
                <= DictationToken.charactersUntilRefresh,
            let next = picker.nextSegment(stats: characterStats)
        else { return }
        appendSegment(next.text)
    }

    private func appendSegment(_ text: String) {
        let sanitized = text.replacingOccurrences(
            of: "\t", with: String(DictationToken.tab)
        )
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

    // MARK: - Limits

    private func checkLimits() {
        switch configuration.limit {
        case .time(let minutes):
            if elapsedSeconds >= minutes * 60 { finish() }
        case .characters(let count):
            if dictatedCharacters >= count { finish() }
        case .entireLesson:
            if cursorIndex >= dictationCharacters.count { finish() }
        }
    }
}
