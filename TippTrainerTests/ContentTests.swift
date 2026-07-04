import Foundation
import Testing
@testable import TippTrainer

/// Validiert die gebündelten Lektionsinhalte: Vollständigkeit, Zeichenvorrat
/// und Diktattypen müssen dem Curriculum entsprechen.
struct ContentTests {

    // MARK: - Übungslektionen

    @Test(arguments: [LessonLanguage.german, .english])
    func hasTwentyLessonsNumberedSequentially(language: LessonLanguage) throws {
        let lessons = try ContentStore.practiceLessons(for: language)
        #expect(lessons.count == 20)
        #expect(lessons.map(\.number) == Array(1...20))
    }

    @Test(arguments: [LessonLanguage.german, .english])
    func unitTypesFollowCurriculum(language: LessonLanguage) throws {
        let lessons = try ContentStore.practiceLessons(for: language)
        for lesson in lessons {
            switch lesson.number {
            case 1...6: #expect(lesson.unit == .word, "L\(lesson.number)")
            case 7...18: #expect(lesson.unit == .sentence, "L\(lesson.number)")
            default: #expect(lesson.unit == .numpad, "L\(lesson.number)")
            }
        }
    }

    @Test(arguments: [LessonLanguage.german, .english])
    func segmentsRespectCumulativeCharset(language: LessonLanguage) throws {
        let lessons = try ContentStore.practiceLessons(for: language)
        var cumulative = Set<Character>(" ")
        for lesson in lessons where lesson.number <= 18 {
            cumulative.formUnion(lesson.newCharacters)
            for segment in lesson.segments + [lesson.intro] {
                let illegal = Set(segment).subtracting(cumulative)
                #expect(
                    illegal.isEmpty,
                    "L\(lesson.number) Segment »\(segment)« nutzt unerlaubte Zeichen: \(illegal)"
                )
            }
        }
    }

    @Test(arguments: [LessonLanguage.german, .english])
    func numpadLessonsUseOnlyNumpadCharacters(language: LessonLanguage) throws {
        let lessons = try ContentStore.practiceLessons(for: language)
        var allowed = Set<Character>(" ")
        for lesson in lessons where lesson.unit == .numpad {
            allowed.formUnion(lesson.newCharacters)
            for segment in lesson.segments + [lesson.intro] {
                #expect(Set(segment).isSubset(of: allowed), "L\(lesson.number): »\(segment)«")
            }
        }
    }

    @Test(arguments: [LessonLanguage.german, .english])
    func lessonsProvideEnoughMaterial(language: LessonLanguage) throws {
        let lessons = try ContentStore.practiceLessons(for: language)
        for lesson in lessons {
            #expect(!lesson.title.isEmpty, "L\(lesson.number) ohne Titel")
            switch lesson.unit {
            case .word:
                #expect(lesson.segments.count >= 30, "L\(lesson.number) zu wenig Wörter")
            case .sentence where lesson.number < 18:
                #expect(lesson.segments.count >= 16, "L\(lesson.number) zu wenig Sätze")
            case .sentence:
                // L18 trainiert den Pool aus L7–L17 und hat kein eigenes Material
                #expect(lesson.segments.isEmpty)
            case .numpad:
                #expect(lesson.segments.count >= 16, "L\(lesson.number) zu wenig Zahlenreihen")
            }
            if lesson.number != 18 {
                #expect(!lesson.intro.isEmpty, "L\(lesson.number) ohne Intro-Zeile")
            }
        }
    }

    @Test(arguments: [LessonLanguage.german, .english])
    func sentenceSegmentsAreRealSentences(language: LessonLanguage) throws {
        let lessons = try ContentStore.practiceLessons(for: language)
        for lesson in lessons where lesson.unit == .sentence {
            for segment in lesson.segments {
                #expect(segment.count >= 10, "L\(lesson.number): »\(segment)« zu kurz")
                #expect(segment.count <= 160, "L\(lesson.number): Segment zu lang")
            }
        }
    }

    // MARK: - Freie Lektionen (Diktate)

    @Test func dictationsAreAvailableAndComplete() throws {
        let dictations = try ContentStore.dictations()
        #expect(dictations.count >= 10)
        for dictation in dictations {
            #expect(!dictation.title.isEmpty)
            #expect(!dictation.summary.isEmpty)
            #expect(dictation.segments.count >= 6, "»\(dictation.title)« zu kurz")
        }
        let themes = Set(dictations.map(\.theme))
        #expect(themes.count >= 4, "Zu wenig Themenvielfalt")
    }

    @Test func dictationsAreTypableOnTheirLayout() throws {
        let dictations = try ContentStore.dictations()
        let typable = Set<Character>(
            " abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
            + "äöüÄÖÜß0123456789"
            + ".,;:!?\"'()-_/#$%&*<=>@§€+"
        )
        for dictation in dictations {
            for segment in dictation.segments {
                let illegal = Set(segment).subtracting(typable)
                #expect(
                    illegal.isEmpty,
                    "»\(dictation.title)«: nicht tippbare Zeichen \(illegal)"
                )
            }
        }
    }
}
