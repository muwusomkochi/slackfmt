// X6: an accessory app that declares §6's Services item, Copy for Slack, as the app would (V12:
// sandboxed, hardened runtime). The handler only logs the types it was offered; it writes nothing.
import AppKit

final class Provider: NSObject {
    @objc func copyForSlack(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        NSLog("x6 probe: Copy for Slack invoked; types offered: %@", (pboard.types ?? []).map(\.rawValue).joined(separator: ", "))
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let provider = Provider()
app.servicesProvider = provider
NSUpdateDynamicServices()
app.run()
