import AppKit
import SlackfmtKit

/// His clipboard, held in memory while a run replaces it, and put back after.
struct ClipboardSnapshot {
    private let items: [[NSPasteboard.PasteboardType: Data]]

    init(_ board: NSPasteboard = .general) {
        items = (board.pasteboardItems ?? []).map { item in
            item.types.reduce(into: [:]) { $0[$1] = item.data(forType: $1) }
        }
    }

    func restore(_ board: NSPasteboard = .general) {
        board.clearContents()
        board.writeObjects(items.map { contents in
            let item = NSPasteboardItem()
            for (type, data) in contents { item.setData(data, forType: type) }
            return item
        })
    }
}

enum Clipboard {
    @discardableResult
    static func put(_ contents: [NSPasteboard.PasteboardType: Data]) -> Int {
        let item = NSPasteboardItem()
        for (type, data) in contents { item.setData(data, forType: type) }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([item])
        return NSPasteboard.general.changeCount
    }

    @discardableResult
    static func put(plain: String) -> Int {
        put([.string: Data(plain.utf8)])
    }

    /// Waits for the general pasteboard's changeCount to move past `count`; returns when it did.
    static func waitForChange(after count: Int, timeout: Double) -> Double? {
        let deadline = now() + timeout
        while now() < deadline {
            if NSPasteboard.general.changeCount != count { return now() }
        }
        return nil
    }

    static var slackDelta: String? {
        NSPasteboard.general.data(forType: PasteboardTypes.customData)
            .flatMap { try? Pickle.decode($0) }?
            .first { $0.type == PasteboardTypes.slackEntry }?.value
    }
}
