import SwiftData
import SwiftUI

@main
struct TippTrainerApp: App {
    @State private var settings = AppSettings()
    private let container = PersistenceController.makeContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(settings)
        }
        .modelContainer(container)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("Über TippTrainer") {}
            }
        }

        Settings {
            SettingsView()
                .environment(settings)
        }
    }
}
