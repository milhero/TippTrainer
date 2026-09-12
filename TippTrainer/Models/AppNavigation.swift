import Foundation
import Observation

/// Reiter des Einstellungsfensters.
enum SettingsTab: String, CaseIterable, Identifiable {
    case training, assistance, appearance, data

    var id: String { rawValue }

    var title: String {
        switch self {
        case .training: "Training"
        case .assistance: "Hilfen"
        case .appearance: "Darstellung"
        case .data: "Daten"
        }
    }

    var icon: String {
        switch self {
        case .training: "timer"
        case .assistance: "keyboard"
        case .appearance: "paintpalette"
        case .data: "externaldrive"
        }
    }
}

/// App-weiter Navigationszustand: Das Einstellungsfenster wird vom Zahnrad,
/// von den Trainingsoptionen auf der Startseite und vom Menü (⌘,) geöffnet —
/// es gibt nur dieses eine.
@Observable
final class AppNavigation {
    var showsSettings = false
    var settingsTab: SettingsTab = .training

    func showSettings(_ tab: SettingsTab) {
        settingsTab = tab
        showsSettings = true
    }
}
