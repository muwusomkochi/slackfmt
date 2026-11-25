import AppKit
import Carbon.HIToolbox

func now() -> Double {
    Double(clock_gettime_nsec_np(CLOCK_UPTIME_RAW)) / 1e6
}

enum Input {
    private static let source = CGEventSource(stateID: .hidSystemState)
    /// When the last posted click's down and up had each been handed to the system.
    static var posted: [Double] = []

    static func move(to point: CGPoint) {
        CGEvent(mouseEventSource: source, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
        usleep(60_000)
    }

    /// Posts a click and returns the time just before its mouse-down was posted.
    @discardableResult
    static func click(_ point: CGPoint, button: CGMouseButton = .left, flags: CGEventFlags = []) -> Double {
        let (down, up): (CGEventType, CGEventType) = button == .left ? (.leftMouseDown, .leftMouseUp) : (.rightMouseDown, .rightMouseUp)
        let events = [down, up].map { CGEvent(mouseEventSource: source, mouseType: $0, mouseCursorPosition: point, mouseButton: button) }
        for event in events { event?.flags = flags }
        let start = now()
        posted = events.map { event in
            event?.post(tap: .cghidEventTap)
            return now()
        }
        return start
    }

    @discardableResult
    static func key(_ code: Int, flags: CGEventFlags) -> Double {
        let events = [true, false].map { CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(code), keyDown: $0) }
        for event in events { event?.flags = flags }
        let start = now()
        for event in events { event?.post(tap: .cghidEventTap) }
        return start
    }

    static var pointer: CGPoint { CGEvent(source: nil)?.location ?? .zero }

    /// Seconds since he last touched the mouse or keyboard.
    static var idle: Double {
        [CGEventType.mouseMoved, .leftMouseDown, .keyDown, .scrollWheel]
            .map { CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: $0) }.min() ?? 0
    }
}
