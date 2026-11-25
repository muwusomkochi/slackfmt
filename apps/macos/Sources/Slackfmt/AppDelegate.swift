import AppKit
import SlackfmtKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let service: ConversionService
    private let capsule = CapsulePanel()
    private let notifications = Notifications()
    private var statusItem: StatusItemController!
    private var hotKey: HotKey!
    private var servicesProvider: ServicesProvider!
    private var isConverting = false
    /// App Nap slows a click's answer and stretches V9's holds.
    private let activity = ProcessInfo.processInfo.beginActivity(options: .userInitiatedAllowingIdleSystemSleep, reason: "ready for a click")

    init(service: ConversionService) {
        self.service = service
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let copy = { [unowned self] in convert(from: .general) }
        let menu = StatusMenu(copy: copy, check: { [unowned self] in notifications.postOrAlert(FormatCheck(.general).message) })
        statusItem = StatusItemController(menu: menu, onClick: copy)
        hotKey = HotKey(action: copy)
        servicesProvider = ServicesProvider(convert: { [unowned self] in convert(from: $0) })
        NSApp.servicesProvider = servicesProvider

        if FirstRun.claim() {
            LoginItem.set(true)
            notifications.askThenPost(Strings.firstRun)
        }
        DispatchQueue.main.async { [service] in service.warmUp() }
    }

    /// macOS activates a Services provider when its call returns. The app has nothing to take focus for but R21's alert, so it
    /// hands the focus straight back.
    func applicationDidBecomeActive(_ notification: Notification) {
        if !notifications.isAlerting { NSApp.hide(nil) }
    }

    private func show(_ state: StatusState) {
        statusItem.show(state)
        if state == .done { capsule.present() }
        if let announcement = state.announcement { capsule.announce(announcement) }
    }

    /// AppKit's HTML reader can run the run loop, so a second trigger can arrive while one is being answered.
    private func convert(from source: NSPasteboard) {
        guard !isConverting else { return }
        isConverting = true
        defer { isConverting = false }
        switch service.convert(from: source, to: NSPasteboard.general) {
        case .converted: show(.done)
        case .refused(let refusal): show(.nothing(refusal))
        }
    }
}
