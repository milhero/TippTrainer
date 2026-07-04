import SwiftUI

/// Kompakte Trainingsparameter, direkt vor dem Start erreichbar
/// (Dauer, Fehlerreaktion, Intelligenz, Hilfen).
struct TrainingOptionsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var settings = settings
        VStack(spacing: 0) {
            Form {
                Section("Dauer der Lektion") {
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
                }

                Section("Reaktion auf Tippfehler") {
                    Toggle("Tippfehler blockieren", isOn: $settings.blockOnError)
                    Toggle("Korrektur mit der Rücktaste", isOn: $settings.requireBackspaceCorrection)
                    Toggle("Akustisches Signal", isOn: $settings.beepOnError)
                    Toggle("Intelligenz", isOn: $settings.intelligence)
                        .disabled(settings.limitKind == .entireLesson)
                }

                Section("Hilfen") {
                    Toggle("Tastatur anzeigen", isOn: $settings.showKeyboard)
                    Toggle("Farbige Tasten", isOn: $settings.coloredKeys)
                        .disabled(!settings.showKeyboard)
                    Toggle("Grundstellung markieren", isOn: $settings.showHomeRow)
                        .disabled(!settings.showKeyboard)
                    Toggle("Tastwege zeigen", isOn: $settings.showFingerPaths)
                        .disabled(!settings.showKeyboard)
                    Toggle("Händetrennlinie", isOn: $settings.showHandSeparator)
                        .disabled(!settings.showKeyboard)
                    Toggle("Hilfetext in der Statusleiste", isOn: $settings.showStatusHints)
                }
            }
            .formStyle(.grouped)

            Divider()
            HStack {
                Spacer()
                Button("Fertig") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 460, height: 620)
    }
}
