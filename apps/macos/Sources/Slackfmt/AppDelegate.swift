import AppKit
import SlackfmtKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: StatusItemController!
    private var service: ConversionService!

    func applicationDidFinishLaunching(_ notification: Notification) {
        service = ConversionService(converter: try! Converter(script: Self.script()))
        statusItem = StatusItemController(onClick: { [unowned self] in convert(from: .general) })
        DispatchQueue.main.async { [service] in service!.warmUp() }
    }

    private func convert(from source: NSPasteboard) {
        switch service.convert(from: source, to: .general) {
        case .converted: statusItem.show(.done)
        case .refused(let refusal): statusItem.show(.nothing(refusal))
        }
    }

    private static func script() -> String {
        let url = Bundle.main.url(forResource: "slackfmt", withExtension: "js")!
        return try! String(contentsOf: url, encoding: .utf8)
    }
}
