import Foundation

/// Finger im Zehnfingersystem.
enum Finger: String, Codable, CaseIterable, Sendable {
    case leftPinky, leftRing, leftMiddle, leftIndex
    case thumb
    case rightIndex, rightMiddle, rightRing, rightPinky

    var isLeftHand: Bool {
        switch self {
        case .leftPinky, .leftRing, .leftMiddle, .leftIndex: return true
        default: return false
        }
    }
}

enum ShiftSide: Sendable { case left, right }

/// Ein Tastendruck: Zieltaste plus benötigte Modifikatoren.
struct KeyStroke: Equatable, Sendable {
    let keyID: String
    let needsShift: Bool
    let needsAltGr: Bool
}

/// Eine Taste der virtuellen Tastatur.
struct KeyboardKey: Identifiable, Sendable {
    enum Kind: Sendable {
        case character
        case shiftLeft, shiftRight
        case altGr
        case modifier          // Tab, Caps, Cmd … rein dekorativ
        case backspace
        case enter
        case space
    }

    let id: String
    let label: String
    let shiftLabel: String
    let width: Double
    let finger: Finger?
    let kind: Kind
    let isHomeKey: Bool

    init(
        id: String, label: String, shiftLabel: String = "", width: Double = 1,
        finger: Finger? = nil, kind: Kind = .character, isHomeKey: Bool = false
    ) {
        self.id = id
        self.label = label
        self.shiftLabel = shiftLabel
        self.width = width
        self.finger = finger
        self.kind = kind
        self.isHomeKey = isHomeKey
    }
}

/// Geometrie und Zeichenzuordnung einer physischen Tastatur.
struct KeyboardModel: Sendable {
    let rows: [[KeyboardKey]]
    /// Zeichen → Tastendruck.
    private let strokeMap: [Character: KeyStroke]
    private let fingerByKeyID: [String: Finger]

    func stroke(for character: Character) -> KeyStroke? {
        strokeMap[character]
    }

    func finger(for character: Character) -> Finger? {
        if character == " " { return .thumb }
        guard let stroke = strokeMap[character] else { return nil }
        return fingerByKeyID[stroke.keyID]
    }

    func shiftSide(for character: Character) -> ShiftSide? {
        guard let stroke = strokeMap[character], stroke.needsShift,
            let finger = finger(for: character)
        else { return nil }
        return finger.isLeftHand ? .right : .left
    }

    func key(withID id: String) -> KeyboardKey? {
        rows.flatMap { $0 }.first { $0.id == id }
    }

    /// Fingerzuordnung auf dem Ziffernblock (rechte Hand):
    /// 1/4/7 Zeigefinger, 2/5/8 Mittelfinger, 3/6/9/Komma Ringfinger,
    /// 0 Daumen, Rechenzeichen und Eingabe kleiner Finger.
    static func numpadFinger(for character: Character) -> Finger? {
        switch character {
        case "1", "4", "7": .rightIndex
        case "2", "5", "8": .rightMiddle
        case "3", "6", "9", ",", ".": .rightRing
        case "0": .thumb
        case "+", "-", "*", "/", "=": .rightPinky
        default: nil
        }
    }

    static func layout(for language: LessonLanguage) -> KeyboardModel {
        switch language {
        case .german: return german
        case .english: return english
        }
    }

    // MARK: - Aufbauhilfen

    /// Baut Tastenreihe + Zeichenkarte aus kompakten Beschreibungen:
    /// (Basiszeichen, Shift-Zeichen, AltGr-Zeichen?, Finger).
    private struct CharKey {
        let base: Character
        let shifted: Character?
        let altGr: Character?
        let finger: Finger
        let home: Bool

        init(
            _ base: Character, _ shifted: Character?, _ finger: Finger,
            altGr: Character? = nil, home: Bool = false
        ) {
            self.base = base
            self.shifted = shifted
            self.altGr = altGr
            self.finger = finger
            self.home = home
        }
    }

    private static func build(
        characterRows: [[CharKey]],
        rowPrefixes: [[KeyboardKey]],
        rowSuffixes: [[KeyboardKey]],
        bottomRow: [KeyboardKey],
        uppercase: Bool = true
    ) -> KeyboardModel {
        var strokeMap: [Character: KeyStroke] = [:]
        var fingerMap: [String: Finger] = [:]
        var rows: [[KeyboardKey]] = []

        for (index, charRow) in characterRows.enumerated() {
            var row = rowPrefixes[index]
            for key in charRow {
                let id = String(key.base)
                row.append(
                    KeyboardKey(
                        id: id,
                        label: id.uppercased() == id ? id : id,
                        shiftLabel: key.shifted.map(String.init) ?? "",
                        finger: key.finger,
                        isHomeKey: key.home
                    )
                )
                fingerMap[id] = key.finger
                strokeMap[key.base] = KeyStroke(
                    keyID: id, needsShift: false, needsAltGr: false
                )
                if let shifted = key.shifted {
                    strokeMap[shifted] = KeyStroke(
                        keyID: id, needsShift: true, needsAltGr: false
                    )
                }
                if let altGr = key.altGr {
                    strokeMap[altGr] = KeyStroke(
                        keyID: id, needsShift: false, needsAltGr: true
                    )
                }
                if uppercase, key.base.isLowercase {
                    let uppercased = String(key.base).uppercased()
                    if uppercased.count == 1, let upper = uppercased.first {
                        strokeMap[upper] = KeyStroke(
                            keyID: id, needsShift: true, needsAltGr: false
                        )
                    }
                }
            }
            row.append(contentsOf: rowSuffixes[index])
            rows.append(row)
        }
        rows.append(bottomRow)
        strokeMap[" "] = KeyStroke(keyID: "space", needsShift: false, needsAltGr: false)
        fingerMap["space"] = .thumb
        return KeyboardModel(rows: rows, strokeMap: strokeMap, fingerByKeyID: fingerMap)
    }

    private static let macBottomRow: [KeyboardKey] = [
        KeyboardKey(id: "fn", label: "fn", width: 1.25, kind: .modifier),
        KeyboardKey(id: "ctrl", label: "⌃", width: 1.25, kind: .modifier),
        KeyboardKey(id: "altL", label: "⌥", width: 1.25, kind: .altGr),
        KeyboardKey(id: "cmdL", label: "⌘", width: 1.5, kind: .modifier),
        KeyboardKey(id: "space", label: "", width: 5.5, finger: .thumb, kind: .space),
        KeyboardKey(id: "cmdR", label: "⌘", width: 1.5, kind: .modifier),
        KeyboardKey(id: "altR", label: "⌥", width: 1.25, kind: .altGr),
        KeyboardKey(id: "pad", label: "", width: 1.5, kind: .modifier),
    ]

    // MARK: - Deutschland QWERTZ (ISO)

    static let german: KeyboardModel = build(
        characterRows: [
            [
                CharKey("^", "°", .leftPinky),
                CharKey("1", "!", .leftPinky),
                CharKey("2", "\"", .leftRing, altGr: "²"),
                CharKey("3", "§", .leftMiddle, altGr: "³"),
                CharKey("4", "$", .leftIndex),
                CharKey("5", "%", .leftIndex),
                CharKey("6", "&", .rightIndex),
                CharKey("7", "/", .rightIndex, altGr: "{"),
                CharKey("8", "(", .rightMiddle, altGr: "["),
                CharKey("9", ")", .rightRing, altGr: "]"),
                CharKey("0", "=", .rightPinky, altGr: "}"),
                CharKey("ß", "?", .rightPinky, altGr: "\\"),
                CharKey("´", "`", .rightPinky),
            ],
            [
                CharKey("q", "Q", .leftPinky, altGr: "@"),
                CharKey("w", "W", .leftRing),
                CharKey("e", "E", .leftMiddle, altGr: "€"),
                CharKey("r", "R", .leftIndex),
                CharKey("t", "T", .leftIndex),
                CharKey("z", "Z", .rightIndex),
                CharKey("u", "U", .rightIndex),
                CharKey("i", "I", .rightMiddle),
                CharKey("o", "O", .rightRing),
                CharKey("p", "P", .rightPinky),
                CharKey("ü", "Ü", .rightPinky),
                CharKey("+", "*", .rightPinky, altGr: "~"),
            ],
            [
                CharKey("a", "A", .leftPinky, home: true),
                CharKey("s", "S", .leftRing, home: true),
                CharKey("d", "D", .leftMiddle, home: true),
                CharKey("f", "F", .leftIndex, home: true),
                CharKey("g", "G", .leftIndex),
                CharKey("h", "H", .rightIndex),
                CharKey("j", "J", .rightIndex, home: true),
                CharKey("k", "K", .rightMiddle, home: true),
                CharKey("l", "L", .rightRing, home: true),
                CharKey("ö", "Ö", .rightPinky, home: true),
                CharKey("ä", "Ä", .rightPinky),
                CharKey("#", "'", .rightPinky),
            ],
            [
                CharKey("<", ">", .leftPinky, altGr: "|"),
                CharKey("y", "Y", .leftPinky),
                CharKey("x", "X", .leftRing),
                CharKey("c", "C", .leftMiddle),
                CharKey("v", "V", .leftIndex),
                CharKey("b", "B", .leftIndex),
                CharKey("n", "N", .rightIndex),
                CharKey("m", "M", .rightIndex),
                CharKey(",", ";", .rightMiddle),
                CharKey(".", ":", .rightRing),
                CharKey("-", "_", .rightPinky),
            ],
        ],
        rowPrefixes: [
            [],
            [KeyboardKey(id: "tab", label: "⇥", width: 1.5, kind: .modifier)],
            [KeyboardKey(id: "caps", label: "⇪", width: 1.75, kind: .modifier)],
            [KeyboardKey(id: "shiftL", label: "⇧", width: 1.25, kind: .shiftLeft)],
        ],
        rowSuffixes: [
            [KeyboardKey(id: "backspace", label: "⌫", width: 2, kind: .backspace)],
            [KeyboardKey(id: "enter", label: "↩", width: 1.5, kind: .enter)],
            [KeyboardKey(id: "enter2", label: "↩", width: 1.25, kind: .enter)],
            [KeyboardKey(id: "shiftR", label: "⇧", width: 2.75, kind: .shiftRight)],
        ],
        bottomRow: macBottomRow
    )

    // MARK: - USA QWERTY (ANSI)

    static let english: KeyboardModel = build(
        characterRows: [
            [
                CharKey("`", "~", .leftPinky),
                CharKey("1", "!", .leftPinky),
                CharKey("2", "@", .leftRing),
                CharKey("3", "#", .leftMiddle),
                CharKey("4", "$", .leftIndex),
                CharKey("5", "%", .leftIndex),
                CharKey("6", "^", .rightIndex),
                CharKey("7", "&", .rightIndex),
                CharKey("8", "*", .rightMiddle),
                CharKey("9", "(", .rightRing),
                CharKey("0", ")", .rightPinky),
                CharKey("-", "_", .rightPinky),
                CharKey("=", "+", .rightPinky),
            ],
            [
                CharKey("q", "Q", .leftPinky),
                CharKey("w", "W", .leftRing),
                CharKey("e", "E", .leftMiddle),
                CharKey("r", "R", .leftIndex),
                CharKey("t", "T", .leftIndex),
                CharKey("y", "Y", .rightIndex),
                CharKey("u", "U", .rightIndex),
                CharKey("i", "I", .rightMiddle),
                CharKey("o", "O", .rightRing),
                CharKey("p", "P", .rightPinky),
                CharKey("[", "{", .rightPinky),
                CharKey("]", "}", .rightPinky),
            ],
            [
                CharKey("a", "A", .leftPinky, home: true),
                CharKey("s", "S", .leftRing, home: true),
                CharKey("d", "D", .leftMiddle, home: true),
                CharKey("f", "F", .leftIndex, home: true),
                CharKey("g", "G", .leftIndex),
                CharKey("h", "H", .rightIndex),
                CharKey("j", "J", .rightIndex, home: true),
                CharKey("k", "K", .rightMiddle, home: true),
                CharKey("l", "L", .rightRing, home: true),
                CharKey(";", ":", .rightPinky, home: true),
                CharKey("'", "\"", .rightPinky),
            ],
            [
                CharKey("z", "Z", .leftPinky),
                CharKey("x", "X", .leftRing),
                CharKey("c", "C", .leftMiddle),
                CharKey("v", "V", .leftIndex),
                CharKey("b", "B", .leftIndex),
                CharKey("n", "N", .rightIndex),
                CharKey("m", "M", .rightIndex),
                CharKey(",", "<", .rightMiddle),
                CharKey(".", ">", .rightRing),
                CharKey("/", "?", .rightPinky),
            ],
        ],
        rowPrefixes: [
            [],
            [KeyboardKey(id: "tab", label: "⇥", width: 1.5, kind: .modifier)],
            [KeyboardKey(id: "caps", label: "⇪", width: 1.75, kind: .modifier)],
            [KeyboardKey(id: "shiftL", label: "⇧", width: 2.25, kind: .shiftLeft)],
        ],
        rowSuffixes: [
            [KeyboardKey(id: "backspace", label: "⌫", width: 2, kind: .backspace)],
            [KeyboardKey(id: "\\", label: "\\", width: 1.5, kind: .modifier)],
            [KeyboardKey(id: "enter", label: "↩", width: 2.25, kind: .enter)],
            [KeyboardKey(id: "shiftR", label: "⇧", width: 2.75, kind: .shiftRight)],
        ],
        bottomRow: macBottomRow
    )
}
