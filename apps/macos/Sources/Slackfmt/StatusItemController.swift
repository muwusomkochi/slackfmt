import AppKit
import SlackfmtKit

enum StatusState: Equatable {
    case idle
    case done
    case nothing(Refusal)

    var image: NSImage? {
        let name = switch self {
        case .idle: "number"
        case .done: "checkmark"
        case .nothing: "nosign"
        }
        let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 16, weight: .regular))
        guard let symbol else { return nil }
        let canvas = NSSize(width: 18, height: 18)
        let image = NSImage(size: canvas, flipped: false) { rect in
            let fit = min(1, canvas.width / symbol.size.width, canvas.height / symbol.size.height)
            let size = NSSize(width: symbol.size.width * fit, height: symbol.size.height * fit)
            symbol.draw(in: NSRect(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2, width: size.width, height: size.height))
            return true
        }
        image.isTemplate = true
        return image
    }

    var hold: TimeInterval? {
        switch self {
        case .idle: nil
        case .done: 1.0
        case .nothing: 1.5
        }
    }

    var toolTip: String? {
        if case .nothing(let refusal) = self { return refusal.message }
        return nil
    }

    var announcement: String? {
        switch self {
        case .idle: nil
        case .done: Strings.done
        case .nothing(let refusal): Strings.nothingConverted + refusal.message
        }
    }

    var logLine: String {
        switch self {
        case .idle: "status idle"
        case .done: "status done"
        case .nothing(let refusal): "status nothing \(refusal.message)"
        }
    }
}

final class StatusItemController: NSObject {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu: NSMenu
    private let onClick: () -> Void
    private var returnToIdle: ExactTimer?

    init(menu: NSMenu, onClick: @escaping () -> Void) {
        self.menu = menu
        self.onClick = onClick
        super.init()
        item.button?.target = self
        item.button?.action = #selector(clicked)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        item.button?.setAccessibilityLabel(Strings.label)
        show(.idle)
    }

    func show(_ state: StatusState) {
        returnToIdle = nil
        item.button?.image = state.image
        item.button?.toolTip = state.toolTip
        StateLog.write(state.logLine)
        if let announcement = state.announcement { announce(announcement) }
        if let hold = state.hold {
            returnToIdle = ExactTimer(after: hold) { [weak self] in self?.show(.idle) }
        }
    }

    private func announce(_ message: String) {
        NSAccessibility.post(element: NSApp as Any, notification: .announcementRequested, userInfo: [
            .announcement: message,
            .priority: NSAccessibilityPriorityLevel.high.rawValue,
        ])
    }

    /// A press by VoiceOver arrives with no mouse event of its own, and with VoiceOver's keys held (Option among them), so the
    /// keys count only for a click. macOS 27 hands a status item its click without modifier flags, so the live ones are read.
    @objc private func clicked() {
        let click = NSApp.currentEvent.flatMap { event in
            [.leftMouseUp, .rightMouseUp].contains(event.type) && ProcessInfo.processInfo.systemUptime - event.timestamp < 1 ? event : nil
        }
        let opens = click.map { $0.type == .rightMouseUp || NSEvent.modifierFlags.union($0.modifierFlags).contains(.option) } ?? false
        opens ? openMenu() : onClick()
    }

    /// The menu is attached only while it's open, so a plain click converts.
    private func openMenu() {
        item.menu = menu
        item.button?.performClick(nil)
        item.menu = nil
    }
}
