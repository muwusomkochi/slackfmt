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

    /// AppKit's HTML reader can run the run loop, so a second trigger can arrive while one is being answered.
    private func convert(from source: NSPasteboard) {
        guard !isConverting else { return }
        isConverting = true
        defer { isConverting = false }
        switch service.convert(from: source, to: .general) {
        case .converted:
            statusItem.show(.done)
            capsule.present()
        case .refused(let refusal):
            statusItem.show(.nothing(refusal))
        }
    }
}
