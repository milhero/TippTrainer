import Foundation
import Testing
@testable import TippTrainer

/// Die App muss wissen, welche Tastatur vor dem Nutzer liegt: Übungen,
/// virtuelle Tastatur und Fingerhinweise richten sich danach.
struct KeyboardLayoutDetectorTests {
    @Test(arguments: [
        "com.apple.keylayout.German",
        "com.apple.keylayout.German-DIN-2137",
        "com.apple.keylayout.Austrian",
        "com.apple.keylayout.SwissGerman",
        "com.apple.keylayout.ABC-QWERTZ",
    ])
    func germanFamilyIsQwertz(id: String) {
        #expect(KeyboardLayoutDetector.layout(forInputSourceID: id) == .german)
    }

    @Test(arguments: [
        "com.apple.keylayout.US",
        "com.apple.keylayout.ABC",
        "com.apple.keylayout.USInternational-PC",
        "com.apple.keylayout.British",
        "com.apple.keylayout.Canadian",
        "com.apple.keylayout.ABC-QWERTY",
    ])
    func englishFamilyIsQwerty(id: String) {
        #expect(KeyboardLayoutDetector.layout(forInputSourceID: id) == .english)
    }

    @Test(arguments: [
        "com.apple.keylayout.French",
        "com.apple.keylayout.ABC-AZERTY",
        "com.apple.keylayout.Dvorak",
        "com.apple.keylayout.Colemak",
        "",
    ])
    func unsupportedLayoutsAreNil(id: String) {
        #expect(KeyboardLayoutDetector.layout(forInputSourceID: id) == nil)
    }

    @Test func currentSystemLayoutIsReadable() {
        let detection = KeyboardLayoutDetector.current()
        #expect(!detection.inputSourceID.isEmpty)
        #expect(!detection.localizedName.isEmpty)
    }
}
