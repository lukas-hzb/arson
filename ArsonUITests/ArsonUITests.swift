import XCTest

final class ArsonUITests: XCTestCase {
    @MainActor
    func testOnboardingAndPresetCreation() throws {
        continueAfterFailure = false

        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-reset", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launchEnvironment["ARSON_TEST_STORAGE_DIRECTORY"] = NSTemporaryDirectory()
            + "ArsonUITests-\(UUID().uuidString)"
        app.terminate()
        app.launch()

        XCTAssertTrue(app.staticTexts["Welcome to Arson"].waitForExistence(timeout: 5))
        app.buttons["Later"].click()

        let addButton = app.buttons["Add Preset"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 3))
        addButton.click()

        XCTAssertTrue(app.textFields["presetNameField"].waitForExistence(timeout: 5))
        try app.performAccessibilityAudit { issue in
            // SwiftUI exposes non-interactive layout containers as disabled groups on macOS.
            // They contain described controls but do not represent user-facing elements.
            if issue.auditType == .sufficientElementDescription,
               let element = issue.element,
               (element.elementType == .menuBar || element.elementType == .touchBar ||
                (element.elementType == .group && !element.isEnabled)) {
                return true
            }
            // The system Picker is actionable, but macOS 27 beta reports its native
            // NSPopUpButton bridge as missing an AX action during automated audits.
            if issue.auditType == .action,
               issue.element?.elementType == .popUpButton {
                return true
            }
            // AppKit's native full-screen title-bar button exposes a disabled internal
            // group that macOS 26 reports as a parent/child mismatch.
            if issue.auditType == .parentChild,
               let element = issue.element,
               element.elementType == .group,
               !element.isEnabled {
                return true
            }
            // Selected SwiftUI List rows use a system material that the macOS 27 beta
            // contrast sampler misclassifies even with primary foreground content.
            if issue.auditType == .contrast,
               let elementType = issue.element?.elementType,
               elementType == .cell || elementType == .outlineRow {
                return true
            }
            if let element = issue.element {
                print("Unhandled accessibility audit issue: \(issue.compactDescription)\n\(element.debugDescription)")
            }
            return false
        }
    }
}
