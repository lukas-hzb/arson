import Foundation
import Testing
@testable import Arson

@MainActor
struct WindowActionQueueTests {
    @Test func rapidActionsFinishInSubmissionOrder() async {
        let queue = WindowActionQueue()
        var events: [Int] = []
        var backlogStates: [Bool] = []
        var position = 0
        var last: Task<Void, Never>?
        for index in 0..<50 {
            last = queue.enqueue {
                backlogStates.append(queue.hasPendingActions)
                events.append(index * 2)
                let initialPosition = position
                for _ in 0..<5 { await Task.yield() }
                #expect(!Task.isCancelled)
                position = initialPosition + 10
                events.append(index * 2 + 1)
            }
        }
        await last?.value
        #expect(events == Array(0..<100))
        #expect(backlogStates == Array(repeating: true, count: 49) + [false])
        #expect(position == 500)

        await queue.enqueue { position += 10 }.value
        #expect(position == 510)
    }

    @Test func handledFailureDoesNotPreventNextAction() async {
        let queue = WindowActionQueue()
        var events: [String] = []
        queue.enqueue {
            do {
                await Task.yield()
                throw WindowActionError.noFocusedWindow
            } catch {
                events.append("failed")
            }
        }
        await queue.enqueue { events.append("finished") }.value
        #expect(events == ["failed", "finished"])
    }

    @Test func shutdownCancelsActiveAndPendingActions() async {
        let queue = WindowActionQueue()
        var activeStarted = false
        var activeCancelled = false
        var pendingRan = false
        queue.enqueue {
            activeStarted = true
            while !Task.isCancelled { await Task.yield() }
            activeCancelled = true
        }
        let last = queue.enqueue { pendingRan = true }
        while !activeStarted { await Task.yield() }
        queue.cancelAll()
        await last.value
        #expect(activeCancelled)
        #expect(!pendingRan)
    }
}
