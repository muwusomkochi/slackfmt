import AppKit
import SlackfmtKit

/// The menu on right-click or Option-left-click, in §6's order (R18).
final class StatusMenu: NSMenu, NSMenuDelegate {
    private let copy: () -> Void
    private let check: () -> Void
    private let launchAtLogin = NSMenuItem(title: "Launch at login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")

    init(copy: @escaping () -> Void, check: @escaping () -> Void) {
        self.copy = copy
        self.check = check
        super.init(title: "")
        autoenablesItems = false
        delegate = self

        let hotKey = NSMenuItem(title: "Hotkey", action: nil, keyEquivalent: "v")
        hotKey.keyEquivalentModifierMask = [.control, .option, .command]
        hotKey.isEnabled = false

        items = [
            NSMenuItem(title: Strings.label, action: #selector(copyForSlack), keyEquivalent: ""),
            hotKey,
            .separator(),
            launchAtLogin,
            .separator(),
            NSMenuItem(title: "Check Slack's format", action: #selector(checkFormat), keyEquivalent: ""),
            .separator(),
            NSMenuItem(title: "Quit Slackfmt", action: #selector(quit), keyEquivalent: "q"),
        ]
        for item in items where item.action != nil { item.target = self }
    }

    @available(*, unavailable)
    required init(coder: NSCoder) { fatalError() }

    func menuNeedsUpdate(_ menu: NSMenu) {
        launchAtLogin.state = LoginItem.isOn ? .on : .off
    }

    @objc private func copyForSlack() { copy() }
    @objc private func checkFormat() { check() }
    @objc private func toggleLaunchAtLogin() { LoginItem.set(!LoginItem.isOn) }
    @objc private func quit() { NSApp.terminate(nil) }
}
