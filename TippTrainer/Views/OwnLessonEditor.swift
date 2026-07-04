import SwiftData
import SwiftUI

/// Editor für eigene Lektionen (Titel, Beschreibung, Diktatzeilen).
struct OwnLessonEditor: View {
    @Bindable var lesson: OwnLesson

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var isNew = false

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Beschreibung") {
                    TextField("Titel", text: $lesson.title)
                    TextField("Kurzbeschreibung", text: $lesson.summary)
                    Picker("Diktatform", selection: $lesson.isSentenceMode) {
                        Text("Satzdiktat").tag(true)
                        Text("Wortdiktat").tag(false)
                    }
                    .pickerStyle(.radioGroup)
                    .horizontalRadioGroupLayout()
                }
                Section("Text") {
                    Text(lesson.isSentenceMode
                        ? "Jede Zeile wird als eigener Satz diktiert."
                        : "Jede Zeile wird als Wortgruppe diktiert.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextEditor(text: $lesson.body)
                        .font(.body.monospaced())
                        .frame(minHeight: 220)
                }
            }
            .formStyle(.grouped)

            Divider()
            HStack {
                Button("Abbrechen", role: .cancel) {
                    if isNew { modelContext.delete(lesson) }
                    dismiss()
                }
                Spacer()
                Button("Speichern") {
                    try? modelContext.save()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(lesson.lines.count < 2)
            }
            .padding()
        }
        .frame(width: 520, height: 560)
        .onAppear {
            // Neue, noch nicht eingefügte Lektionen registrieren.
            if lesson.modelContext == nil {
                modelContext.insert(lesson)
                isNew = true
            }
        }
    }
}
