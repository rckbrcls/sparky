import Testing
@testable import sparky

@Suite("Platform capability matrix")
struct PlatformCapabilitiesTests {
    @Test("iPhone retains phone-only capabilities")
    func iPhoneCapabilities() {
        let capabilities = PlatformCapabilities.iPhone

        #expect(capabilities.supportsTabShell)
        #expect(!capabilities.supportsSidebarShell)
        #expect(capabilities.supportsLocationExecution)
        #expect(capabilities.supportsCameraCapture)
        #expect(capabilities.supportsMicrophoneRecord)
        #expect(capabilities.supportsScheduledNotifications)
        #expect(capabilities.supportsAlternateAppIcon)
    }

    @Test("Mac exposes desktop capabilities without phone-only execution")
    func macCapabilities() {
        let capabilities = PlatformCapabilities.mac

        #expect(!capabilities.supportsTabShell)
        #expect(capabilities.supportsSidebarShell)
        #expect(!capabilities.supportsLocationExecution)
        #expect(!capabilities.supportsCameraCapture)
        #expect(!capabilities.supportsMicrophoneRecord)
        #expect(capabilities.supportsScheduledNotifications)
        #expect(!capabilities.supportsAlternateAppIcon)
        #expect(capabilities.supportsLiveFocusWhileRunning)
        #expect(!capabilities.supportsFocusAfterQuit)
    }
}
