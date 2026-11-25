import AppKit
import SlackfmtKit

/// V21's `--specimen`: the app's states in one window, for review beside the mini DS.
final class Specimen: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private let menu = StatusMenu(copy: {}, check: {})

    func applicationDidFinishLaunching(_ notification: Notification) {
        let sections: [(String, NSView)] = [
            ("Status item", row([strip(.aqua), strip(.darkAqua)])),
            ("Done capsule", row([capsule(.aqua), capsule(.darkAqua)])),
            ("Menu", NSButton(title: "Open the menu", target: self, action: #selector(openMenu))),
            ("Nothing converted: tooltip, and VoiceOver after \"\(Strings.nothingConverted)\"", text(Refusal.allCases.map(\.message))),
            ("Check Slack's format", text([FormatCheck.matches, .changed, .absent].map(\.message))),
            ("First run", text([Strings.firstRun])),
        ]
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        for (title, view) in sections {
            let heading = NSTextField(labelWithString: title)
            heading.font = .systemFont(ofSize: 13, weight: .semibold)
            stack.addArrangedSubview(heading)
            stack.addArrangedSubview(view)
            stack.setCustomSpacing(20, after: view)
        }
        window = NSWindow(contentRect: NSRect(origin: .zero, size: stack.fittingSize), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Slackfmt specimen"
        window.contentView = stack
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    @objc private func openMenu(_ sender: NSButton) {
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.maxY), in: sender)
    }

    private func strip(_ appearance: NSAppearance.Name) -> NSView {
        let states: [StatusState] = [.idle, .done, .nothing(.empty)]
        let views = states.map { state -> NSView in
            let view = NSImageView(image: state.image ?? NSImage())
            view.contentTintColor = .labelColor
            return view
        }
        return box(row(views), appearance, height: 24)
    }

    private func capsule(_ appearance: NSAppearance.Name) -> NSView {
        box(CapsuleView(text: Strings.done), appearance, height: 72)
    }

    private func box(_ content: NSView, _ appearance: NSAppearance.Name, height: CGFloat) -> NSView {
        let box = NSBox()
        box.boxType = .custom
        box.borderWidth = 0
        box.fillColor = .windowBackgroundColor
        box.appearance = NSAppearance(named: appearance)
        box.addSubview(content)
        content.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            box.widthAnchor.constraint(equalToConstant: 240),
            box.heightAnchor.constraint(equalToConstant: height),
            content.centerXAnchor.constraint(equalTo: box.centerXAnchor),
            content.centerYAnchor.constraint(equalTo: box.centerYAnchor),
        ])
        return box
    }

    private func row(_ views: [NSView]) -> NSStackView {
        let stack = NSStackView(views: views)
        stack.spacing = 16
        return stack
    }

    private func text(_ lines: [String]) -> NSTextField {
        NSTextField(labelWithString: lines.joined(separator: "\n"))
    }
}
