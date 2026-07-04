import Foundation

/// Zeichenstatistik: Wie oft wurde ein Zeichen diktiert, wie oft wurde es
/// als Ziel verfehlt und wie oft wurde es fälschlich getippt.
/// Grundlage der Intelligenz-Funktion.
struct CharacterStats {
    struct Entry: Codable, Equatable {
        var occurrences = 0
        var targetErrors = 0
        var mistakes = 0
    }

    private(set) var entries: [Character: Entry] = [:]

    mutating func recordOccurrence(_ character: Character) {
        entries[character, default: Entry()].occurrences += 1
    }

    mutating func recordTargetError(_ character: Character) {
        entries[character, default: Entry()].targetErrors += 1
    }

    mutating func recordMistake(_ character: Character) {
        entries[character, default: Entry()].mistakes += 1
    }

    /// Fehlerquote in Prozent: Zielfehler × 100 / Vorkommen.
    func errorRate(of character: Character) -> Double {
        guard let entry = entries[character], entry.occurrences > 0 else {
            return 0
        }
        return Double(entry.targetErrors) * 100.0 / Double(entry.occurrences)
    }

    func mistakes(of character: Character) -> Int {
        entries[character]?.mistakes ?? 0
    }

    /// Die fehlerträchtigsten Zeichen, absteigend nach Fehlerquote.
    /// Zeichen ohne Zielfehler tauchen nicht auf.
    func worstCharacters(limit: Int = 4) -> [Character] {
        entries
            .filter { $0.value.targetErrors > 0 && $0.value.occurrences > 0 }
            .sorted { lhs, rhs in
                let l = errorRate(of: lhs.key)
                let r = errorRate(of: rhs.key)
                if l != r { return l > r }
                return lhs.key < rhs.key
            }
            .prefix(limit)
            .map(\.key)
    }
}
