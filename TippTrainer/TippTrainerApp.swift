import SwiftData
import SwiftUI

@main
struct TippTrainerApp: App {
    @State private var settings = AppSettings()
    @State private var navigation = AppNavigation()

    /// `--memory-store`: flüchtiger Datenspeicher für visuelle Prüfungen,
    /// damit Testläufe die echte Lernstatistik nicht verändern.
    private let container = PersistenceController.makeContainer(
        inMemory: ProcessInfo.processInfo.arguments.contains("--memory-store")
    )

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(settings)
                .environment(navigation)
        }
        .modelContainer(container)
        .commands {
            // Es gibt nur ein Einstellungsfenster; ⌘, öffnet dasselbe wie
            // das Zahnrad und die Trainingsoptionen auf der Startseite.
            CommandGroup(replacing: .appSettings) {
                Button("Einstellungen …") {
                    navigation.showSettings(.training)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}
