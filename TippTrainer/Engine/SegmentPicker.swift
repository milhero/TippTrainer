import Foundation

/// Ein Textbaustein einer Lektion (Wort, Satz oder Zahlenreihe).
struct TextSegment: Equatable, Sendable {
    let id: Int
    let text: String
}

/// Deterministischer Zufallsgenerator (SplitMix64), damit die
/// Segmentauswahl testbar bleibt.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

/// Wählt den nächsten Textbaustein einer Lektion aus — mit oder ohne
/// Intelligenz. Mit Intelligenz werden Bausteine bevorzugt, die die
/// aktuell fehlerträchtigsten Zeichen am häufigsten enthalten; jede
/// zweite Abfrage ist stattdessen zufällig, und die letzten zehn
/// Bausteine werden nie wiederholt.
struct SegmentPicker {
    private let segments: [TextSegment]
    private let intelligence: Bool
    private let antiRepeatLimit: Int
    private let randomEveryNthQuery: Int
    private var rng: SeededGenerator
    private var recentIDs: [Int] = []
    private var queryCounter = 0

    init(
        segments: [TextSegment],
        intelligence: Bool,
        seed: UInt64,
        antiRepeatLimit: Int = 10,
        randomEveryNthQuery: Int = 2
    ) {
        self.segments = segments
        self.intelligence = intelligence
        self.antiRepeatLimit = antiRepeatLimit
        self.randomEveryNthQuery = randomEveryNthQuery
        self.rng = SeededGenerator(seed: seed)
    }

    /// Die feste Intro-Zeile: immer der erste Baustein der Lektion.
    mutating func firstSegment() -> TextSegment? {
        guard let first = segments.first else { return nil }
        remember(first.id)
        return first
    }

    mutating func nextSegment(stats: CharacterStats) -> TextSegment? {
        guard !segments.isEmpty else { return nil }
        queryCounter += 1

        let worst = stats.worstCharacters(limit: 4)
        let useWeighted = intelligence
            && !worst.isEmpty
            && queryCounter % randomEveryNthQuery != 0

        var pool = segments
        if useWeighted, pool.count > 1 {
            // Die Intro-Zeile nimmt an der gewichteten Auswahl nicht teil.
            pool.removeFirst()
        }
        var ordered = pool.shuffled(using: &rng)
        if useWeighted {
            ordered.sort { lhs, rhs in
                for character in worst {
                    let l = lhs.text.occurrences(of: character)
                    let r = rhs.text.occurrences(of: character)
                    if l != r { return l > r }
                }
                return false
            }
        }

        if let pick = ordered.first(where: { !recentIDs.contains($0.id) }) {
            remember(pick.id)
            return pick
        }

        // Alle Kandidaten kürzlich verwendet: Verlauf bis auf den
        // jüngsten Eintrag leeren und erneut wählen.
        if recentIDs.count > 1 {
            recentIDs.removeSubrange(1...)
        }
        if let pick = ordered.first(where: { !recentIDs.contains($0.id) }) {
            remember(pick.id)
            return pick
        }
        return ordered.first
    }

    private mutating func remember(_ id: Int) {
        recentIDs.insert(id, at: 0)
        if recentIDs.count > antiRepeatLimit {
            recentIDs.removeLast()
        }
    }
}

extension String {
    func occurrences(of character: Character) -> Int {
        reduce(0) { $1 == character ? $0 + 1 : $0 }
    }
}
