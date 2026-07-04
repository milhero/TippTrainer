import SwiftData
import SwiftUI

/// Das Einstellungsfenster (⌘,) mit den Grundeinstellungen.
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem { Label("Allgemein", systemImage: "gearshape") }
            AssistanceSettingsTab()
                .tabItem { Label("Hilfen", systemImage: "hand.point.up.left") }
            DataSettingsTab()
                .tabItem { Label("Daten", systemImage: "externaldrive") }
        }
        .frame(width: 480, height: 440)
    }
}

private struct GeneralSettingsTab: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section("Sprache & Layout") {
                Picker("Lektionssprache", selection: $settings.language) {
                    Text("Deutsch (QWERTZ)").tag(LessonLanguage.german)
                    Text("English (QWERTY)").tag(LessonLanguage.english)
                }
            }
            Section("Laufschrift") {
                Picker("Geschwindigkeit", selection: $settings.tickerSpeedLevel) {
                    Text("Stillstand (Blocksprung)").tag(0)
                    Text("Langsam").tag(1)
                    Text("Mittel").tag(2)
                    Text("Schnell").tag(3)
                    Text("Sehr schnell").tag(4)
                }
            }
            Section("Extras") {
                Toggle("Rekorde feiern (Konfetti)", isOn: $settings.celebrateRecords)
            }
        }
        .formStyle(.grouped)
    }
}

private struct AssistanceSettingsTab: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section("Standard-Hilfen beim Training") {
                Toggle("Tastatur anzeigen", isOn: $settings.showKeyboard)
                Toggle("Farbige Tasten", isOn: $settings.coloredKeys)
                Toggle("Grundstellung markieren", isOn: $settings.showHomeRow)
                Toggle("Tastwege zeigen", isOn: $settings.showFingerPaths)
                Toggle("Händetrennlinie", isOn: $settings.showHandSeparator)
                Toggle("Hilfetext in der Statusleiste", isOn: $settings.showStatusHints)
            }
        }
        .formStyle(.grouped)
    }
}

private struct DataSettingsTab: View {
    @Environment(\.modelContext) private var modelContext
    @State private var confirmLessons = false
    @State private var confirmChars = false

    var body: some View {
        Form {
            Section("Lernstatistik zurücksetzen") {
                Button("Absolvierte Lektionen löschen", role: .destructive) {
                    confirmLessons = true
                }
                Button("Zeichenstatistik löschen", role: .destructive) {
                    confirmChars = true
                }
            }
            Section {
                Text("Alle Daten werden lokal auf diesem Mac gespeichert.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .confirmationDialog(
            "Alle absolvierten Lektionen löschen?",
            isPresented: $confirmLessons
        ) {
            Button("Löschen", role: .destructive) {
                StatisticsStore(context: modelContext).resetLessons()
            }
        }
        .confirmationDialog(
            "Aufgezeichnete Zeichenstatistik löschen?",
            isPresented: $confirmChars
        ) {
            Button("Löschen", role: .destructive) {
                StatisticsStore(context: modelContext).resetCharacterStats()
            }
        }
    }
}
