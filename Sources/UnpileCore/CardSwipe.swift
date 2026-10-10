import Foundation

/// One physical gesture can propose one decision, only after finger release.
/// This reducer does not read files or perform filesystem operations.
public struct CardSwipe: Sendable {
    public enum Phase: Sendable { case began, changed, ended, cancelled, momentum, unphased }
    public struct Result: Sendable {
        public let consumed: Bool
        public let offset: Double
        public let decision: Decision?
    }
    private enum Axis: Sendable { case pending, horizontal, vertical }
    public private(set) var isTracking = false
    private var axis: Axis = .pending
    private var x = 0.0
    private var y = 0.0

    public init() {}
    public mutating func reset() {
        isTracking = false; axis = .pending; x = 0; y = 0
    }

    /// Normalize to finger movement: positive is right, regardless of Natural Scrolling.
    public static func fingerDelta(_ delta: Double, invertedFromDevice: Bool) -> Double {
        invertedFromDevice ? delta : -delta
    }

    public mutating func handle(phase: Phase, deltaX: Double, deltaY: Double,
                                precise: Bool, invertedFromDevice: Bool, threshold: Double) -> Result {
        if phase == .momentum || phase == .unphased {
            return Result(consumed: false, offset: 0, decision: nil)
        }
        let wasHorizontal = isTracking && axis == .horizontal
        guard precise, deltaX.isFinite, deltaY.isFinite, threshold.isFinite, threshold > 0 else {
            reset(); return Result(consumed: wasHorizontal, offset: 0, decision: nil)
        }
        if phase == .cancelled {
            reset(); return Result(consumed: wasHorizontal, offset: 0, decision: nil)
        }
        if phase == .began { reset(); isTracking = true }
        guard isTracking else { return Result(consumed: false, offset: 0, decision: nil) }
        x += Self.fingerDelta(deltaX, invertedFromDevice: invertedFromDevice)
        y += Self.fingerDelta(deltaY, invertedFromDevice: invertedFromDevice)
        guard x.isFinite, y.isFinite else {
            reset(); return Result(consumed: wasHorizontal, offset: 0, decision: nil)
        }
        if axis == .pending && max(abs(x), abs(y)) >= 8 {
            axis = abs(x) > abs(y) * 1.5 ? .horizontal : .vertical
        }
        let horizontal = axis == .horizontal
        if phase == .ended {
            let decision: Decision? = horizontal && abs(x) >= threshold && abs(x) > abs(y) * 1.35
                ? (x < 0 ? .stage : .keep) : nil
            reset()
            return Result(consumed: horizontal, offset: 0, decision: decision)
        }
        return Result(consumed: horizontal, offset: horizontal ? x : 0, decision: nil)
    }
}
