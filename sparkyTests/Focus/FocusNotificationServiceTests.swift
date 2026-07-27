import Foundation
import Testing
@testable import sparky

@MainActor
struct FocusNotificationServiceTests {
    @Test func completionRequestsAreSilent() throws {
        let settings = makeSettings(suite: "FocusNotification.silent")
        let service = FocusNotificationService(settings: settings)

        let workRequest = try #require(
            service.makeRequest(for: .focusComplete)
        )
        let breakRequest = try #require(
            service.makeRequest(for: .breakComplete)
        )

        #expect(workRequest.content.title == "Focus complete")
        #expect(workRequest.content.body == "Time for a break.")
        #expect(workRequest.content.sound == nil)
        #expect(breakRequest.content.title == "Break over")
        #expect(breakRequest.content.sound == nil)
    }

    @Test func focusPreferenceGatesOnlyFocusCompletionRequests() {
        let settings = makeSettings(suite: "FocusNotification.gate")
        let service = FocusNotificationService(settings: settings)
        settings.notificationsEnabled = false

        #expect(service.makeRequest(for: .focusComplete) == nil)
        #expect(service.makeRequest(for: .breakComplete) == nil)

        settings.notificationsEnabled = true
        #expect(service.makeRequest(for: .focusComplete) != nil)
        #expect(service.makeRequest(for: .startOrResume) == nil)
        #expect(service.makeRequest(for: .pause) == nil)
        #expect(service.makeRequest(for: .end) == nil)
    }

    private func makeSettings(suite: String) -> FocusSettings {
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return FocusSettings(defaults: defaults)
    }
}
