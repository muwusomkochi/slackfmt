import AppKit

/// Why nothing was converted, in the order V25 picks when more than one applies.
public enum Refusal: CaseIterable {
    case image, file, slackFormat, empty, tooLong, converterError

    public var message: String {
        switch self {
        case .image: "Images can't be converted"
        case .file: "Files can't be converted"
        case .slackFormat: "Already Slack format"
        case .empty: "Clipboard is empty"
        case .tooLong: "Too long to convert"
        case .converterError: "Couldn't convert this"
        }
    }
}

public enum Source: Equatable {
    case html(String)
    case rtf(Data)
    case plain(String)

    fileprivate var text: String {
        switch self {
        case .html(let text), .plain(let text): text
        case .rtf(let data): String(decoding: data, as: UTF8.self)
        }
    }
}

public enum PasteboardReader {
    public static let maximumCodeUnits = 200_000

    public enum Reading: Equatable {
        case source(Source)
        case refused(Refusal)
    }

    public static func read(_ board: NSPasteboard) -> Reading {
        let types = Set((board.pasteboardItems ?? []).flatMap(\.types) + (board.types ?? []))
        if !types.isDisjoint(with: PasteboardTypes.images) { return .refused(.image) }
        if types.contains(.fileURL) { return .refused(.file) }
        if holdsSlackFormat(board, types) { return .refused(.slackFormat) }
        guard let source = firstSource(board, types) else { return .refused(.empty) }
        let text = source.text
        if text.allSatisfy(\.isWhitespace) { return .refused(.empty) }
        if text.utf16.count > maximumCodeUnits { return .refused(.tooLong) }
        return .source(source)
    }

    private static func holdsSlackFormat(_ board: NSPasteboard, _ types: Set<NSPasteboard.PasteboardType>) -> Bool {
        guard types.contains(PasteboardTypes.customData),
              let data = board.data(forType: PasteboardTypes.customData),
              let entries = try? Pickle.decode(data) else { return false }
        return entries.contains { $0.type == PasteboardTypes.slackEntry }
    }

    private static func firstSource(_ board: NSPasteboard, _ types: Set<NSPasteboard.PasteboardType>) -> Source? {
        if types.contains(.html) { return .html(board.string(forType: .html) ?? "") }
        if types.contains(.rtf) { return .rtf(board.data(forType: .rtf) ?? Data()) }
        if types.contains(.string) { return .plain(board.string(forType: .string) ?? "") }
        return nil
    }
}
