import Foundation
import Testing
@testable import TippTrainer

/// Die generierten Lernschritte müssen zum Lehrplan passen: nur bereits
/// gelernte Zeichen, sinnvolle Fingerhinweise, feste Struktur.
struct CurriculumTests {
    @Test(arguments: [LessonLanguage.german, .english])
    func stepsUseOnlyCharactersLearnedSoFar(language: LessonLanguage) throws {
        let lessons = try ContentStore.practiceLessons(for: language)
        var cumulative = Set<Character>(" ")
        for lesson in lessons where lesson.number <= 18 {
            cumulative.formUnion(lesson.newCharacters)
            for step in LessonCurriculum.steps(for: lesson, language: language) {
                let illegal = Set(step.drill).subtracting(cumulative)
                #expect(
                    illegal.isEmpty,
                    "L\(lesson.number) »\(step.title)«: unerlaubte Zeichen \(illegal)"
                )
                #expect(!step.drill.isEmpty, "L\(lesson.number) »\(step.title)« ohne Übungszeile")
                #expect(!step.hint.isEmpty, "L\(lesson.number) »\(step.title)« ohne Hinweis")
                #expect(step.drill.count <= 45, "L\(lesson.number) »\(step.title)« zu lang")
            }
        }
    }

    @Test(arguments: [LessonLanguage.german, .english])
    func numpadStepsUseOnlyNumpadCharacters(language: LessonLanguage) throws {
        let lessons = try ContentStore.practiceLessons(for: language)
        var allowed = Set<Character>(" ")
        for lesson in lessons where lesson.unit == .numpad {
            allowed.formUnion(lesson.newCharacters)
            let steps = LessonCurriculum.steps(for: lesson, language: language)
            #expect(!steps.isEmpty)
            for step in steps {
                #expect(Set(step.drill).isSubset(of: allowed), "L\(lesson.number): »\(step.drill)«")
            }
        }
    }

    @Test(arguments: [LessonLanguage.german, .english])
    func everyLessonExceptTheMixedOneHasSteps(language: LessonLanguage) throws {
        for lesson in try ContentStore.practiceLessons(for: language) {
            let steps = LessonCurriculum.steps(for: lesson, language: language)
            if lesson.number == 18 {
                #expect(steps.isEmpty)
            } else {
                #expect((2...7).contains(steps.count), "L\(lesson.number): \(steps.count) Schritte")
            }
        }
    }

    @Test func firstLessonTeachesTheHomeRowFingerByFinger() throws {
        let lesson = try #require(ContentStore.practiceLessons(for: .german).first)
        let steps = LessonCurriculum.steps(for: lesson, language: .german)
        #expect(steps.count == 6)
        #expect(steps.first?.title == "Grundstellung")
        #expect(steps.first?.drill == lesson.intro)
        #expect(steps[1].fingers == [.leftIndex, .rightIndex])
        #expect(steps[1].drill.hasPrefix("fff jjj"))
        #expect(steps[4].fingers == [.leftPinky, .rightPinky])
        #expect(steps[4].drill.hasPrefix("aaa ööö"))
        #expect(steps.last?.title == "Alles zusammen")
    }

    @Test func englishHomeRowUsesTheSemicolon() throws {
        let lesson = try #require(ContentStore.practiceLessons(for: .english).first)
        let steps = LessonCurriculum.steps(for: lesson, language: .english)
        #expect(steps[4].drill.hasPrefix("aaa ;;;"))
    }

    @Test func newLetterStepExplainsFingerAndDirection() throws {
        let lessons = try ContentStore.practiceLessons(for: .german)
        let steps = LessonCurriculum.steps(for: lessons[1], language: .german) // e n
        let e = try #require(steps.first { $0.title == "Neue Taste: e" })
        #expect(e.fingers == [.leftMiddle])
        #expect(e.hint.contains("Mittelfinger links"))
        #expect(e.hint.contains("vom d eine Reihe nach oben"))
        #expect(e.drill.hasPrefix("ddd eee ded ede"))

        let n = try #require(steps.first { $0.title == "Neue Taste: n" })
        #expect(n.fingers == [.rightIndex])
        #expect(n.hint.contains("vom j eine Reihe nach unten"))
    }

    @Test func capitalLettersAreGroupedByHandWithTheOppositeShiftKey() throws {
        let lessons = try ContentStore.practiceLessons(for: .german)
        let steps = LessonCurriculum.steps(for: lessons[5], language: .german) // Großschreibung
        let groups = steps.filter { $0.title.hasPrefix("Großbuchstaben") }
        #expect(groups.count == 2)
        let left = try #require(groups.first { $0.title.contains("linken") })
        #expect(left.hint.contains("Umschalt ⇧ rechts"))
        #expect(left.fingers.contains(.rightPinky))
        #expect(left.drill.contains("aAa"))
    }

    @Test func shiftedSymbolsMentionTheShiftKey() throws {
        let lessons = try ContentStore.practiceLessons(for: .german)
        let steps = LessonCurriculum.steps(for: lessons[6], language: .german) // g G . :
        let symbols = try #require(steps.first { $0.title.hasPrefix("Neue Tasten: .") })
        #expect(symbols.hint.contains("Umschalt"))
        #expect(symbols.drill.contains("l.l"))
        #expect(symbols.fingers.contains(.rightRing))
    }

    @Test func movementHintDescribesSidewaysReach() {
        let layout = KeyboardModel.layout(for: .german)
        #expect(LessonCurriculum.movementHint(for: "g", layout: layout)?.contains("einen Schritt nach rechts") == true)
        #expect(LessonCurriculum.movementHint(for: "t", layout: layout)?.contains("nach oben und") == true)
        #expect(LessonCurriculum.movementHint(for: "f", layout: layout)?.contains("Grundstellungstaste") == true)
    }

    @Test func macGermanLayoutPutsAtSignOnTheLKey() {
        let layout = KeyboardModel.layout(for: .german)
        #expect(layout.stroke(for: "@")?.keyID == "l")
        #expect(layout.stroke(for: "@")?.needsAltGr == true)
        #expect(layout.stroke(for: "€")?.keyID == "e")
        #expect(layout.stroke(for: "{")?.keyID == "8")
    }

    @Test func homeKeysAndRowsAreResolvable() {
        let layout = KeyboardModel.layout(for: .german)
        #expect(layout.homeCharacter(for: .leftIndex) == "f")
        #expect(layout.homeCharacter(for: .rightPinky) == "ö")
        #expect(layout.homeCharacter(for: .thumb) == nil)
        #expect(layout.rowIndex(ofKeyID: "f") == 2)
        #expect(layout.rowIndex(ofKeyID: "r") == 1)
        #expect(layout.rowIndex(ofKeyID: "4") == 0)
    }
}
