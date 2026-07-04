import Testing
@testable import TippTrainer

struct KeyboardLayoutTests {
    @Test func germanLayoutFindsBasicKeys() {
        let layout = KeyboardModel.layout(for: .german)
        let stroke = layout.stroke(for: "f")
        #expect(stroke?.keyID == "f")
        #expect(stroke?.needsShift == false)
    }

    @Test func uppercaseNeedsShift() {
        let layout = KeyboardModel.layout(for: .german)
        let stroke = layout.stroke(for: "A")
        #expect(stroke?.keyID == "a")
        #expect(stroke?.needsShift == true)
    }

    @Test func germanSpecialCharacters() {
        let layout = KeyboardModel.layout(for: .german)
        #expect(layout.stroke(for: "!")?.keyID == "1")
        #expect(layout.stroke(for: "!")?.needsShift == true)
        #expect(layout.stroke(for: "?")?.keyID == "ß")
        #expect(layout.stroke(for: "@")?.needsAltGr == true)
        #expect(layout.stroke(for: "€")?.keyID == "e")
        #expect(layout.stroke(for: "€")?.needsAltGr == true)
        #expect(layout.stroke(for: ":")?.keyID == ".")
        #expect(layout.stroke(for: ";")?.keyID == ",")
    }

    @Test func germanLayoutHasZAndYSwapped() {
        let layout = KeyboardModel.layout(for: .german)
        // z liegt auf QWERTZ in der oberen Buchstabenreihe
        #expect(layout.finger(for: "z") == .rightIndex)
        #expect(layout.finger(for: "y") == .leftPinky)
    }

    @Test func englishLayoutSpecialCharacters() {
        let layout = KeyboardModel.layout(for: .english)
        #expect(layout.stroke(for: ":")?.keyID == ";")
        #expect(layout.stroke(for: ":")?.needsShift == true)
        #expect(layout.stroke(for: "@")?.keyID == "2")
        #expect(layout.stroke(for: "'")?.keyID == "'")
        #expect(layout.finger(for: "y") == .rightIndex)
        #expect(layout.finger(for: "z") == .leftPinky)
    }

    @Test func fingerAssignmentsFollowTouchTypingStandard() {
        let layout = KeyboardModel.layout(for: .german)
        #expect(layout.finger(for: "a") == .leftPinky)
        #expect(layout.finger(for: "s") == .leftRing)
        #expect(layout.finger(for: "d") == .leftMiddle)
        #expect(layout.finger(for: "f") == .leftIndex)
        #expect(layout.finger(for: "j") == .rightIndex)
        #expect(layout.finger(for: "k") == .rightMiddle)
        #expect(layout.finger(for: "l") == .rightRing)
        #expect(layout.finger(for: "ö") == .rightPinky)
        #expect(layout.finger(for: " ") == .thumb)
    }

    @Test func shiftSideIsOppositeHand() {
        let layout = KeyboardModel.layout(for: .german)
        // 'A' wird links getippt → rechte Umschalttaste
        #expect(layout.shiftSide(for: "A") == .right)
        // 'J' wird rechts getippt → linke Umschalttaste
        #expect(layout.shiftSide(for: "J") == .left)
    }

    @Test func homeKeysAreMarked() {
        let layout = KeyboardModel.layout(for: .german)
        let homeIDs = layout.rows.flatMap { $0 }.filter(\.isHomeKey).map(\.id)
        #expect(Set(homeIDs) == Set(["a", "s", "d", "f", "j", "k", "l", "ö"]))
    }

    @Test func everyLessonCharacterIsTypable() throws {
        for language in LessonLanguage.allCases {
            let layout = KeyboardModel.layout(for: language)
            let lessons = try ContentStore.practiceLessons(for: language)
            for lesson in lessons where lesson.unit != .numpad {
                for segment in lesson.segments {
                    for character in segment where character != " " {
                        #expect(
                            layout.stroke(for: character) != nil,
                            "\(language): »\(character)« aus L\(lesson.number) nicht tippbar"
                        )
                    }
                }
            }
        }
    }
}
