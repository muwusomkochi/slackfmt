import Foundation

/// A one-shot main-queue timer that App Nap can't stretch: V9's holds are ±0.2 s.
final class ExactTimer {
    private let timer: DispatchSourceTimer
    private let activity: NSObjectProtocol

    init(after delay: TimeInterval, _ action: @escaping () -> Void) {
        activity = ProcessInfo.processInfo.beginActivity(options: .userInitiatedAllowingIdleSystemSleep, reason: "showing a conversion's result")
        timer = DispatchSource.makeTimerSource(flags: .strict, queue: .main)
        timer.schedule(deadline: .now() + delay, leeway: .milliseconds(5))
        timer.setEventHandler(handler: action)
        timer.activate()
    }

    deinit {
        timer.cancel()
        ProcessInfo.processInfo.endActivity(activity)
    }
}
