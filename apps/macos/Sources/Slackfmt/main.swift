import AppKit
import SlackfmtKit

let arguments = CommandLine.arguments

func makeService() -> ConversionService {
    guard let url = Bundle.main.url(forResource: "slackfmt", withExtension: "js"),
          let script = try? String(contentsOf: url, encoding: .utf8),
          let converter = try? Converter(script: script) else { fatalError("the app's bundle has no converter") }
    converter.throwsForTesting = arguments.contains("--test-throw")
    return ConversionService(converter: converter)
}

if arguments.contains("--reset-first-run") {
    FirstRun.reset()
    LoginItem.set(false)
    exit(0)
}

if arguments.contains("--convert-now") {
    switch makeService().convert(from: .general, to: NSPasteboard.general) {
    case .converted: exit(0)
    case .refused(.converterError): exit(1)
    case .refused: exit(2)
    }
}

let delegate: NSApplicationDelegate = arguments.contains("--specimen") ? Specimen() : AppDelegate(service: makeService())
NSApplication.shared.delegate = delegate
NSApplication.shared.setActivationPolicy(.accessory)
NSApplication.shared.run()
