import Foundation

/// Kennzahlen einer Trainingseinheit.
nonisolated enum Scorer {
    /// Punkteformel des klassischen Trainers:
    /// ((Anschläge − 20 × Fehler) / Minuten) × 0,4, kaufmännisch gerundet.
    static func points(strokes: Int, errors: Int, seconds: Int) -> Int {
        guard seconds > 0 else { return 0 }
        let minutes = Double(seconds) / 60.0
        let raw = (Double(strokes) - 20.0 * Double(errors)) / minutes * 0.4
        return Int(raw.rounded())
    }

    static func strokesPerMinute(strokes: Int, seconds: Int) -> Double {
        guard seconds > 0 else { return 0 }
        return Double(strokes) / (Double(seconds) / 60.0)
    }

    /// Fehlerquote in Prozent, bezogen auf die diktierten Zeichen.
    static func errorRate(errors: Int, characters: Int) -> Double {
        guard characters > 0 else { return 0 }
        return Double(errors) * 100.0 / Double(characters)
    }
}
