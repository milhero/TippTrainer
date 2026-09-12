import SwiftData
import SwiftUI

/// Das eine Einstellungsfenster der App (Zahnrad, Trainingsoptionen, ⌘,):
/// Training · Hilfen · Darstellung · Daten.
struct SettingsSheet: View {
    @Environment(AppNavigation.self) private var navigation
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var navigation = navigation
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                Text("Einstellungen")
                    .font(.title2.bold())
                Spacer()
                Picker("", selection: $navigation.settingsTab) {
                    ForEach(SettingsTab.allCases) { tab in
                        Label(tab.title, systemImage: tab.icon).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .labelStyle(.titleAndIcon)
                .labelsHidden()
                .fixedSize()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Divider()

            Group {
                switch navigation.settingsTab {
                case .training: TrainingSettingsTab()
                case .assistance: AssistanceSettingsTab()
                case .appearance: AppearanceSettingsTab()
                case .data: DataSettingsTab()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()
            HStack {
                Text(footnote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Fertig") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(width: 580, height: 640)
    }

    private var footnote: String {
        switch navigation.settingsTab {
        case .training: "Gilt für jedes Training, bis du es änderst."
        case .assistance: "Hilfen erscheinen während des Trainings."
        case .appearance: "Darstellung von Laufschrift und Feiern."
        case .data: "Alle Daten liegen lokal auf diesem Mac."
        }
    }
}

// MARK: - Training

private struct TrainingSettingsTab: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section {
                Picker("Layout", selection: $settings.layoutChoice) {
                    Text("Automatisch erkennen").tag(KeyboardLayoutChoice.automatic)
                    Text(LessonLanguage.german.layoutName).tag(KeyboardLayoutChoice.german)
                    Text(LessonLanguage.english.layoutName).tag(KeyboardLayoutChoice.english)
                }
                LabeledContent("Erkannt", value: settings.detectedLayoutName.isEmpty
                    ? "–"
                    : "\(settings.detectedLayoutName)"
                        + (settings.detectedLayout.map { " → \($0.layoutName)" } ?? " (nicht unterstützt)"))
                if let warning = settings.layoutWarning {
                    Label(warning, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            } header: {
                Text("Tastatur")
            } footer: {
                Text("Die Übungslektionen, die virtuelle Tastatur und die Fingerhinweise richten sich nach dem Layout, das vor dir liegt. Aktiv: \(settings.language.layoutName).")
            }

            Section {
                Picker("Begrenzung", selection: $settings.limitKind) {
                    Text("Zeitlimit").tag(AppSettings.LimitKind.time)
                    Text("Zeichenlimit").tag(AppSettings.LimitKind.characters)
                    Text("Ganze Lektion").tag(AppSettings.LimitKind.entireLesson)
                }
                .pickerStyle(.radioGroup)

                switch settings.limitKind {
                case .time:
                    Stepper(
                        "\(settings.limitMinutes) Minuten",
                        value: $settings.limitMinutes, in: 1...30
                    )
                case .characters:
                    Stepper(
                        "\(settings.limitCharacters) Zeichen",
                        value: $settings.limitCharacters, in: 100...3000, step: 100
                    )
                case .entireLesson:
                    Text("Die Lektion wird einmal von vorn bis hinten diktiert. Die Intelligenz ist dabei ausgeschaltet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Dauer einer Lektion")
            }

            Section("Tippfehler") {
                SettingToggle(
                    "Falsche Taste blockieren",
                    detail: "Es geht erst weiter, wenn die richtige Taste gedrückt wurde.",
                    isOn: $settings.blockOnError
                )
                SettingToggle(
                    "Fehler mit der Rücktaste löschen",
                    detail: "Nach einem Fehler muss zuerst ⌫ gedrückt werden.",
                    isOn: $settings.requireBackspaceCorrection
                )
                SettingToggle(
                    "Warnton bei Fehlern",
                    detail: nil,
                    isOn: $settings.beepOnError
                )
            }

            Section("Lernen") {
                SettingToggle(
                    "Intelligenz",
                    detail: "Wörter mit deinen Fehlerzeichen kommen häufiger dran.",
                    isOn: $settings.intelligence
                )
                .disabled(settings.limitKind == .entireLesson)
                SettingToggle(
                    "Lernschritte",
                    detail: "Jede Übungslektion beginnt mit kurzen, geführten Übungszeilen zu den neuen Tasten.",
                    isOn: $settings.guidedSteps
                )
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Hilfen

private struct AssistanceSettingsTab: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section("Virtuelle Tastatur") {
                Toggle("Tastatur anzeigen", isOn: $settings.showKeyboard)
                Toggle("Farbige Tasten je Finger", isOn: $settings.coloredKeys)
                    .disabled(!settings.showKeyboard)
                Toggle("Grundstellung markieren", isOn: $settings.showHomeRow)
                    .disabled(!settings.showKeyboard)
                Toggle("Tastwege zeigen", isOn: $settings.showFingerPaths)
                    .disabled(!settings.showKeyboard)
                Toggle("Händetrennlinie", isOn: $settings.showHandSeparator)
                    .disabled(!settings.showKeyboard)
            }
            Section("Statusleiste") {
                SettingToggle(
                    "Fingerhinweis",
                    detail: "Zeigt zum aktuellen Zeichen den Finger als Text und auf der Handgrafik.",
                    isOn: $settings.showStatusHints
                )
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Darstellung

private struct AppearanceSettingsTab: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section {
                Picker("Geschwindigkeit", selection: $settings.tickerSpeedLevel) {
                    Text("Stillstand (Blocksprung)").tag(0)
                    Text("Langsam").tag(1)
                    Text("Mittel").tag(2)
                    Text("Schnell").tag(3)
                    Text("Sehr schnell").tag(4)
                }
            } header: {
                Text("Laufschrift")
            } footer: {
                Text("Wie schnell der Diktattext der Schreibposition folgt. Bei Stillstand springt der Text blockweise.")
            }
            Section("Extras") {
                Toggle("Rekorde feiern (Konfetti)", isOn: $settings.celebrateRecords)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Daten

private struct DataSettingsTab: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var records: [LessonRecord]
    @Query private var charRecords: [CharRecord]
    @State private var confirmLessons = false
    @State private var confirmChars = false

    var body: some View {
        Form {
            Section("Lernstatistik") {
                LabeledContent("Absolvierte Lektionen", value: "\(records.count)")
                LabeledContent("Erfasste Zeichen", value: "\(charRecords.count)")
            }
            Section {
                Button("Absolvierte Lektionen löschen …", role: .destructive) {
                    confirmLessons = true
                }
                .disabled(records.isEmpty)
                Button("Zeichenstatistik löschen …", role: .destructive) {
                    confirmChars = true
                }
                .disabled(charRecords.isEmpty)
            } header: {
                Text("Zurücksetzen")
            } footer: {
                Text("Die Zeichenstatistik steuert die Intelligenz. Nach dem Löschen beginnt sie von vorn.")
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

// MARK: - Bausteine

/// Schalter mit optionaler Erklärung in der zweiten Zeile.
private struct SettingToggle: View {
    let title: String
    let detail: String?
    @Binding var isOn: Bool

    init(_ title: String, detail: String?, isOn: Binding<Bool>) {
        self.title = title
        self.detail = detail
        _isOn = isOn
    }

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
