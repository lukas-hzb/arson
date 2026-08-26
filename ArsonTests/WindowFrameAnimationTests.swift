import CoreGraphics
import Foundation
import Testing
@testable import Arson

struct WindowFrameAnimationTests {
    @Test func easeOutUsesExactEndpointsWithoutOvershooting() {
        #expect(WindowFrameAnimation.easeOut(-1) == 0)
        #expect(WindowFrameAnimation.easeOut(0) == 0)
        #expect(WindowFrameAnimation.easeOut(0.5) == 0.875)
        #expect(WindowFrameAnimation.easeOut(1) == 1)
        #expect(WindowFrameAnimation.easeOut(2) == 1)
    }

    @Test func interpolationMovesAndResizesAsOneFrame() {
        let start = CGRect(x: 100, y: 200, width: 400, height: 300)
        let target = CGRect(x: 300, y: 100, width: 800, height: 600)

        let halfway = WindowFrameAnimation.interpolate(
            from: start,
            to: target,
            progress: 0.5
        )

        #expect(halfway == CGRect(x: 200, y: 150, width: 600, height: 450))
        #expect(WindowFrameAnimation.interpolate(from: start, to: target, progress: 1) == target)
    }

    @Test func constrainedCenteredWindowKeepsTheRequestedCenter() {
        let requested = CGRect(x: 200, y: 100, width: 800, height: 600)
        let accepted = WindowFrameAnimation.frame(
            accepting: CGSize(width: 600, height: 500),
            for: requested,
            positionMode: .center
        )

        #expect(accepted.size == CGSize(width: 600, height: 500))
        #expect(accepted.midX == requested.midX)
        #expect(accepted.midY == requested.midY)
    }

    @Test func keepPositionDoesNotCompensateForConstrainedSize() {
        let requested = CGRect(x: 240, y: 180, width: 800, height: 600)
        let accepted = WindowFrameAnimation.frame(
            accepting: CGSize(width: 600, height: 500),
            for: requested,
            positionMode: .keep
        )

        #expect(accepted.origin == requested.origin)
    }

    @Test func constrainedRightAlignedWindowKeepsTheRequestedRightEdge() {
        let requested = CGRect(x: 640, y: 180, width: 800, height: 600)
        let accepted = WindowFrameAnimation.frame(
            accepting: CGSize(width: 600, height: 500),
            for: requested,
            positionMode: .rightEdge
        )

        #expect(accepted.size == CGSize(width: 600, height: 500))
        #expect(accepted.maxX == requested.maxX)
        #expect(accepted.minY == requested.minY)
    }

    @Test func growthPositionsBeforeResizeButShrinkDoesNot() {
        let current = CGSize(width: 600, height: 500)

        #expect(
            WindowFrameAnimation.shouldPositionBeforeResizing(
                from: current,
                to: CGSize(width: 700, height: 500)
            )
        )
        #expect(
            !WindowFrameAnimation.shouldPositionBeforeResizing(
                from: current,
                to: CGSize(width: 500, height: 400)
            )
        )
    }

    @Test func resizingUsesAThrottledCadenceButAlwaysAppliesTheFinalFrame() {
        let interval = WindowFrameAnimation.resizeUpdateInterval

        #expect(
            WindowFrameAnimation.shouldApplyUpdate(
                at: 1,
                lastStartedAt: nil,
                lastCompletedAt: nil,
                changesSize: true,
                isFinalFrame: false
            )
        )
        #expect(
            !WindowFrameAnimation.shouldApplyUpdate(
                at: 1 + interval / 2,
                lastStartedAt: 1,
                lastCompletedAt: 1,
                changesSize: true,
                isFinalFrame: false
            )
        )
        #expect(
            WindowFrameAnimation.shouldApplyUpdate(
                at: 1 + interval,
                lastStartedAt: 1,
                lastCompletedAt: 1,
                changesSize: true,
                isFinalFrame: false
            )
        )
        #expect(
            WindowFrameAnimation.shouldApplyUpdate(
                at: 1 + interval / 2,
                lastStartedAt: 1,
                lastCompletedAt: 1,
                changesSize: true,
                isFinalFrame: true
            )
        )
    }

    @Test func resizingWaitsForRecoveryAfterASlowSynchronousMutation() {
        let now: TimeInterval = 2

        #expect(
            !WindowFrameAnimation.shouldApplyUpdate(
                at: now,
                lastStartedAt: now - WindowFrameAnimation.resizeUpdateInterval,
                lastCompletedAt: now - WindowFrameAnimation.resizeRecoveryInterval / 2,
                changesSize: true,
                isFinalFrame: false
            )
        )
    }

    @Test func pureMovementKeepsTheDisplayCadence() {
        #expect(
            WindowFrameAnimation.shouldApplyUpdate(
                at: 1.001,
                lastStartedAt: 1,
                lastCompletedAt: 1,
                changesSize: false,
                isFinalFrame: false
            )
        )
    }

}
