import AppKit
import Carbon.HIToolbox

/// Where the status item was when it was last found, so nothing asks the app for it while a click is being timed.
var lastFrame: CGRect?

enum Trigger: String {
    case click, hotkey

    /// Fires the trigger and returns the time just before its event was posted.
    func fire(_ app: App) -> Double? {
        switch self {
        case .hotkey:
            lastFrame = StatusItem.frame(app.pid)
            return Input.key(kVK_ANSI_V, flags: [.maskControl, .maskAlternate, .maskCommand])
        case .click:
            guard let frame = StatusItem.frame(app.pid) else {
                print("the status item isn't on screen, so nothing was clicked")
                return nil
            }
            lastFrame = frame
            let point = CGPoint(x: frame.midX, y: frame.midY)
            Input.move(to: point)
            return Input.click(point)
        }
    }
}

enum Fixtures {
    static let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Tests/fixtures")

    static func text(_ name: String) -> String { try! String(contentsOf: folder.appendingPathComponent(name), encoding: .utf8) }
    static func data(_ name: String) -> Data { try! Data(contentsOf: folder.appendingPathComponent(name)) }
}

func sameJSON(_ a: String?, _ b: String) -> Bool {
    guard let a, let x = try? JSONSerialization.jsonObject(with: Data(a.utf8)) as? NSDictionary,
          let y = try? JSONSerialization.jsonObject(with: Data(b.utf8)) as? NSDictionary else { return false }
    return x == y
}

/// The harness's first posted event costs it up to 100 ms, so that cost is paid before anything is timed.
func warmTheHarness() {
    Input.key(kVK_F20, flags: [])
    Input.move(to: Input.pointer)
    usleep(500_000)
}
