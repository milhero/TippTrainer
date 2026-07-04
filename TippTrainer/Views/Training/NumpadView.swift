import SwiftUI

/// Ziffernblock für die Lektionen 19 und 20.
struct NumpadView: View {
    let currentCharacter: Character?
    let showsBackspaceHint: Bool
    let assistance: AssistanceOptions

    private struct PadKey: Identifiable {
        let id: String
        let label: String
        let column: Int
        let row: Int
        let width: Int
        let height: Int
        let finger: Finger
        let isHome: Bool

        init(
            _ id: String, _ label: String, col: Int, row: Int,
            width: Int = 1, height: Int = 1, finger: Finger, home: Bool = false
        ) {
            self.id = id
            self.label = label
            self.column = col
            self.row = row
            self.width = width
            self.height = height
            self.finger = finger
            self.isHome = home
        }
    }

    private static let keys: [PadKey] = [
        PadKey("clear", "⌧", col: 0, row: 0, finger: .rightIndex),
        PadKey("=", "=", col: 1, row: 0, finger: .rightMiddle),
        PadKey("/", "/", col: 2, row: 0, finger: .rightRing),
        PadKey("*", "*", col: 3, row: 0, finger: .rightPinky),
        PadKey("7", "7", col: 0, row: 1, finger: .rightIndex),
        PadKey("8", "8", col: 1, row: 1, finger: .rightMiddle),
        PadKey("9", "9", col: 2, row: 1, finger: .rightRing),
        PadKey("-", "-", col: 3, row: 1, finger: .rightPinky),
        PadKey("4", "4", col: 0, row: 2, finger: .rightIndex, home: true),
        PadKey("5", "5", col: 1, row: 2, finger: .rightMiddle, home: true),
        PadKey("6", "6", col: 2, row: 2, finger: .rightRing, home: true),
        PadKey("+", "+", col: 3, row: 2, height: 2, finger: .rightPinky),
        PadKey("1", "1", col: 0, row: 3, finger: .rightIndex),
        PadKey("2", "2", col: 1, row: 3, finger: .rightMiddle),
        PadKey("3", "3", col: 2, row: 3, finger: .rightRing),
        PadKey("0", "0", col: 0, row: 4, width: 2, finger: .thumb),
        PadKey(",", ",", col: 2, row: 4, finger: .rightRing),
        PadKey("enter", "↩", col: 3, row: 4, finger: .rightPinky),
    ]

    var body: some View {
        GeometryReader { geometry in
            let gap: CGFloat = 6
            let unit = (geometry.size.width - gap * 3) / 4
            let keyHeight = (geometry.size.height - gap * 4) / 5

            ZStack(alignment: .topLeading) {
                ForEach(Self.keys) { key in
                    let width = unit * CGFloat(key.width) + gap * CGFloat(key.width - 1)
                    let height = keyHeight * CGFloat(key.height) + gap * CGFloat(key.height - 1)
                    let x = CGFloat(key.column) * (unit + gap)
                    let y = CGFloat(key.row) * (keyHeight + gap)

                    keyCap(for: key)
                        .frame(width: width, height: height)
                        .position(x: x + width / 2, y: y + height / 2)
                }
            }
        }
        .aspectRatio(4 / 5.2, contentMode: .fit)
        .frame(maxWidth: 260)
        .animation(.spring(duration: 0.18), value: currentCharacter)
    }

    private func isTarget(_ key: PadKey) -> Bool {
        if showsBackspaceHint { return key.id == "clear" }
        guard let character = currentCharacter else { return false }
        if character == DictationToken.newline || character == " " {
            return key.id == "enter"
        }
        if character == "." || character == "," {
            return key.id == ","
        }
        return key.id == String(character)
    }

    @ViewBuilder
    private func keyCap(for key: PadKey) -> some View {
        let target = isTarget(key)
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(
                target
                    ? Color.accentColor.opacity(0.22)
                    : assistance.coloredKeys
                        ? key.finger.color.opacity(0.16)
                        : Color.primary.opacity(0.05)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(
                        target ? Color.accentColor : Color.primary.opacity(0.09),
                        lineWidth: target ? 2.5 : 1
                    )
            )
            .overlay(
                Text(key.label)
                    .font(.system(size: 15, weight: target ? .bold : .medium))
                    .foregroundStyle(target ? Color.accentColor : .primary)
            )
            .overlay(alignment: .bottom) {
                if key.isHome && assistance.showHomeRow {
                    Capsule()
                        .fill(Color.primary.opacity(0.4))
                        .frame(width: 10, height: 2.5)
                        .padding(.bottom, 3)
                }
            }
            .scaleEffect(target ? 1.06 : 1.0)
            .shadow(color: target ? Color.accentColor.opacity(0.5) : .clear, radius: 5)
    }
}
