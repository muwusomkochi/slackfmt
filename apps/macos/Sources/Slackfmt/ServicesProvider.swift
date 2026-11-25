import AppKit

/// Services > Copy for Slack (R3). The method's name is Info.plist's NSMessage.
final class ServicesProvider: NSObject {
    private let convert: (NSPasteboard) -> Void

    init(convert: @escaping (NSPasteboard) -> Void) {
        self.convert = convert
    }

    @objc func copyForSlack(_ board: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        StateLog.write("services called")
        convert(board)
    }
}
