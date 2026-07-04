import Foundation
import SwiftData

struct SaveResult {
    let record: LessonRecord
    let isPersonalRecord: Bool
}

/// Schreibt Trainingsergebnisse in SwiftData und pflegt die kumulierte
/// Zeichenstatistik. Erkennt persönliche Rekorde je Lektion.
@MainActor
struct StatisticsStore {
    let context: ModelContext

    @discardableResult
    func save(
        lessonTitle: String,
        language: LessonLanguage,
        kind: LessonKind,
        strokes: Int,
        errors: Int,
        characters: Int,
        seconds: Int,
        characterStats: CharacterStats
    ) -> SaveResult {
        let points = Scorer.points(strokes: strokes, errors: errors, seconds: seconds)
        let isRecord = isPersonalRecord(title: lessonTitle, points: points)

        let record = LessonRecord(
            lessonTitle: lessonTitle,
            language: language,
            kind: kind,
            strokes: strokes,
            errors: errors,
            characters: characters,
            seconds: seconds,
            points: points
        )
        context.insert(record)
        mergeCharacterStats(characterStats)
        try? context.save()
        return SaveResult(record: record, isPersonalRecord: isRecord)
    }

    private func isPersonalRecord(title: String, points: Int) -> Bool {
        let descriptor = FetchDescriptor<LessonRecord>(
            predicate: #Predicate { $0.lessonTitle == title }
        )
        let previous = (try? context.fetch(descriptor)) ?? []
        guard let best = previous.map(\.points).max() else { return true }
        return points > best
    }

    private func mergeCharacterStats(_ stats: CharacterStats) {
        for (character, entry) in stats.entries {
            guard let scalar = character.unicodeScalars.first else { continue }
            let code = Int(scalar.value)
            let descriptor = FetchDescriptor<CharRecord>(
                predicate: #Predicate { $0.unicode == code }
            )
            if let existing = (try? context.fetch(descriptor))?.first {
                existing.occurrences += entry.occurrences
                existing.targetErrors += entry.targetErrors
                existing.mistakes += entry.mistakes
            } else {
                context.insert(CharRecord(
                    unicode: code,
                    occurrences: entry.occurrences,
                    targetErrors: entry.targetErrors,
                    mistakes: entry.mistakes
                ))
            }
        }
    }

    /// Vorbelegung der Zeichenstatistik einer neuen Sitzung mit den
    /// bereits gesammelten Fehlern (damit die Intelligenz sofort greift).
    func accumulatedCharacterStats() -> CharacterStats {
        var stats = CharacterStats()
        let records = (try? context.fetch(FetchDescriptor<CharRecord>())) ?? []
        for record in records {
            let character = record.character
            for _ in 0..<record.occurrences { stats.recordOccurrence(character) }
            for _ in 0..<record.targetErrors { stats.recordTargetError(character) }
            for _ in 0..<record.mistakes { stats.recordMistake(character) }
        }
        return stats
    }

    func resetLessons() {
        try? context.delete(model: LessonRecord.self)
        try? context.save()
    }

    func resetCharacterStats() {
        try? context.delete(model: CharRecord.self)
        try? context.save()
    }
}
