import Foundation
import Observation
import Testing
@testable import TippTrainer

/// Die Einstellungen müssen beobachtbar sein — sonst reagieren Sprachwahl,
/// Dauer-Auswahl und Schalter erst beim nächsten zufälligen Neuzeichnen —
/// und ihre Werte über Instanzen hinweg behalten.
struct AppSettingsTests {
    private func makeDefaults() -> UserDefaults {
        let suite = "TippTrainerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test func languageChangeIsObservable() {
        let settings = AppSettings(defaults: makeDefaults())
        let notified = ObservationFlag()
        withObservationTracking {
            _ = settings.language
        } onChange: {
            notified.raise()
        }
        settings.language = .english
        #expect(notified.wasRaised)
        #expect(settings.language == .english)
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
        settings.language = .english
        settings.limitKind = .characters
        settings.limitCharacters = 800
        settings.blockOnError = false
        settings.guidedSteps = false

        let reloaded = AppSettings(defaults: defaults)
        #expect(reloaded.language == .english)
        #expect(reloaded.limitKind == .characters)
        #expect(reloaded.limitCharacters == 800)
        #expect(reloaded.blockOnError == false)
        #expect(reloaded.guidedSteps == false)
    }

    @Test func defaultsMatchTheClassicTrainer() {
        let settings = AppSettings(defaults: makeDefaults())
        #expect(settings.language == .german)
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
