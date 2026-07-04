import SwiftUI

struct HomeView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "keyboard")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text("TippTrainer")
                .font(.largeTitle.bold())
            Text("Der Zehnfinger-Trainer für den Mac")
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 900, minHeight: 600)
    }
}

#Preview {
    HomeView()
}
