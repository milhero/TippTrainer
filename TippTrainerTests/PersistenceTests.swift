import Foundation
import SwiftData
import Testing
@testable import TippTrainer

@MainActor
struct PersistenceTests {
    private func makeContext() -> ModelContext {
        let container = PersistenceController.makeContainer(inMemory: true)
        return ModelContext(container)
    }

    @Test func savingARecordMergesCharacterStats() throws {
        let context = makeContext()
        let store = StatisticsStore(context: context)

        var stats = CharacterStats()
        for _ in 1...5 { stats.recordOccurrence("e") }
        stats.recordTargetError("e")
        stats.recordMistake("r")

        _ = store.save(
            lessonTitle: "Lektion 1",
            language: .german,
            kind: .practice,
            strokes: 100, errors: 3, characters: 103, seconds: 60,
            characterStats: stats
        )

        let records = try context.fetch(FetchDescriptor<LessonRecord>())
        #expect(records.count == 1)
        #expect(records.first?.points == Scorer.points(strokes: 100, errors: 3, seconds: 60))

        let charRecords = try context.fetch(FetchDescriptor<CharRecord>())
        let e = charRecords.first { $0.character == "e" }
        #expect(e?.occurrences == 5)
        #expect(e?.targetErrors == 1)
    }

    @Test func characterStatsAccumulateAcrossSessions() throws {
        let context = makeContext()
        let store = StatisticsStore(context: context)

        var first = CharacterStats()
        first.recordOccurrence("a")
        first.recordTargetError("a")
        _ = store.save(
            lessonTitle: "L1", language: .german, kind: .practice,
            strokes: 10, errors: 1, characters: 10, seconds: 30,
            characterStats: first
        )

        var second = CharacterStats()
        second.recordOccurrence("a")
        _ = store.save(
            lessonTitle: "L1", language: .german, kind: .practice,
            strokes: 10, errors: 0, characters: 10, seconds: 30,
            characterStats: second
        )

        let charRecords = try context.fetch(FetchDescriptor<CharRecord>())
        let a = charRecords.first { $0.character == "a" }
        #expect(a?.occurrences == 2)
        #expect(a?.targetErrors == 1)
    }

    @Test func recordIsRecognisedWhenPointsExceedPreviousBest() {
        let context = makeContext()
        let store = StatisticsStore(context: context)
        let stats = CharacterStats()

        let first = store.save(
            lessonTitle: "L1", language: .german, kind: .practice,
            strokes: 100, errors: 0, characters: 100, seconds: 60,
            characterStats: stats
        )
        #expect(first.isPersonalRecord) // erster Eintrag zählt als Rekord

        let worse = store.save(
            lessonTitle: "L1", language: .german, kind: .practice,
            strokes: 50, errors: 0, characters: 50, seconds: 60,
            characterStats: stats
        )
        #expect(!worse.isPersonalRecord)

        let better = store.save(
            lessonTitle: "L1", language: .german, kind: .practice,
            strokes: 200, errors: 0, characters: 200, seconds: 60,
            characterStats: stats
        )
        #expect(better.isPersonalRecord)
    }

    @Test func resettingLessonsClearsRecordsButKeepsCharStats() throws {
        let context = makeContext()
        let store = StatisticsStore(context: context)
        var stats = CharacterStats()
        stats.recordOccurrence("x")
        _ = store.save(
            lessonTitle: "L1", language: .german, kind: .practice,
            strokes: 10, errors: 0, characters: 10, seconds: 30,
            characterStats: stats
        )

        store.resetLessons()
        #expect(try context.fetch(FetchDescriptor<LessonRecord>()).isEmpty)
        #expect(!(try context.fetch(FetchDescriptor<CharRecord>()).isEmpty))

        store.resetCharacterStats()
        #expect(try context.fetch(FetchDescriptor<CharRecord>()).isEmpty)
    }
}
