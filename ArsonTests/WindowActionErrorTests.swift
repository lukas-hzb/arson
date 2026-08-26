import ApplicationServices
import Testing
@testable import Arson

struct WindowActionErrorTests {
    @Test func fullScreenWindowsDoNotPresentAWarning() {
        #expect(!WindowActionError.fullScreenWindow.presentsHUD)
    }

    @Test func actionableWindowErrorsStillPresentAWarning() {
        #expect(WindowActionError.permissionRequired.presentsHUD)
        #expect(WindowActionError.noFocusedWindow.presentsHUD)
    }
}
