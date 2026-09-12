import SwiftUI

/// Zwei stilisierte Hände (Handfläche und fünf Finger als Pfade). Jeder
/// Finger lässt sich einzeln färben, hervorheben und beschriften — für den
/// Fingerhinweis im Training, die Lernschritte und die Fehlerquote je
/// Finger in der Statistik.
struct HandsView: View {
    /// Füllfarbe je Finger (Daumen gilt für beide Hände).
    var fill: (Finger) -> Color = { _ in Color.primary.opacity(0.08) }
    /// Kräftig hervorgehobene Finger (z. B. der gefragte Finger).
    var highlighted: Set<Finger> = []
    /// Dezent hervorgehobene Finger (z. B. der kleine Finger für Umschalt).
    var secondary: Set<Finger> = []
    /// Beschriftung an der Fingerspitze (z. B. »12 %«).
    var labels: [Finger: String] = [:]

    var body: some View {
        HStack(spacing: 0) {
            SingleHandView(
                isLeft: true, fill: fill, highlighted: highlighted,
                secondary: secondary, labels: labels
            )
            SingleHandView(
                isLeft: false, fill: fill, highlighted: highlighted,
                secondary: secondary, labels: labels
            )
        }
        .aspectRatio(2.15, contentMode: .fit)
    }
}

/// Eine Hand im normierten 100×100-Raster, Handfläche unten, Finger oben.
private struct SingleHandView: View {
    let isLeft: Bool
    let fill: (Finger) -> Color
    let highlighted: Set<Finger>
    let secondary: Set<Finger>
    let labels: [Finger: String]

    private struct FingerShape: Identifiable {
        let finger: Finger
        let centerX: CGFloat
        let top: CGFloat
        let bottom: CGFloat
        var id: Finger { finger }
    }

    private static let fingerWidth: CGFloat = 13.5

    /// Rechte Hand (Daumen links); die linke Hand ist gespiegelt.
    private var fingers: [FingerShape] {
        let right: [FingerShape] = [
            FingerShape(finger: .rightIndex, centerX: 33, top: 16, bottom: 64),
            FingerShape(finger: .rightMiddle, centerX: 48, top: 6, bottom: 64),
            FingerShape(finger: .rightRing, centerX: 63, top: 12, bottom: 64),
            FingerShape(finger: .rightPinky, centerX: 78, top: 28, bottom: 64),
        ]
        guard isLeft else { return right }
        let mirrored: [Finger: Finger] = [
            .rightIndex: .leftIndex, .rightMiddle: .leftMiddle,
            .rightRing: .leftRing, .rightPinky: .leftPinky,
        ]
        return right.map {
            FingerShape(
                finger: mirrored[$0.finger] ?? $0.finger,
                centerX: 100 - $0.centerX, top: $0.top, bottom: $0.bottom
            )
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let scale = min(geometry.size.width, geometry.size.height) / 100
            ZStack(alignment: .topLeading) {
                palmPath(scale: scale)
                    .fill(Color.primary.opacity(0.07))
                palmPath(scale: scale)
                    .stroke(Color.primary.opacity(0.12), lineWidth: 1)

                thumbPath(scale: scale)
                    .fill(fillColor(for: .thumb))
                thumbPath(scale: scale)
                    .stroke(strokeColor(for: .thumb), lineWidth: strokeWidth(for: .thumb))

                ForEach(fingers) { shape in
                    let path = fingerPath(shape, scale: scale)
                    path.fill(fillColor(for: shape.finger))
                    path.stroke(
                        strokeColor(for: shape.finger),
                        lineWidth: strokeWidth(for: shape.finger)
                    )
                    if let label = labels[shape.finger] {
                        Text(label)
                            .font(.system(size: max(8, 7.5 * scale), weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .position(
                                x: shape.centerX * scale,
                                y: (shape.top - 8) * scale
                            )
                    }
                }
                // Der Daumen gilt für beide Hände: eine Beschriftung, mittig
                // zwischen den Händen (an der rechten Hand, linker Rand).
                if !isLeft, let label = labels[.thumb] {
                    Text(label)
                        .font(.system(size: max(8, 7.5 * scale), weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .position(x: 1 * scale, y: 30 * scale)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    // MARK: - Farben

    private func fillColor(for finger: Finger) -> Color {
        if highlighted.contains(finger) { return Color.accentColor.opacity(0.55) }
        if secondary.contains(finger) { return Color.accentColor.opacity(0.25) }
        return fill(finger)
    }

    private func strokeColor(for finger: Finger) -> Color {
        if highlighted.contains(finger) { return Color.accentColor }
        if secondary.contains(finger) { return Color.accentColor.opacity(0.6) }
        return Color.primary.opacity(0.14)
    }

    private func strokeWidth(for finger: Finger) -> CGFloat {
        highlighted.contains(finger) ? 2 : 1
    }

    // MARK: - Pfade

    private func palmPath(scale: CGFloat) -> Path {
        let rect = CGRect(x: 24, y: 54, width: 62, height: 46)
        return Path(
            roundedRect: CGRect(
                x: (isLeft ? 100 - rect.maxX : rect.minX) * scale,
                y: rect.minY * scale,
                width: rect.width * scale,
                height: rect.height * scale
            ),
            cornerRadius: 15 * scale
        )
    }

    private func fingerPath(_ shape: FingerShape, scale: CGFloat) -> Path {
        let width = Self.fingerWidth
        return Path(
            roundedRect: CGRect(
                x: (shape.centerX - width / 2) * scale,
                y: shape.top * scale,
                width: width * scale,
                height: (shape.bottom - shape.top) * scale
            ),
            cornerRadius: width / 2 * scale
        )
    }

    private func thumbPath(scale: CGFloat) -> Path {
        let width = Self.fingerWidth
        let length: CGFloat = 42
        var capsule = Path(
            roundedRect: CGRect(x: -width / 2, y: -length / 2, width: width, height: length),
            cornerRadius: width / 2
        )
        let angle: CGFloat = (isLeft ? 1 : -1) * (.pi / 180) * 36
        let center = CGPoint(x: isLeft ? 82 : 18, y: 58)
        let transform = CGAffineTransform(translationX: center.x, y: center.y)
            .rotated(by: angle)
        capsule = capsule.applying(transform)
        return capsule.applying(CGAffineTransform(scaleX: scale, y: scale))
    }
}
