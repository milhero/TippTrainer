import SwiftUI

/// Platzhalter — das Buchstabenregen-Spiel folgt in Phase 8.
struct RainGameView: View {
    var body: some View {
        ContentUnavailableView(
            "Buchstabenregen",
            systemImage: "gamecontroller",
            description: Text("Das Tippspiel kommt bald.")
        )
    }
}
