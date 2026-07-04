import Foundation

/// Tempologik der Laufschrift. Stufe 0 ist der stehende Text mit
/// Blocksprung; die Stufen 1–4 scrollen kontinuierlich, wobei der Ticker
/// beschleunigt, je weiter die Schreibposition vorauseilt.
enum TickerPacing {
    static let jumpLevel = 0
    static let levelRange = 0...4
    static let defaultLevel = 2

    /// Millisekunden pro Pixel für eine Tempostufe (1–4).
    static func baseInterval(forLevel level: Int) -> Int {
        50 - level * 10
    }

    static func isJumpMode(level: Int) -> Bool {
        level == jumpLevel
    }

    /// Adaptives Aufholen: Je größer der Abstand zwischen Schreibposition
    /// und Scrollposition, desto kürzer das Intervall (= schneller).
    static func interval(base: Int, gapToCursor gap: Int) -> Int {
        switch gap {
        case ...30: return base
        case 31...60: return base - 3 * (base / 10)
        case 61...90: return base - 5 * (base / 10)
        default: return base - 8 * (base / 10)
        }
    }
}
