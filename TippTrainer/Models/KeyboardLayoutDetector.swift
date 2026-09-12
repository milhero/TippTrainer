import Carbon
import Foundation

/// Erkennt das aktive Tastaturlayout des Systems (Text Input Source) und
/// ordnet es einem der unterstützten Layouts zu: Deutsch (QWERTZ) oder
/// US-Englisch (QWERTY). Andere Layouts (AZERTY, Dvorak …) gelten als nicht
/// unterstützt; die App fällt dann auf Deutsch zurück und weist darauf hin.
enum KeyboardLayoutDetector {
    struct Detection: Equatable, Sendable {
        /// Kennung der Eingabequelle, z. B. `com.apple.keylayout.German`.
        let inputSourceID: String
        /// Anzeigename des Systems, z. B. »German«.
        let localizedName: String
        /// Zugeordnetes Layout, `nil` wenn nicht unterstützt.
        let layout: LessonLanguage?
    }

    /// Das aktuell im System gewählte Tastaturlayout.
    static func current() -> Detection {
        let source = TISCopyCurrentKeyboardLayoutInputSource().takeRetainedValue()
        let id = property(kTISPropertyInputSourceID, of: source) ?? ""
        let name = property(kTISPropertyLocalizedName, of: source) ?? id
        return Detection(
            inputSourceID: id,
            localizedName: name,
            layout: layout(forInputSourceID: id)
        )
    }

    /// Zuordnung einer Eingabequellen-Kennung zu einem unterstützten Layout.
    static func layout(forInputSourceID id: String) -> LessonLanguage? {
        let name = id
            .replacingOccurrences(of: "com.apple.keylayout.", with: "")
            .lowercased()
        if name.contains("qwertz") || qwertzLayouts.contains(name) {
            return .german
        }
        if name.contains("qwerty") || qwertyLayouts.contains(name) {
            return .english
        }
        return nil
    }

    private static let qwertzLayouts: Set<String> = [
        "german", "german-din-2137", "austrian", "swissgerman",
    ]

    private static let qwertyLayouts: Set<String> = [
        "us", "abc", "usextended", "usinternational-pc", "british", "british-pc",
        "canadian", "australian", "irish", "abc-india",
    ]

    /// Systemweite Benachrichtigung bei Wechsel des Tastaturlayouts.
    static let changeNotification = Notification.Name(
        "com.apple.Carbon.TISNotifySelectedKeyboardInputSourceChanged"
    )

    private static func property(_ key: CFString, of source: TISInputSource) -> String? {
        guard let pointer = TISGetInputSourceProperty(source, key) else { return nil }
        return Unmanaged<CFString>.fromOpaque(pointer).takeUnretainedValue() as String
    }
}
