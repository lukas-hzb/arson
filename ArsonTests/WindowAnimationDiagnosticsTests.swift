import Testing
@testable import Arson

struct WindowAnimationDiagnosticsTests {
    @Test func measurementRunsTheOperationExactlyOnceAndReturnsItsResult() {
        var calls = 0
        let result = WindowAnimationDiagnostics.measureAX("TestAXCall") {
            calls += 1
            return 42
        }
        #expect(calls == 1)
        #expect(result == 42)
    }

    @Test func measurementPreservesTheOriginalErrorWithoutRetrying() {
        enum Failure: Error { case expected }
        var calls = 0
        #expect(throws: Failure.expected) {
            try WindowAnimationDiagnostics.measureAX("TestAXFailure") {
                calls += 1
                throw Failure.expected
            }
        }
        #expect(calls == 1)
    }
}
