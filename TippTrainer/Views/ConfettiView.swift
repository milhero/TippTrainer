import SwiftUI

/// Dezenter Konfetti-Regen zur Feier eines persönlichen Rekords.
struct ConfettiView: View {
    private struct Piece: Identifiable {
        let id = UUID()
        let x: CGFloat
        let delay: Double
        let hue: Double
        let size: CGFloat
        let spin: Double
    }

    private let pieces: [Piece] = (0..<80).map { _ in
        Piece(
            x: .random(in: 0...1),
            delay: .random(in: 0...0.6),
            hue: .random(in: 0...1),
            size: .random(in: 6...12),
            spin: .random(in: -360...360)
        )
    }

    @State private var animate = false

    var body: some View {
        GeometryReader { geometry in
            ForEach(pieces) { piece in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(hue: piece.hue, saturation: 0.7, brightness: 0.95))
                    .frame(width: piece.size, height: piece.size * 0.6)
                    .rotationEffect(.degrees(animate ? piece.spin : 0))
                    .position(
                        x: piece.x * geometry.size.width,
                        y: animate ? geometry.size.height + 40 : -40
                    )
                    .opacity(animate ? 0 : 1)
                    .animation(
                        .easeIn(duration: 1.8).delay(piece.delay),
                        value: animate
                    )
            }
        }
        .onAppear { animate = true }
    }
}
