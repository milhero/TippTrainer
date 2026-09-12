import Foundation

/// Erzeugt die geführten Lernschritte einer Übungslektion aus ihren neuen
/// Zeichen und dem Tastaturmodell — ein kleines Tutorial am Anfang jeder
/// Lektion: Grundstellung Finger für Finger, je neue Taste eine Übungszeile
/// mit Fingerhinweis, Großbuchstaben und Sonderzeichen gebündelt, zum
/// Schluss die Intro-Zeile der Lektion. Danach übernimmt das freie Üben.
enum LessonCurriculum {
    static func steps(for lesson: PracticeLesson, language: LessonLanguage) -> [LessonStep] {
        let layout = KeyboardModel.layout(for: language)
        switch lesson.unit {
        case .numpad:
            return numpadSteps(for: lesson)
        case .word, .sentence:
            if lesson.number == 1 {
                return homeRowSteps(for: lesson, layout: layout)
            }
            return keySteps(for: lesson, layout: layout)
        }
    }

    // MARK: - Lektion 1: Grundreihe

    private static let leftHand: [Finger] = [.leftPinky, .leftRing, .leftMiddle, .leftIndex]
    private static let rightHand: [Finger] = [.rightIndex, .rightMiddle, .rightRing, .rightPinky]

    private static func homeRowSteps(
        for lesson: PracticeLesson, layout: KeyboardModel
    ) -> [LessonStep] {
        let left = String(leftHand.compactMap { layout.homeCharacter(for: $0) })
        let right = String(rightHand.compactMap { layout.homeCharacter(for: $0) })
        guard left.count == 4, right.count == 4 else { return [] }

        var steps: [LessonStep] = []
        steps.append(LessonStep(
            title: "Grundstellung",
            hint: "Lege die Finger der linken Hand auf \(spaced(left)) und die der "
                + "rechten auf \(spaced(right)). Die Zeigefinger spüren die kleinen "
                + "Erhebungen auf f und j, die Daumen ruhen auf der Leertaste. Am "
                + "Zeilenende drückst du die Eingabetaste ↩ mit dem kleinen Finger rechts.",
            drill: lesson.intro,
            fingers: leftHand + rightHand
        ))

        let pairs: [(Finger, Finger, String)] = [
            (.leftIndex, .rightIndex, "Zeigefinger"),
            (.leftMiddle, .rightMiddle, "Mittelfinger"),
            (.leftRing, .rightRing, "Ringfinger"),
            (.leftPinky, .rightPinky, "Kleine Finger"),
        ]
        for (leftFinger, rightFinger, name) in pairs {
            guard let a = layout.homeCharacter(for: leftFinger),
                let b = layout.homeCharacter(for: rightFinger)
            else { continue }
            steps.append(LessonStep(
                title: "\(name): \(a) und \(b)",
                hint: "Links \(a), rechts \(b) — immer mit demselben Finger. Nach jedem "
                    + "Anschlag bleibt die Hand ruhig in der Grundstellung liegen.",
                drill: pairDrill(a, b),
                fingers: [leftFinger, rightFinger]
            ))
        }

        steps.append(LessonStep(
            title: "Alles zusammen",
            hint: "Die ganze Grundreihe im Wechsel. Tippe gleichmäßig und ohne auf "
                + "die Tastatur zu schauen — das Tempo kommt von allein.",
            drill: "\(left) \(right) \(String(left.reversed())) \(String(right.reversed()))",
            fingers: leftHand + rightHand
        ))
        return steps
    }

    private static func pairDrill(_ a: Character, _ b: Character) -> String {
        "\(a)\(a)\(a) \(b)\(b)\(b) \(a)\(b)\(a) \(b)\(a)\(b) \(a)\(b) \(b)\(a)"
    }

    // MARK: - Übrige Lektionen: neue Tasten

    private static func keySteps(
        for lesson: PracticeLesson, layout: KeyboardModel
    ) -> [LessonStep] {
        let new = Array(lesson.newCharacters)
        var steps: [LessonStep] = []

        for letter in new where letter.isLetter && letter.isLowercase {
            if let step = singleKeyStep(letter, layout: layout) {
                steps.append(step)
            }
        }
        let uppercase = new.filter { $0.isLetter && $0.isUppercase }
        steps += shiftSteps(uppercase, layout: layout)

        let symbols = new.filter { !$0.isLetter }
        for chunk in symbols.chunks(of: 4) {
            if let step = symbolStep(chunk, layout: layout) {
                steps.append(step)
            }
        }

        if !lesson.intro.isEmpty {
            steps.append(LessonStep(
                title: "Alles zusammen",
                hint: "Die neuen Tasten im Zusammenspiel mit den bekannten. "
                    + "Danach geht es mit dem freien Üben weiter.",
                drill: lesson.intro,
                fingers: fingers(in: lesson.intro, layout: layout)
            ))
        }
        return steps
    }

    private static func singleKeyStep(
        _ letter: Character, layout: KeyboardModel
    ) -> LessonStep? {
        guard let finger = layout.finger(for: letter),
            let home = layout.homeCharacter(for: finger),
            let hint = movementHint(for: letter, layout: layout)
        else { return nil }
        let h = home, x = letter
        return LessonStep(
            title: "Neue Taste: \(letter)",
            hint: hint,
            drill: "\(h)\(h)\(h) \(x)\(x)\(x) \(h)\(x)\(h) \(x)\(h)\(x) \(h)\(x)\(x) \(x)\(x)\(h)",
            fingers: [finger]
        )
    }

    /// Großbuchstaben, nach Hand gruppiert: Die Umschalttaste drückt immer
    /// der kleine Finger der jeweils anderen Hand.
    private static func shiftSteps(
        _ letters: [Character], layout: KeyboardModel
    ) -> [LessonStep] {
        guard !letters.isEmpty else { return [] }
        let groups: [(letters: [Character], shiftSide: String, hand: String, shiftFinger: Finger)] = [
            (letters.filter { layout.finger(for: $0)?.isLeftHand == true }, "rechts", "linken", .rightPinky),
            (letters.filter { layout.finger(for: $0)?.isLeftHand == false }, "links", "rechten", .leftPinky),
        ]
        return groups.compactMap { group in
            guard !group.letters.isEmpty else { return nil }
            let sample = group.letters.prefix(8)
            let drill = sample.map { upper -> String in
                let lower = String(upper).lowercased()
                return "\(lower)\(upper)\(lower)"
            }.joined(separator: " ")
            let title = group.letters.count == 1
                ? "Großes \(group.letters[0])"
                : "Großbuchstaben der \(group.hand) Hand"
            var fingers = uniqueFingers(sample.compactMap { layout.finger(for: $0) })
            fingers.append(group.shiftFinger)
            return LessonStep(
                title: title,
                hint: "Für Buchstaben der \(group.hand) Hand hältst du Umschalt ⇧ \(group.shiftSide) "
                    + "mit dem kleinen Finger der anderen Hand gedrückt, tippst den Buchstaben "
                    + "und lässt dann beide Tasten los.",
                drill: drill,
                fingers: fingers
            )
        }
    }

    private static func symbolStep(
        _ symbols: [Character], layout: KeyboardModel
    ) -> LessonStep? {
        var drills: [String] = []
        var hints: [String] = []
        var fingers: [Finger] = []
        for symbol in symbols {
            guard let finger = layout.finger(for: symbol),
                let home = layout.homeCharacter(for: finger),
                let hint = movementHint(for: symbol, layout: layout)
            else { continue }
            drills.append("\(home)\(symbol)\(home) \(symbol)\(home)\(symbol)")
            hints.append("\(symbol)  \(hint)")
            fingers.append(finger)
            if let side = layout.shiftSide(for: symbol) {
                fingers.append(side == .left ? .leftPinky : .rightPinky)
            }
        }
        guard !drills.isEmpty else { return nil }
        let names = symbols.map(String.init).joined(separator: " ")
        return LessonStep(
            title: symbols.count == 1 ? "Neue Taste: \(names)" : "Neue Tasten: \(names)",
            hint: hints.joined(separator: "\n"),
            drill: drills.joined(separator: " "),
            fingers: uniqueFingers(fingers)
        )
    }

    /// »Mittelfinger links: vom d eine Reihe nach oben. Dazu Umschalt rechts …«
    static func movementHint(for character: Character, layout: KeyboardModel) -> String? {
        guard let stroke = layout.stroke(for: character),
            let finger = layout.finger(for: character),
            let homeKey = layout.homeKey(for: finger),
            let homeRow = layout.rowIndex(ofKeyID: homeKey.id),
            let targetRow = layout.rowIndex(ofKeyID: stroke.keyID),
            let homeX = layout.keyCenterX(ofKeyID: homeKey.id),
            let targetX = layout.keyCenterX(ofKeyID: stroke.keyID)
        else { return nil }

        var hint = "\(finger.germanName): "
        if stroke.keyID == homeKey.id {
            hint += "die Grundstellungstaste \(homeKey.id) selbst"
        } else {
            let dx = targetX - homeX
            let sideways = dx > 0 ? "rechts" : "links"
            switch targetRow - homeRow {
            case ..<(-1):
                hint += "vom \(homeKey.id) zwei Reihen hinauf in die Zahlenreihe"
            case -1:
                hint += "vom \(homeKey.id) eine Reihe nach oben"
            case 0:
                hint += abs(dx) >= 1.9
                    ? "vom \(homeKey.id) zwei Schritte nach \(sideways)"
                    : "vom \(homeKey.id) einen Schritt nach \(sideways)"
            default:
                hint += "vom \(homeKey.id) eine Reihe nach unten"
            }
            if targetRow != homeRow, abs(dx) >= 0.4 {
                hint += abs(dx) >= 0.9 ? " und nach \(sideways)" : " und etwas nach \(sideways)"
            }
        }
        hint += "."
        if stroke.needsShift, let side = layout.shiftSide(for: character) {
            hint += " Dazu Umschalt ⇧ \(side == .left ? "links" : "rechts") "
                + "mit dem kleinen Finger der anderen Hand."
        }
        if stroke.needsAltGr {
            hint += " Dazu die Wahltaste ⌥."
        }
        return hint
    }

    // MARK: - Ziffernblock

    private static func numpadSteps(for lesson: PracticeLesson) -> [LessonStep] {
        let digits = Set("0123456789")
        if lesson.newCharacters.allSatisfy(digits.contains) {
            return [
                LessonStep(
                    title: "Grundstellung 4 5 6",
                    hint: "Rechte Hand auf den Ziffernblock: Zeigefinger auf 4, Mittelfinger "
                        + "auf 5 (spürbare Erhebung), Ringfinger auf 6. Der Daumen liegt an "
                        + "der 0, der kleine Finger an der Eingabetaste.",
                    drill: "456 456 654 654 465 564",
                    fingers: [.rightIndex, .rightMiddle, .rightRing]
                ),
                LessonStep(
                    title: "Obere Reihe 7 8 9",
                    hint: "Jeder Finger streckt sich eine Reihe nach oben und kehrt "
                        + "danach auf seine Grundtaste zurück.",
                    drill: "474 585 696 789 987 748",
                    fingers: [.rightIndex, .rightMiddle, .rightRing]
                ),
                LessonStep(
                    title: "Untere Reihe 1 2 3",
                    hint: "Dieselben Finger eine Reihe nach unten: 1 Zeigefinger, "
                        + "2 Mittelfinger, 3 Ringfinger.",
                    drill: "414 525 636 123 321 142",
                    fingers: [.rightIndex, .rightMiddle, .rightRing]
                ),
                LessonStep(
                    title: "Die 0 mit dem Daumen",
                    hint: "Die breite 0 tippt der Daumen — die Finger bleiben auf 4 5 6.",
                    drill: "404 505 606 100 200 300",
                    fingers: [.thumb]
                ),
            ]
        }
        return [
            LessonStep(
                title: "Rechenzeichen",
                hint: "Der kleine Finger übernimmt die Spalte rechts außen: "
                    + "+ und − untereinander, darüber * und /.",
                drill: "4+4 5-5 6*6 4/4 5+6 6-4",
                fingers: [.rightPinky, .rightIndex, .rightMiddle, .rightRing]
            ),
            LessonStep(
                title: "Das Komma",
                hint: "Das Komma liegt unter der 3 und gehört dem Ringfinger.",
                drill: "3,3 6,6 1,5 2,5 0,5 4,4",
                fingers: [.rightRing, .thumb]
            ),
        ]
    }

    // MARK: - Hilfen

    private static func spaced(_ text: String) -> String {
        text.map(String.init).joined(separator: " ")
    }

    private static func fingers(in text: String, layout: KeyboardModel) -> [Finger] {
        uniqueFingers(text.compactMap { layout.finger(for: $0) })
    }

    private static func uniqueFingers(_ fingers: [Finger]) -> [Finger] {
        var seen: Set<Finger> = []
        return fingers.filter { seen.insert($0).inserted }
    }
}

private extension Array {
    func chunks(of size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map { Array(self[$0..<Swift.min($0 + size, count)]) }
    }
}
