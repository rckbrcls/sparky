import Foundation
import Testing
@testable import sparky

@MainActor
struct FocusSettingsFeedbackTests {
    @Test func defaultsUseEnabledGlassAndBell() {
        let settings = makeSettings(suite: "FocusSettingsFeedback.defaults")

        #expect(settings.notificationsEnabled)
        #expect(settings.soundsEnabled)
        #expect(settings.focusCompletionSound == .glass)
        #expect(settings.breakCompletionSound == .bell)
    }

    @Test func feedbackPreferencesPersist() {
        let suite = "FocusSettingsFeedback.persistence"
        let settings = makeSettings(suite: suite)
        settings.notificationsEnabled = false
        settings.soundsEnabled = false
        settings.focusCompletionSound = .ping
        settings.breakCompletionSound = .pop

        let restored = FocusSettings(defaults: UserDefaults(suiteName: suite)!)

        #expect(!restored.notificationsEnabled)
        #expect(!restored.soundsEnabled)
        #expect(restored.focusCompletionSound == .ping)
        #expect(restored.breakCompletionSound == .pop)
    }

    @Test func invalidStoredSoundsFallBackToDefaults() {
        let suite = "FocusSettingsFeedback.invalid"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defaults.set("invalid", forKey: "focus.focusCompletionSound")
        defaults.set("invalid", forKey: "focus.breakCompletionSound")

        let settings = FocusSettings(defaults: defaults)

        #expect(settings.focusCompletionSound == .glass)
        #expect(settings.breakCompletionSound == .bell)
    }

    @Test func resetRestoresAllFeedbackDefaults() {
        let settings = makeSettings(suite: "FocusSettingsFeedback.reset")
        settings.notificationsEnabled = false
        settings.soundsEnabled = false
        settings.focusCompletionSound = .chime
        settings.breakCompletionSound = .ping

        settings.resetToDefaults()

        #expect(settings.notificationsEnabled)
        #expect(settings.soundsEnabled)
        #expect(settings.focusCompletionSound == .glass)
        #expect(settings.breakCompletionSound == .bell)
    }

    private func makeSettings(suite: String) -> FocusSettings {
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return FocusSettings(defaults: defaults)
    }
}
