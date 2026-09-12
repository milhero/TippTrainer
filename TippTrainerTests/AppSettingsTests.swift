import Foundation
import Observation
import Testing
@testable import TippTrainer

/// Die Einstellungen müssen beobachtbar sein — sonst reagieren Layoutwahl,
/// Dauer-Auswahl und Schalter erst beim nächsten zufälligen Neuzeichnen —
/// und ihre Werte über Instanzen hinweg behalten.
struct AppSettingsTests {
    private func makeDefaults() -> UserDefaults {
        let suite = "TippTrainerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    private func detection(_ layout: LessonLanguage?, name: String = "Test") -> KeyboardLayoutDetector.Detection {
        KeyboardLayoutDetector.Detection(inputSourceID: "test", localizedName: name, layout: layout)
    }

    @Test func layoutChoiceChangeIsObservable() {
        let settings = AppSettings(defaults: makeDefaults())
        let notified = ObservationFlag()
        withObservationTracking {
            _ = settings.language
        } onChange: {
            notified.raise()
        }
        settings.layoutChoice = .english
        #expect(notified.wasRaised)
        #expect(settings.language == .english)
    }

    @Test func detectedLayoutChangeIsObservable() {
        let settings = AppSettings(defaults: makeDefaults())
        let notified = ObservationFlag()
        withObservationTracking {
            _ = settings.language
        } onChange: {
            notified.raise()
        }
        settings.apply(detection(.english))
        #expect(notified.wasRaised)
        #expect(settings.language == .english)
    }

    @Test func automaticChoiceFollowsTheDetectedKeyboard() {
        let settings = AppSettings(defaults: makeDefaults())
        #expect(settings.layoutChoice == .automatic)
        #expect(settings.language == .german) // ohne Erkennung: Deutsch
        settings.apply(detection(.english, name: "U.S."))
        #expect(settings.language == .english)
        settings.apply(detection(.german, name: "German"))
        #expect(settings.language == .german)
        #expect(settings.layoutWarning == nil)
    }

    @Test func unsupportedKeyboardFallsBackToGermanWithWarning() {
        let settings = AppSettings(defaults: makeDefaults())
        settings.apply(detection(nil, name: "French"))
        #expect(settings.language == .german)
        #expect(settings.layoutWarning?.contains("French") == true)
    }

    @Test func manualChoiceOverridesDetectionAndWarnsOnMismatch() {
        let settings = AppSettings(defaults: makeDefaults())
        settings.apply(detection(.german, name: "German"))
        settings.layoutChoice = .english
        #expect(settings.language == .english)
        #expect(settings.layoutWarning?.contains("Deutsch (QWERTZ)") == true)
        settings.layoutChoice = .german
        #expect(settings.layoutWarning == nil)
    }

    @Test func limitKindChangeIsObservable() {
        let settings = AppSettings(defaults: makeDefaults())
        let notified = ObservationFlag()
        withObservationTracking {
            _ = settings.limitKind
        } onChange: {
            notified.raise()
        }
        settings.limitKind = .entireLesson
        #expect(notified.wasRaised)
    }

    @Test func valuesSurviveANewInstance() {
        let defaults = makeDefaults()
        let settings = AppSettings(defaults: defaults)
        settings.layoutChoice = .english
        settings.limitKind = .characters
        settings.limitCharacters = 800
        settings.blockOnError = false
        settings.guidedSteps = false

        let reloaded = AppSettings(defaults: defaults)
        #expect(reloaded.layoutChoice == .english)
        #expect(reloaded.limitKind == .characters)
        #expect(reloaded.limitCharacters == 800)
        #expect(reloaded.blockOnError == false)
        #expect(reloaded.guidedSteps == false)
    }

    @Test func legacyLessonLanguageKeyIsIgnored() {
        // Der frühere Schlüssel wurde durch den Observation-Fehler still
        // beschrieben; er darf die automatische Erkennung nicht übersteuern.
        let defaults = makeDefaults()
        defaults.set("en", forKey: "lessonLanguage")
        let settings = AppSettings(defaults: defaults)
        #expect(settings.layoutChoice == .automatic)
        #expect(settings.language == .german)
    }

    @Test func defaultsMatchTheClassicTrainer() {
        let settings = AppSettings(defaults: makeDefaults())
        #expect(settings.limitKind == .time)
        #expect(settings.limitMinutes == 5)
        #expect(settings.intelligence)
        #expect(settings.blockOnError)
        #expect(settings.guidedSteps)
    }

    @Test func entireLessonSwitchesIntelligenceOff() {
        let settings = AppSettings(defaults: makeDefaults())
        settings.intelligence = true
        settings.limitKind = .entireLesson
        #expect(settings.configuration().intelligence == false)
        #expect(settings.configuration().limit == .entireLesson)
    }
}

/// Testhilfe: threadsicherer Merker, da `onChange` `@Sendable` ist.
nonisolated final class ObservationFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var raised = false
    func raise() { lock.lock(); raised = true; lock.unlock() }
    var wasRaised: Bool { lock.lock(); defer { lock.unlock() }; return raised }
}
