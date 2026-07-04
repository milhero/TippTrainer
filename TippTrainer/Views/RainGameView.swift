import SwiftUI

/// Buchstabenregen: fallende Buchstaben abtippen, bevor sie unten
/// ankommen. Level und Tempo steigen mit dem Punktestand.
struct RainGameView: View {
    @Environment(AppSettings.self) private var settings
    @State private var engine = RainGameEngine(pool: Array("asdfjklö"))
    @FocusState private var focused: Bool
    @State private var lastSpawn = Date()

    var body: some View {
        VStack(spacing: 0) {
            scoreBar
            Divider()
            gameField
        }
        .focusable()
        .focused($focused)
        .focusEffectDisabled()
        .onKeyPress(phases: .down) { press in
            guard let character = press.characters.first else { return .ignored }
            if engine.state == .ready || engine.state == .over {
                if character == " " { startGame() }
                return .handled
            }
            engine.type(character)
            return .handled
        }
        .onAppear {
            engine = RainGameEngine(pool: poolForLanguage)
            focused = true
            if ProcessInfo.processInfo.arguments.contains("--game-auto") {
                engine.start()
                for _ in 0..<6 { engine.spawn() }
            }
        }
    }

    private var poolForLanguage: [Character] {
        settings.language == .german
            ? Array("asdfjklöenritghbwzuvpüämocx")
            : Array("asdfjkl;enritghbwuvpyomcx")
    }

    private var scoreBar: some View {
        HStack(spacing: 24) {
            label("Punkte", "\(engine.score)", "star.fill")
            label("Level", "\(engine.level)", "chart.line.uptrend.xyaxis")
            Spacer()
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Image(systemName: index < engine.lives ? "heart.fill" : "heart")
                        .foregroundStyle(index < engine.lives ? .red : .secondary)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private func label(_ title: String, _ value: String, _ icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(.tint)
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .animation(.snappy, value: value)
    }

    private var gameField: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                for drop in engine.drops {
                    let point = CGPoint(x: drop.x * size.width, y: drop.y * size.height)
                    let text = Text(String(drop.character))
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(color(for: drop.y))
                    context.draw(text, at: point)
                }
            }
            .background(fieldBackground)
            .onChange(of: timeline.date) { _, now in
                step(at: now)
            }
            .overlay { overlay }
        }
    }

    private var fieldBackground: some View {
        LinearGradient(
            colors: [Color.accentColor.opacity(0.05), .clear],
            startPoint: .bottom, endPoint: .top
        )
    }

    @ViewBuilder
    private var overlay: some View {
        switch engine.state {
        case .ready:
            gameMessage(
                title: "Buchstabenregen",
                subtitle: "Tippe die fallenden Buchstaben, bevor sie unten ankommen.",
                hint: "Leertaste startet"
            )
        case .over:
            gameMessage(
                title: "Vorbei!",
                subtitle: "Punkte: \(engine.score) · Level \(engine.level)",
                hint: "Leertaste für neue Runde"
            )
        case .running:
            EmptyView()
        }
    }

    private func gameMessage(title: String, subtitle: String, hint: String) -> some View {
        VStack(spacing: 12) {
            Text(title).font(.largeTitle.bold())
            Text(subtitle)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text(hint)
                .font(.callout.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Capsule().fill(.tint.opacity(0.15)))
                .padding(.top, 4)
        }
        .padding(40)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private func color(for y: Double) -> Color {
        y > 0.75 ? .red : y > 0.5 ? .orange : .primary
    }

    private func startGame() {
        engine.start()
        lastSpawn = Date()
    }

    private func step(at now: Date) {
        guard engine.state == .running else { return }
        engine.update(deltaTime: 1.0 / 60.0)
        if now.timeIntervalSince(lastSpawn) >= engine.spawnInterval {
            engine.spawn()
            lastSpawn = now
        }
    }
}
