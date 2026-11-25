import Foundation

/// A one-shot main-queue timer with no coalescing, for V9's holds.
final class ExactTimer {
    private let timer = DispatchSource.makeTimerSource(flags: .strict, queue: .main)

    init(after delay: TimeInterval, _ action: @escaping () -> Void) {
        timer.schedule(deadline: .now() + delay, leeway: .milliseconds(5))
        timer.setEventHandler(handler: action)
        timer.activate()
    }

    deinit {
        timer.cancel()
    }
}
