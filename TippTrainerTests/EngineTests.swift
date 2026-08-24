import Foundation
import Observation
import Testing
@testable import TippTrainer

// MARK: - Punkteformel

struct ScorerTests {
    @Test func pointsMatchOriginalFormula() {
        // ((Anschläge − 20×Fehler) / Minuten) × 0,4
        #expect(Scorer.points(strokes: 500, errors: 0, seconds: 300) == 40)
        #expect(Scorer.points(strokes: 600, errors: 5, seconds: 120) == 100)
    }

    @Test func pointsAreRoundedToNearestInteger() {
        // (100 / 1,5) × 0,4 = 26,67 → 27
        #expect(Scorer.points(strokes: 100, errors: 0, seconds: 90) == 27)
    }

    @Test func strokesPerMinute() {
        #expect(Scorer.strokesPerMinute(strokes: 250, seconds: 150) == 100)
        #expect(Scorer.strokesPerMinute(strokes: 0, seconds: 0) == 0)
    }

    @Test func errorRatePercent() {
        #expect(Scorer.errorRate(errors: 5, characters: 200) == 2.5)
        #expect(Scorer.errorRate(errors: 3, characters: 0) == 0)
    }
}

// MARK: - Zeichenstatistik

struct CharacterStatsTests {
    @Test func tracksOccurrencesAndErrors() {
        var stats = CharacterStats()
        stats.recordOccurrence("e")
        stats.recordOccurrence("e")
        stats.recordTargetError("e")
        stats.recordMistake("r")
        #expect(stats.errorRate(of: "e") == 50)
        #expect(stats.errorRate(of: "x") == 0)
    }

    @Test func worstCharactersAreOrderedByErrorRate() {
        var stats = CharacterStats()
        for _ in 1...10 { stats.recordOccurrence("a") }
        stats.recordTargetError("a") // 10 %
        for _ in 1...2 { stats.recordOccurrence("b") }
        stats.recordTargetError("b") // 50 %
        for _ in 1...4 { stats.recordOccurrence("c") }
        stats.recordTargetError("c") // 25 %
        for _ in 1...50 { stats.recordOccurrence("d") } // fehlerfrei

        #expect(stats.worstCharacters(limit: 4) == ["b", "c", "a"])
    }
}

// MARK: - Intelligente Segmentauswahl

struct SegmentPickerTests {
    private func makeSegments(_ texts: [String]) -> [TextSegment] {
        texts.enumerated().map { TextSegment(id: $0.offset + 1, text: $0.element) }
    }

    @Test func firstSegmentIsTheIntroLine() {
        var picker = SegmentPicker(
            segments: makeSegments(["intro zeile", "aaa", "bbb"]),
            intelligence: true, seed: 7
        )
        #expect(picker.firstSegment()?.text == "intro zeile")
    }

    @Test func errorWeightedPickPrefersSegmentsWithWorstCharacter() {
        var stats = CharacterStats()
        for _ in 1...4 { stats.recordOccurrence("x") }
        stats.recordTargetError("x")
        stats.recordTargetError("x")

        var picker = SegmentPicker(
            segments: makeSegments(["intro", "ohne treffer", "xx xx xx", "ein x nur"]),
            intelligence: true, seed: 1
        )
        _ = picker.firstSegment()
        // Query 1: queryCounter % 2 != 0 → fehlergewichtete Auswahl
        #expect(picker.nextSegment(stats: stats)?.text == "xx xx xx")
    }

    @Test func everySecondQueryIsRandomInsteadOfWeighted() {
        var stats = CharacterStats()
        stats.recordOccurrence("z")
        stats.recordTargetError("z")

        var picker = SegmentPicker(
            segments: makeSegments(["intro", "zz zz", "aaa", "bbb"]),
            intelligence: true, seed: 3
        )
        _ = picker.firstSegment()
        _ = picker.nextSegment(stats: stats) // Query 1: gewichtet
        // Query 2 ist zufällig — muss aber in jedem Fall ein noch
        // nicht verwendetes Segment liefern.
        let second = picker.nextSegment(stats: stats)
        #expect(second != nil)
        #expect(second?.text != "zz zz")
    }

    @Test func recentSegmentsAreNotRepeated() {
        var picker = SegmentPicker(
            segments: makeSegments(["intro", "a", "b", "c", "d"]),
            intelligence: true, seed: 11
        )
        _ = picker.firstSegment()
        let stats = CharacterStats()
        var seen = Set<String>()
        for _ in 1...3 {
            let segment = picker.nextSegment(stats: stats)!
            #expect(!seen.contains(segment.text), "Segment wiederholt: \(segment.text)")
            seen.insert(segment.text)
        }
    }

    @Test func exhaustedPoolResetsInsteadOfStalling() {
        var picker = SegmentPicker(
            segments: makeSegments(["intro", "a", "b"]),
            intelligence: true, seed: 5
        )
        _ = picker.firstSegment()
        let stats = CharacterStats()
        for _ in 1...10 {
            #expect(picker.nextSegment(stats: stats) != nil)
        }
    }
}

// MARK: - Trainingssitzung

struct TrainingSessionTests {
    private func makeSession(
        segments: [String],
        unit: LessonUnit = .sentence,
        limit: TrainingLimit = .time(minutes: 5),
        blockOnError: Bool = true,
        requireBackspaceCorrection: Bool = false,
        intelligence: Bool = true
    ) -> TrainingSession {
        let config = TrainingConfiguration(
            limit: limit,
            blockOnError: blockOnError,
            requireBackspaceCorrection: requireBackspaceCorrection,
            beepOnError: false,
            intelligence: intelligence
        )
        return TrainingSession(
            segments: segments.enumerated().map {
                TextSegment(id: $0.offset + 1, text: $0.element)
            },
            unit: unit,
            configuration: config,
            seed: 42
        )
    }

    @Test func spaceStartsTheSession() {
        let session = makeSession(segments: ["abc", "def"])
        #expect(session.state == .ready)
        session.handleKey(.character(" "))
        #expect(session.state == .running)
    }

    @Test func correctKeysAdvanceCursorAndCountStrokes() {
        let session = makeSession(segments: ["abc", "xyz"])
        session.handleKey(.character(" "))
        session.handleKey(.character("a"))
        session.handleKey(.character("b"))
        #expect(session.strokes == 2)
        #expect(session.errors == 0)
    }

    @Test func wrongKeyCountsOnlyOneErrorPerTargetCharacter() {
        let session = makeSession(segments: ["abc", "xyz"])
        session.handleKey(.character(" "))
        session.handleKey(.character("q"))
        session.handleKey(.character("q"))
        session.handleKey(.character("q"))
        #expect(session.errors == 1)
        session.handleKey(.character("a"))
        #expect(session.strokes == 1)
    }

    @Test func blockOnErrorHoldsCursorUntilCorrectKey() {
        let session = makeSession(segments: ["ab", "xy"])
        session.handleKey(.character(" "))
        session.handleKey(.character("z"))
        #expect(session.strokes == 0)
        session.handleKey(.character("a"))
        session.handleKey(.character("b"))
        #expect(session.strokes == 2)
        #expect(session.errors == 1)
    }

    @Test func withoutBlockingTheCursorAdvancesDespiteError() {
        let session = makeSession(segments: ["ab", "xy"], blockOnError: false)
        session.handleKey(.character(" "))
        session.handleKey(.character("z")) // falsch, rückt trotzdem vor
        session.handleKey(.character("b"))
        #expect(session.errors == 1)
        #expect(session.strokes == 2)
    }

    @Test func backspaceCorrectionModeRequiresBackspaceFirst() {
        let session = makeSession(
            segments: ["ab", "xy"], requireBackspaceCorrection: true
        )
        session.handleKey(.character(" "))
        session.handleKey(.character("z"))
        #expect(session.awaitingCorrection)
        session.handleKey(.character("a")) // wird ignoriert
        #expect(session.strokes == 0)
        session.handleKey(.backspace)
        #expect(!session.awaitingCorrection)
        session.handleKey(.character("a"))
        #expect(session.strokes == 1)
    }

    @Test func enterMatchesNewlineTokenAndTabMatchesTabToken() {
        let session = makeSession(segments: ["a¶b\tc"], limit: .entireLesson)
        session.handleKey(.character(" "))
        session.handleKey(.character("a"))
        session.handleKey(.enter)
        session.handleKey(.character("b"))
        session.handleKey(.tab)
        session.handleKey(.character("c"))
        #expect(session.strokes == 5)
        #expect(session.errors == 0)
    }

    @Test func statsRecordTargetAndMistakeCharacters() {
        let session = makeSession(segments: ["ab", "xy"])
        session.handleKey(.character(" "))
        session.handleKey(.character("z"))
        #expect(session.characterStats.errorRate(of: "a") == 100)
        session.handleKey(.character("a"))
        let mistakes = session.characterStats.mistakes(of: "z")
        #expect(mistakes == 1)
    }

    @Test func timeLimitFinishesTheSession() {
        let session = makeSession(segments: ["abc", "def"], limit: .time(minutes: 1))
        session.handleKey(.character(" "))
        for _ in 1...60 { session.tick() }
        #expect(session.state == .finished)
    }

    @Test func characterLimitFinishesTheSession() {
        let session = makeSession(segments: ["abcdef", "ghijkl"], limit: .characters(3))
        session.handleKey(.character(" "))
        session.handleKey(.character("a"))
        session.handleKey(.character("b"))
        session.handleKey(.character("c"))
        session.tick()
        #expect(session.state == .finished)
    }

    @Test func entireLessonFinishesAtTheEnd() {
        let session = makeSession(
            segments: ["ab"], unit: .sentence, limit: .entireLesson,
            intelligence: false
        )
        session.handleKey(.character(" "))
        session.handleKey(.character("a"))
        session.handleKey(.character("b"))
        session.handleKey(.enter) // ¶ am Satzende
        session.tick()
        #expect(session.state == .finished)
    }

    @Test func wordUnitJoinsSegmentsWithSpacesAndBreaksLongLines() {
        let words = (1...20).map { _ in "wort" }
        let session = makeSession(segments: words, unit: .word, intelligence: false)
        session.handleKey(.character(" "))
        let text = session.dictationText
        #expect(text.contains("wort wort"))
        // Nach spätestens 35 Zeichen pro Zeile muss ein Umbruch folgen
        let lines = text.split(separator: "¶")
        #expect(lines.allSatisfy { $0.count <= 41 })
    }

    @Test func runningLowOnTextExtendsTheDictation() {
        let session = makeSession(
            segments: ["abcdefghij", "klmnopqrst", "uvwxyzabcd", "efghijklmn"],
            unit: .sentence
        )
        session.handleKey(.character(" "))
        let initialLength = session.dictationText.count
        // Intro ist kurz: Nach dem ersten Zeichen muss Nachschub kommen,
        // sobald weniger als 25 Zeichen verbleiben.
        session.handleKey(.character("a"))
        #expect(session.dictationText.count > initialLength)
    }

    @Test func stateChangesAreObservable() {
        let session = makeSession(segments: ["abc", "def"])
        let notified = ChangeFlag()
        withObservationTracking {
            _ = session.state
        } onChange: {
            notified.raise()
        }
        session.handleKey(.character(" "))
        #expect(notified.wasRaised) // sonst zeichnet die Ansicht nicht neu
    }

    @Test func cursorChangesAreObservable() {
        let session = makeSession(segments: ["abc", "def"])
        session.handleKey(.character(" "))
        let notified = ChangeFlag()
        withObservationTracking {
            _ = session.cursorIndex
        } onChange: {
            notified.raise()
        }
        session.handleKey(.character("a"))
        #expect(notified.wasRaised)
    }

    @Test func elapsedSecondsAreObservable() {
        let session = makeSession(segments: ["abc", "def"])
        session.handleKey(.character(" "))
        let notified = ChangeFlag()
        withObservationTracking {
            _ = session.elapsedSeconds
        } onChange: {
            notified.raise()
        }
        session.tick()
        #expect(notified.wasRaised)
    }

    @Test func pauseSuspendsTimeAndInput() {
        let session = makeSession(segments: ["abc", "def"])
        session.handleKey(.character(" "))
        session.pause()
        #expect(session.state == .paused)
        session.tick()
        #expect(session.elapsedSeconds == 0)
        session.handleKey(.character("a"))
        #expect(session.strokes == 0)
        session.handleKey(.character(" ")) // Leertaste setzt fort
        #expect(session.state == .running)
    }
}

// MARK: - Laufschrift-Tempo

struct TickerPacingTests {
    @Test func baseIntervalDependsOnSpeedLevel() {
        #expect(TickerPacing.baseInterval(forLevel: 1) == 40)
        #expect(TickerPacing.baseInterval(forLevel: 2) == 30)
        #expect(TickerPacing.baseInterval(forLevel: 4) == 10)
    }

    @Test func levelZeroMeansJumpMode() {
        #expect(TickerPacing.isJumpMode(level: 0))
        #expect(!TickerPacing.isJumpMode(level: 2))
    }

    @Test func tickerCatchesUpWhenTypistIsFarAhead() {
        let base = 30
        #expect(TickerPacing.interval(base: base, gapToCursor: 10) == 30)
        #expect(TickerPacing.interval(base: base, gapToCursor: 45) == 21)
        #expect(TickerPacing.interval(base: base, gapToCursor: 75) == 15)
        #expect(TickerPacing.interval(base: base, gapToCursor: 120) == 6)
    }
}

/// Testhilfe: threadsicherer Merker, da `onChange` `@Sendable` ist.
private nonisolated final class ChangeFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var raised = false
    func raise() { lock.lock(); raised = true; lock.unlock() }
    var wasRaised: Bool { lock.lock(); defer { lock.unlock() }; return raised }
}
