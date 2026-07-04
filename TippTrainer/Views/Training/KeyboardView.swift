import SwiftUI

/// Virtuelle Tastatur mit Fingerfarben, Grundstellungsmarkierung,
/// Tastwegen und Hervorhebung der Zieltaste samt Modifikatoren.
struct KeyboardView: View {
    let layout: KeyboardModel
    let currentCharacter: Character?
    let showsBackspaceHint: Bool
    let assistance: AssistanceOptions

    private let keyGap: CGFloat = 5
    private let rowUnits: CGFloat = 15

    var body: some View {
        GeometryReader { geometry in
            let unit = (geometry.size.width - keyGap * (rowUnits - 1))
                / rowUnits
            let keyHeight = unit * 0.94
            let frames = keyFrames(unit: unit, keyHeight: keyHeight)

            ZStack(alignment: .topLeading) {
                ForEach(Array(layout.rows.enumerated()), id: \.offset) { _, row in
                    ForEach(row) { key in
                        if let frame = frames[key.id] {
                            keyCap(for: key)
                                .frame(width: frame.width, height: frame.height)
                                .position(x: frame.midX, y: frame.midY)
                        }
                    }
                }
                if assistance.showHandSeparator {
                    handSeparator(frames: frames, height: geometry.size.height)
                }
                if assistance.showFingerPaths, let path = fingerPath(frames: frames) {
                    path
                        .stroke(
                            Color.accentColor.opacity(0.75),
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [1, 6])
                        )
                }
            }
        }
        .aspectRatio(rowUnits / 5.4, contentMode: .fit)
        .animation(.spring(duration: 0.18), value: currentCharacter)
    }

    // MARK: - Einzelne Taste

    @ViewBuilder
    private func keyCap(for key: KeyboardKey) -> some View {
        let highlight = highlightState(for: key)

        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(fillColor(for: key, highlight: highlight))
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(
                        highlight != .none
                            ? Color.accentColor
                            : Color.primary.opacity(0.09),
                        lineWidth: highlight != .none ? 2.5 : 1
                    )
            )
            .overlay(alignment: .center) {
                VStack(spacing: 0) {
                    if !key.shiftLabel.isEmpty {
                        Text(key.shiftLabel)
                            .font(.system(size: 8, weight: .regular))
                            .foregroundStyle(.secondary)
                    }
                    Text(key.label)
                        .font(.system(
                            size: key.kind == .character ? 12 : 10,
                            weight: highlight != .none ? .bold : .medium
                        ))
                        .foregroundStyle(
                            highlight != .none ? Color.accentColor : .primary
                        )
                }
            }
            .overlay(alignment: .bottom) {
                if key.isHomeKey && assistance.showHomeRow {
                    Capsule()
                        .fill(Color.primary.opacity(0.4))
                        .frame(width: 10, height: 2.5)
                        .padding(.bottom, 3)
                }
            }
            .scaleEffect(highlight == .target ? 1.08 : 1.0)
            .shadow(
                color: highlight == .target
                    ? Color.accentColor.opacity(0.5) : .clear,
                radius: 6
            )
    }

    private enum Highlight { case none, target, modifier }

    private func highlightState(for key: KeyboardKey) -> Highlight {
        guard let character = currentCharacter else { return .none }

        if showsBackspaceHint {
            return key.kind == .backspace ? .target : .none
        }
        if character == DictationToken.newline {
            return key.kind == .enter ? .target : .none
        }
        if character == DictationToken.tab {
            return key.id == "tab" ? .target : .none
        }
        if character == " " {
            return key.kind == .space ? .target : .none
        }
        guard let stroke = layout.stroke(for: character) else { return .none }
        if key.id == stroke.keyID { return .target }
        if stroke.needsShift {
            let side = layout.shiftSide(for: character)
            if key.kind == .shiftLeft && side == .left { return .modifier }
            if key.kind == .shiftRight && side == .right { return .modifier }
        }
        if stroke.needsAltGr && key.kind == .altGr && key.id == "altR" {
            return .modifier
        }
        return .none
    }

    private func fillColor(for key: KeyboardKey, highlight: Highlight) -> Color {
        if highlight == .target { return Color.accentColor.opacity(0.22) }
        if highlight == .modifier { return Color.accentColor.opacity(0.14) }
        guard assistance.coloredKeys, let finger = key.finger else {
            return Color.primary.opacity(0.05)
        }
        return finger.color.opacity(0.16)
    }

    // MARK: - Geometrie

    private func keyFrames(
        unit: CGFloat, keyHeight: CGFloat
    ) -> [String: CGRect] {
        var frames: [String: CGRect] = [:]
        for (rowIndex, row) in layout.rows.enumerated() {
            var x: CGFloat = 0
            let y = CGFloat(rowIndex) * (keyHeight + keyGap)
            for key in row {
                let width = unit * key.width + keyGap * (key.width - 1)
                frames[key.id] = CGRect(x: x, y: y, width: width, height: keyHeight)
                x += width + keyGap
            }
        }
        return frames
    }

    private func handSeparator(
        frames: [String: CGRect], height: CGFloat
    ) -> some View {
        // Trennlinie zwischen linker und rechter Hand: verläuft zwischen
        // 5/6 (obere Reihen) bzw. g/h und b/n.
        let anchors = ["5", "t", "g", "b"]
        var points: [CGPoint] = []
        for id in anchors {
            if let frame = frames[id] {
                points.append(CGPoint(x: frame.maxX + keyGap / 2, y: frame.minY))
                points.append(CGPoint(x: frame.maxX + keyGap / 2, y: frame.maxY))
            }
        }
        return Path { path in
            guard let first = points.first else { return }
            path.move(to: first)
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
        }
        .stroke(Color.primary.opacity(0.22), lineWidth: 1.5)
    }

    private func fingerPath(frames: [String: CGRect]) -> Path? {
        guard let character = currentCharacter, !showsBackspaceHint,
            character != " ",
            character != DictationToken.newline,
            character != DictationToken.tab,
            let stroke = layout.stroke(for: character),
            let finger = layout.finger(for: character),
            let targetFrame = frames[stroke.keyID],
            let homeID = homeKeyID(for: finger),
            homeID != stroke.keyID,
            let homeFrame = frames[homeID]
        else { return nil }

        var path = Path()
        path.move(to: CGPoint(x: homeFrame.midX, y: homeFrame.midY))
        path.addLine(to: CGPoint(x: targetFrame.midX, y: targetFrame.midY))
        return path
    }

    private func homeKeyID(for finger: Finger) -> String? {
        layout.rows
            .flatMap { $0 }
            .first { $0.isHomeKey && $0.finger == finger }?
            .id
    }
}
