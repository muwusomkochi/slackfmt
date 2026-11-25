import AppKit
import SlackfmtKit

enum StatusState: Equatable {
    case idle
    case done
    case nothing(Refusal)

    var symbolName: String {
        switch self {
        case .idle: "number"
        case .done: "checkmark"
        case .nothing: "nosign"
        }
    }

    var hold: TimeInterval? {
        switch self {
        case .idle: nil
        case .done: 1.0
        case .nothing: 1.5
        }
    }
}

final class StatusItemController: NSObject {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let onClick: () -> Void
    private var returnToIdle: Timer?

    init(onClick: @escaping () -> Void) {
        self.onClick = onClick
        super.init()
        item.button?.target = self
        item.button?.action = #selector(clicked)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        show(.idle)
    }

    func show(_ state: StatusState) {
        returnToIdle?.invalidate()
        let image = NSImage(systemSymbolName: state.symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 16, weight: .regular))
        image?.isTemplate = true
        item.button?.image = image
        if let hold = state.hold {
            returnToIdle = Timer.scheduledTimer(withTimeInterval: hold, repeats: false) { [weak self] _ in self?.show(.idle) }
        }
    }

    @objc private func clicked() {
        onClick()
    }
}
