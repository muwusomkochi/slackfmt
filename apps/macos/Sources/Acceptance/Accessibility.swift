import AppKit
import ApplicationServices

enum AX {
    static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        AXUIElementCopyAttributeValue(element, name as CFString, &value)
        return value
    }

    static func element(_ element: AXUIElement, _ name: String) -> AXUIElement? {
        attribute(element, name).map { $0 as! AXUIElement }
    }

    static func children(_ element: AXUIElement) -> [AXUIElement] {
        attribute(element, "AXChildren") as? [AXUIElement] ?? []
    }

    static func string(_ element: AXUIElement, _ name: String) -> String? {
        attribute(element, name) as? String
    }

    static func frame(_ element: AXUIElement) -> CGRect? {
        guard let position = attribute(element, "AXPosition"), let size = attribute(element, "AXSize") else { return nil }
        var rect = CGRect.zero
        AXValueGetValue(position as! AXValue, .cgPoint, &rect.origin)
        AXValueGetValue(size as! AXValue, .cgSize, &rect.size)
        return rect
    }

    static func press(_ element: AXUIElement) {
        AXUIElementPerformAction(element, kAXPressAction as CFString)
    }
}

/// The app's status item, as the menu bar shows it. A full menu bar holds new items behind macOS's overflow arrow,
/// so the arrow is expanded before the item's frame is read.
enum StatusItem {
    static func element(_ pid: pid_t) -> AXUIElement? {
        AX.element(AXUIElementCreateApplication(pid), "AXExtrasMenuBar").flatMap { AX.children($0).first }
    }

    /// The item's frame, only when the item is really on screen there: a hidden item still reports a stale frame, and a
    /// click on one would land on something else.
    static func frame(_ pid: pid_t) -> CGRect? {
        expandOverflow()
        for _ in 0..<20 {
            if let frame = element(pid).flatMap(AX.frame), frame.width > 0, frame.maxY < 60, isHit(CGPoint(x: frame.midX, y: frame.midY), pid) {
                return frame
            }
            usleep(50_000)
        }
        return nil
    }

    private static func isHit(_ point: CGPoint, _ pid: pid_t) -> Bool {
        var found: AXUIElement?
        AXUIElementCopyElementAtPosition(AXUIElementCreateSystemWide(), Float(point.x), Float(point.y), &found)
        guard let found else { return false }
        var owner: pid_t = 0
        AXUIElementGetPid(found, &owner)
        return owner == pid || AX.string(found, "AXDescription") == "Copy for Slack" || AX.string(found, "AXTitle") == "Copy for Slack"
    }

    private static func expandOverflow() {
        guard let agent = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.MenuBarAgent").first,
              let bar = AX.element(AXUIElementCreateApplication(agent.processIdentifier), "AXExtrasMenuBar"),
              let arrow = AX.children(bar).first(where: { AX.string($0, "AXIdentifier") == "menu-bar-overflow-indicator" }),
              AX.string(arrow, "AXDescription")?.hasPrefix("Show") == true else { return }
        AX.press(arrow)
        usleep(700_000)
    }
}
