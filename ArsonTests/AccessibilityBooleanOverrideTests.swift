import ApplicationServices
import Testing
@testable import Arson

struct AccessibilityBooleanOverrideTests {
    @Test(arguments: [AXError.success, .notImplemented, .cannotComplete, .failure])
    func restoresOriginalStateEvenWhenTheSetterMutatesAndReportsFailure(_ error: AXError) {
        var targetState = true
        var writes: [Bool] = []
        let override = AccessibilityBooleanOverride(originalValue: targetState, temporaryValue: false) { value in
            targetState = value
            writes.append(value)
            return error
        }
        #expect(!targetState)
        #expect(override.writeError == error)
        override.restore { value in
            targetState = value
            writes.append(value)
            return error
        }
        #expect(targetState)
        #expect(writes == [false, true])
    }

    @Test func doesNotWriteWhenTheOriginalValueIsUnknownOrAlreadyMatches() {
        for original in [nil, false] as [Bool?] {
            var writes = 0
            let override = AccessibilityBooleanOverride(originalValue: original, temporaryValue: false) { _ in
                writes += 1
                return .success
            }
            override.restore { _ in
                writes += 1
                return .success
            }
            #expect(writes == 0)
            #expect(override.writeError == nil)
        }
    }

    @Test func deferredRestorationSurvivesAnOperationFailure() {
        enum Failure: Error { case cancelled }
        var targetState = true
        func operation() throws {
            let override = AccessibilityBooleanOverride(originalValue: targetState, temporaryValue: false) { value in
                targetState = value
                return .notImplemented
            }
            defer {
                override.restore { value in
                    targetState = value
                    return .notImplemented
                }
            }
            throw Failure.cancelled
        }
        #expect(throws: Failure.cancelled) { try operation() }
        #expect(targetState)
    }
}
