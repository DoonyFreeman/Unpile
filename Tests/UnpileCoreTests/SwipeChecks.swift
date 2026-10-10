import Foundation
import UnpileCore

struct SwipeChecks {
    private static func sample(_ gesture: inout CardSwipe, _ phase: CardSwipe.Phase,
                               _ x: Double = 0, _ y: Double = 0, inverted: Bool = true,
                               precise: Bool = true) -> CardSwipe.Result {
        gesture.handle(phase: phase, deltaX: x, deltaY: y, precise: precise,
            invertedFromDevice: inverted, threshold: 100)
    }
    static func releaseAndDirection() throws {
        for inverted in [true, false] {
            for (movement, decision) in [(140.0, Decision.keep), (-140.0, .stage)] {
                var gesture = CardSwipe()
                let raw = inverted ? movement : -movement
                _ = sample(&gesture, .began)
                let progress = sample(&gesture, .changed, raw, inverted: inverted)
                try expect(progress.consumed && progress.decision == nil, "Decision occurred before release")
                try expect(progress.offset == movement, "Natural Scrolling changed finger direction")
                try expect(sample(&gesture, .ended).decision == decision, "Release selected wrong decision")
            }
        }
    }
    static func scrollingAndIncompleteSequences() throws {
        for (x, y) in [(3.0, 80.0), (80.0, 70.0)] {
            var gesture = CardSwipe()
            _ = sample(&gesture, .began)
            try expect(!sample(&gesture, .changed, x, y).consumed, "Vertical/diagonal scroll was swallowed")
            _ = sample(&gesture, .changed, 200, 0)
            try expect(sample(&gesture, .ended).decision == nil, "Vertical gesture changed axis mid-stream")
        }
        var gesture = CardSwipe()
        try expect(sample(&gesture, .changed, 500).decision == nil && !gesture.isTracking, "Missing begin was accepted")
        try expect(!sample(&gesture, .unphased, 500).consumed, "Wheel tick was consumed")
    }
    static func cancellationAndReversal() throws {
        var gesture = CardSwipe()
        _ = sample(&gesture, .began)
        _ = sample(&gesture, .changed, 180)
        try expect(sample(&gesture, .cancelled).decision == nil, "Cancelled gesture committed")
        _ = sample(&gesture, .began)
        _ = sample(&gesture, .changed, 160)
        _ = sample(&gesture, .changed, -140)
        try expect(sample(&gesture, .ended).decision == nil, "Reversed short gesture committed")
        _ = sample(&gesture, .began)
        _ = sample(&gesture, .changed, 20)
        try expect(sample(&gesture, .ended).decision == nil, "Short gesture committed")
    }
    static func oneDecisionAndMomentum() throws {
        var gesture = CardSwipe()
        _ = sample(&gesture, .began, -130)
        try expect(sample(&gesture, .ended).decision == .stage, "Valid swipe failed")
        for phase in [CardSwipe.Phase.momentum, .changed, .ended] {
            try expect(sample(&gesture, phase, -400).decision == nil, "One gesture decided another card")
        }
        _ = sample(&gesture, .began, 130)
        gesture.reset() // Overlay, focus loss or a different card invalidates a gesture.
        try expect(sample(&gesture, .ended).decision == nil, "Reset gesture committed")
    }
    static func invalidInputNeverCommits() throws {
        var gesture = CardSwipe()
        _ = sample(&gesture, .began, 130)
        try expect(sample(&gesture, .changed, 130, precise: false).decision == nil && !gesture.isTracking, "Coarse device accepted")
        _ = sample(&gesture, .began, 130)
        _ = sample(&gesture, .changed, .infinity)
        try expect(sample(&gesture, .ended).decision == nil, "Non-finite input committed")
    }
}
