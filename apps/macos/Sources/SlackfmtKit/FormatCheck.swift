import AppKit

/// Whether a Slack copy on the pasteboard still holds the format this app writes (V20).
public enum FormatCheck: Equatable {
    case matches, changed, absent

    public init(_ board: NSPasteboard) {
        guard let data = board.data(forType: PasteboardTypes.customData) else {
            self = .absent
            return
        }
        let delta = (try? Pickle.decode(data))?.first { $0.type == PasteboardTypes.slackEntry }?.value
        let object = delta.flatMap { try? JSONSerialization.jsonObject(with: Data($0.utf8)) } as? [String: Any]
        self = object?["ops"] is [Any] ? .matches : .changed
    }

    public var message: String {
        switch self {
        case .matches: "Slack's format still matches"
        case .changed: "Slack's format changed: formatted pastes may break"
        case .absent: "No Slack format on the clipboard. Copy a formatted message in Slack first"
        }
    }
}
