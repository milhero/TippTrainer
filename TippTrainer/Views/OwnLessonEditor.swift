import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Editor für eigene Lektionen (Titel, Beschreibung, Diktatzeilen)
/// samt Import aus .txt und Export.
struct OwnLessonEditor: View {
    @Bindable var lesson: OwnLesson

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var isNew = false
    @State private var showsImporter = false
    @State private var showsExporter = false

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
                Section {
                    Text(lesson.isSentenceMode
                        ? "Jede Zeile wird als eigener Satz diktiert."
                        : "Jede Zeile wird als Wortgruppe diktiert.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextEditor(text: $lesson.body)
                        .font(.body.monospaced())
                        .frame(minHeight: 220)
                } header: {
                    HStack {
                        Text("Text")
                        Spacer()
                        Button("Importieren …", systemImage: "square.and.arrow.down") {
                            showsImporter = true
                        }
                        .buttonStyle(.borderless)
                        Button("Exportieren …", systemImage: "square.and.arrow.up") {
                            showsExporter = true
                        }
                        .buttonStyle(.borderless)
                        .disabled(lesson.body.isEmpty)
                    }
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
        .fileImporter(
            isPresented: $showsImporter,
            allowedContentTypes: [.plainText]
        ) { result in
            if case let .success(url) = result {
                importText(from: url)
            }
        }
        .fileExporter(
            isPresented: $showsExporter,
            document: TextDocument(text: lesson.body),
            contentType: .plainText,
            defaultFilename: lesson.title.isEmpty ? "Lektion" : lesson.title
        ) { _ in }
    }

    private func importText(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return }
        lesson.body = text
        if lesson.title.isEmpty {
            lesson.title = url.deletingPathExtension().lastPathComponent
        }
    }
}

/// Schlichtes Textdokument für den Export eigener Lektionen.
struct TextDocument: FileDocument {
    static let readableContentTypes = [UTType.plainText]
    var text: String

    init(text: String) { self.text = text }

    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents {
            text = String(decoding: data, as: UTF8.self)
        } else {
            text = ""
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
