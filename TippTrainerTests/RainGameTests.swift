import Testing
@testable import TippTrainer

struct RainGameTests {
    @Test func startsAtLevelOneWithZeroScore() {
        let game = RainGameEngine(pool: Array("asdf"), seed: 1)
        game.start()
        #expect(game.level == 1)
        #expect(game.score == 0)
        #expect(game.lives == 3)
        #expect(game.state == .running)
    }

    @Test func spawningAddsFallingLetters() {
        let game = RainGameEngine(pool: Array("asdf"), seed: 1)
        game.start()
        game.spawn()
        #expect(game.drops.count == 1)
        #expect("asdf".contains(game.drops[0].character))
    }

    @Test func typingCorrectLetterRemovesNearestDropAndScores() {
        let game = RainGameEngine(pool: Array("as"), seed: 1)
        game.start()
        game.addDrop(character: "a", x: 0.5, y: 0.4)
        game.addDrop(character: "a", x: 0.2, y: 0.8) // näher am Boden
        let hit = game.type("a")
        #expect(hit)
        #expect(game.drops.count == 1)
        #expect(game.drops[0].y == 0.4) // der untere wurde getroffen
        #expect(game.score == 10)
    }

    @Test func typingWrongLetterDoesNotScore() {
        let game = RainGameEngine(pool: Array("as"), seed: 1)
        game.start()
        game.addDrop(character: "a", x: 0.5, y: 0.4)
        let hit = game.type("s")
        #expect(!hit)
        #expect(game.drops.count == 1)
        #expect(game.score == 0)
    }

    @Test func dropsFallOverTimeAndCostALifeAtTheBottom() {
        let game = RainGameEngine(pool: Array("a"), seed: 1)
        game.start()
        game.addDrop(character: "a", x: 0.5, y: 0.95)
        game.update(deltaTime: 1.0) // fällt genug, um den Boden zu erreichen
        #expect(game.drops.isEmpty)
        #expect(game.lives == 2)
    }

    @Test func losingAllLivesEndsTheGame() {
        let game = RainGameEngine(pool: Array("a"), seed: 1)
        game.start()
        for _ in 0..<3 {
            game.addDrop(character: "a", x: 0.5, y: 0.99)
            game.update(deltaTime: 1.0)
        }
        #expect(game.state == .over)
    }

    @Test func levelIncreasesWithScore() {
        let game = RainGameEngine(pool: Array("a"), seed: 1)
        game.start()
        for _ in 0..<10 {
            game.addDrop(character: "a", x: 0.5, y: 0.5)
            _ = game.type("a")
        }
        // 100 Punkte → Level 2
        #expect(game.level >= 2)
    }

    @Test func wrongLetterCountsAnErrorAndDeductsPoints() {
        let game = RainGameEngine(pool: Array("as"), seed: 1)
        game.start()
        game.addDrop(character: "a", x: 0.5, y: 0.4)
        game.addDrop(character: "s", x: 0.3, y: 0.6)
        _ = game.type("a") // Treffer: +10, entfernt das "a"
        #expect(game.score == 10)
        #expect(game.errors == 0)
        #expect(game.drops.count == 1)

        let hit = game.type("x") // Fehltreffer
        #expect(!hit)
        #expect(game.errors == 1)
        #expect(game.score == 5) // 10 - 5
        #expect(game.lives == 3) // Leben bleiben unangetastet
        #expect(game.drops.count == 1) // kein Buchstabe wird entfernt
    }

    @Test func errorsNeverPushTheScoreBelowZero() {
        let game = RainGameEngine(pool: Array("a"), seed: 1)
        game.start()
        _ = game.type("x")
        _ = game.type("x")
        #expect(game.errors == 2)
        #expect(game.score == 0)
    }

    @Test func startResetsTheErrorCount() {
        let game = RainGameEngine(pool: Array("a"), seed: 1)
        game.start()
        _ = game.type("x")
        #expect(game.errors == 1)
        game.start()
        #expect(game.errors == 0)
    }

    @Test func wrongLetterIsIgnoredBeforeTheGameStarts() {
        let game = RainGameEngine(pool: Array("a"), seed: 1)
        _ = game.type("x") // Zustand .ready
        #expect(game.errors == 0)
        #expect(game.score == 0)
    }
}
