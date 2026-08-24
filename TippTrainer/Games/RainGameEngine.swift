import Foundation

/// Ein fallender Buchstabe. Position normiert (0…1) im Spielfeld.
struct LetterDrop: Identifiable {
    let id = UUID()
    let character: Character
    var x: Double
    var y: Double
}

enum RainGameState { case ready, running, over }

/// Spiellogik des Buchstabenregens — UI-frei und testbar. Fallende
/// Buchstaben müssen abgetippt werden, bevor sie den Boden erreichen.
@Observable
final class RainGameEngine {
    private(set) var drops: [LetterDrop] = []
    private(set) var score = 0
    private(set) var level = 1
    private(set) var lives = 3
    /// Anschläge, die keinen fallenden Buchstaben getroffen haben.
    private(set) var errors = 0

    /// Punktabzug je Fehlanschlag.
    static let errorPenalty = 5
    private(set) var state: RainGameState = .ready

    private let pool: [Character]
    private var rng: SeededGenerator

    init(pool: [Character], seed: UInt64 = UInt64.random(in: .min ... .max)) {
        self.pool = pool.isEmpty ? Array("asdfjklö") : pool
        self.rng = SeededGenerator(seed: seed)
    }

    /// Fallgeschwindigkeit (Feldanteil pro Sekunde), steigt mit dem Level.
    var fallSpeed: Double { 0.14 + Double(level - 1) * 0.03 }

    /// Sekunden zwischen zwei neuen Buchstaben, sinkt mit dem Level.
    var spawnInterval: Double { max(0.5, 1.4 - Double(level - 1) * 0.1) }

    func start() {
        drops.removeAll()
        score = 0
        level = 1
        lives = 3
        errors = 0
        state = .running
    }

    func spawn() {
        guard state == .running, let character = pool.randomElement(using: &rng) else {
            return
        }
        drops.append(LetterDrop(
            character: character,
            x: Double.random(in: 0.06...0.94, using: &rng),
            y: 0
        ))
    }

    /// Testhilfe: Buchstaben an fester Position einfügen.
    func addDrop(character: Character, x: Double, y: Double) {
        drops.append(LetterDrop(character: character, x: x, y: y))
    }

    /// Verarbeitet einen Tastenanschlag. Trifft den bodennächsten
    /// passenden Buchstaben. Gibt zurück, ob getroffen wurde. Ein Anschlag
    /// ohne Treffer zählt als Fehler und kostet Punkte (nie unter null);
    /// Leben kosten nur verpasste Buchstaben.
    @discardableResult
    func type(_ character: Character) -> Bool {
        guard state == .running else { return false }
        let candidates = drops.enumerated()
            .filter { $0.element.character == character }
            .sorted { $0.element.y > $1.element.y }
        guard let target = candidates.first else {
            errors += 1
            score = max(0, score - Self.errorPenalty)
            updateLevel()
            return false
        }
        drops.remove(at: target.offset)
        score += 10
        updateLevel()
        return true
    }

    /// Lässt alle Buchstaben um deltaTime weiterfallen; entfernt jene,
    /// die den Boden erreichen, und zieht dafür ein Leben ab.
    func update(deltaTime: Double) {
        guard state == .running else { return }
        for index in drops.indices {
            drops[index].y += fallSpeed * deltaTime
        }
        let reachedBottom = drops.filter { $0.y >= 1.0 }
        if !reachedBottom.isEmpty {
            drops.removeAll { $0.y >= 1.0 }
            lives -= reachedBottom.count
            if lives <= 0 {
                lives = 0
                state = .over
            }
        }
    }

    private func updateLevel() {
        level = max(1, score / 100 + 1)
    }
}
