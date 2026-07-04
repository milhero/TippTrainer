import SwiftUI

/// Die Laufschrift: zeigt den Diktattext, hebt das aktuelle Zeichen hervor
/// und scrollt adaptiv mit dem Tipptempo mit (Stufe 0 = Blocksprung).
struct TickerView: View {
    let text: String
    let cursorIndex: Int
    let isError: Bool
    let speedLevel: Int
    let isPausedOverlay: String?

    private static let font = Font.system(size: 26, weight: .medium, design: .monospaced)
    private static let charWidth: CGFloat = {
        let font = NSFont.monospacedSystemFont(ofSize: 26, weight: .medium)
        return ("0" as NSString).size(withAttributes: [.font: font]).width
    }()

    @State private var scrollOffset: CGFloat = 0
    @State private var lastFrameTime: Date?

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let cursorX = CGFloat(cursorIndex) * Self.charWidth

            ZStack(alignment: .leading) {
                if let overlay = isPausedOverlay {
                    Text(overlay)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    TimelineView(.animation) { timeline in
                        styledText
                            .offset(x: 24 - effectiveOffset(
                                cursorX: cursorX,
                                width: width,
                                now: timeline.date
                            ))
                    }
                }
            }
            .frame(maxHeight: .infinity)
        }
        .frame(height: 76)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.background.secondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    isError ? Color.orange.opacity(0.8) : Color.primary.opacity(0.06),
                    lineWidth: isError ? 2 : 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .animation(.easeOut(duration: 0.15), value: isError)
    }

    private var styledText: Text {
        var attributed = AttributedString()

        let characters = Array(text)
        let visibleStart = max(0, cursorIndex - 200)
        let visibleEnd = min(characters.count, cursorIndex + 200)

        if visibleStart > 0 {
            // Platzhalter, damit die x-Positionen stimmen
            var pad = AttributedString(String(repeating: " ", count: visibleStart))
            pad.foregroundColor = .clear
            attributed += pad
        }
        if cursorIndex > visibleStart {
            var typed = AttributedString(
                String(characters[visibleStart..<cursorIndex])
            )
            typed.foregroundColor = .secondary.opacity(0.55)
            attributed += typed
        }
        if cursorIndex < characters.count {
            var current = AttributedString(String(characters[cursorIndex]))
            current.foregroundColor = isError ? .white : .primary
            current.backgroundColor = isError
                ? Color.orange
                : Color.accentColor.opacity(0.25)
            attributed += current
        }
        let upcomingStart = min(cursorIndex + 1, characters.count)
        if upcomingStart < visibleEnd {
            var upcoming = AttributedString(
                String(characters[upcomingStart..<visibleEnd])
            )
            upcoming.foregroundColor = .primary
            attributed += upcoming
        }
        return Text(attributed).font(Self.font)
    }

    private func effectiveOffset(
        cursorX: CGFloat, width: CGFloat, now: Date
    ) -> CGFloat {
        if TickerPacing.isJumpMode(level: speedLevel) {
            // Stehender Text: springt blockweise, sobald der Cursor
            // das letzte Drittel erreicht.
            let usable = width * 0.62
            let block = (cursorX / usable).rounded(.down)
            return block * usable
        }
        // Kontinuierlich: dem Cursor hinterherscrollen; je größer der
        // Rückstand, desto schneller (adaptives Aufholen).
        let target = max(0, cursorX - width * 0.38)
        let gap = target - scrollOffset
        defer { lastFrameTime = now }
        guard let last = lastFrameTime else { return scrollOffset }
        let dt = now.timeIntervalSince(last)
        guard dt > 0, abs(gap) > 0.5 else { return scrollOffset }

        let base = TickerPacing.baseInterval(forLevel: max(1, speedLevel))
        let interval = TickerPacing.interval(base: base, gapToCursor: Int(abs(gap)))
        let pixelsPerSecond = 1000.0 / Double(max(1, interval))
        let step = CGFloat(pixelsPerSecond * dt)

        Task { @MainActor in
            scrollOffset += gap > 0 ? min(step, gap) : max(-step, gap)
        }
        return scrollOffset
    }
}
