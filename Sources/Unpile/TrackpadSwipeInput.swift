import AppKit
import SwiftUI
import UnpileCore

/// Observes only this application's phased scroll events over the visible card.
/// A transparent background keeps buttons, text selection and mouse drag usable.
struct TrackpadSwipeInput: NSViewRepresentable {
    let enabled: Bool
    let onProgress: (Double) -> Void
    let onFinish: (Decision?) -> Void

    func makeNSView(context: Context) -> SwipeRegion { SwipeRegion() }
    func updateNSView(_ view: SwipeRegion, context: Context) {
        if view.enabled != enabled { view.gesture.reset() }
        view.enabled = enabled
        view.onProgress = onProgress
        view.onFinish = onFinish
    }
    static func dismantleNSView(_ view: SwipeRegion, coordinator: ()) { view.stopObserving() }

    @MainActor final class SwipeRegion: NSView {
        var enabled = false
        var onProgress: (Double) -> Void = { _ in }
        var onFinish: (Decision?) -> Void = { _ in }
        var gesture = CardSwipe()
        private var monitor: Any?
        private var resignation: NSObjectProtocol?
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
        override func viewWillMove(toWindow newWindow: NSWindow?) {
            stopObserving()
            super.viewWillMove(toWindow: newWindow)
        }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                // AppKit invokes local monitors synchronously on its event thread.
                // Return only a Bool across the isolation check, never NSEvent.
                let consumed = MainActor.assumeIsolated { self?.receive(event) == nil && self != nil }
                return consumed ? nil : event
            }
            resignation = NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification,
                object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.gesture.reset()
                    self?.onFinish(nil)
                }
            }
        }
        func stopObserving() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            if let resignation { NotificationCenter.default.removeObserver(resignation) }
            monitor = nil; resignation = nil; gesture.reset()
        }
        private func receive(_ event: NSEvent) -> NSEvent? {
            guard enabled, let window, event.window === window, window.isKeyWindow, NSApp.isActive,
                  window.attachedSheet == nil else { gesture.reset(); return event }
            // Momentum and wheel ticks never begin or complete a file decision.
            guard event.momentumPhase.isEmpty, !event.phase.isEmpty else { return event }
            let phase: CardSwipe.Phase
            if event.phase.contains(.cancelled) { phase = .cancelled }
            else if event.phase.contains(.ended) { phase = .ended }
            else if event.phase.contains(.began) { phase = .began }
            else if event.phase.contains(.changed) { phase = .changed }
            else { return event } // mayBegin is not yet a gesture.
            if phase == .began {
                let point = convert(event.locationInWindow, from: nil)
                guard visibleRect.contains(point) else { gesture.reset(); return event }
            }
            let wasTracking = gesture.isTracking
            let result = gesture.handle(phase: phase, deltaX: event.scrollingDeltaX, deltaY: event.scrollingDeltaY,
                precise: event.hasPreciseScrollingDeltas, invertedFromDevice: event.isDirectionInvertedFromDevice,
                threshold: max(80, min(130, bounds.width * 0.23)))
            if result.consumed { onProgress(result.offset) }
            if wasTracking && (phase == .ended || phase == .cancelled) { onFinish(result.decision) }
            return result.consumed ? nil : event
        }
    }
}
