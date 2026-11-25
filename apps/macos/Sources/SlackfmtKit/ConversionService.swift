import AppKit

public enum Outcome: Equatable {
    case converted
    case refused(Refusal)
}

/// Where a conversion is written: the general pasteboard.
public protocol PasteboardDestination {
    /// Clears the pasteboard and writes the item; false when the pasteboard didn't take it.
    func replaceContents(with item: NSPasteboardItem) -> Bool
}

extension NSPasteboard: PasteboardDestination {
    public func replaceContents(with item: NSPasteboardItem) -> Bool {
        clearContents()
        return writeObjects([item])
    }
}

/// "Convert" in the PRD's sense: read a source pasteboard, write the general one.
public final class ConversionService {
    public let converter: Converter

    public init(converter: Converter) {
        self.converter = converter
    }

    public func convert(from source: NSPasteboard, to destination: PasteboardDestination) -> Outcome {
        switch PasteboardReader.read(source) {
        case .refused(let refusal):
            return .refused(refusal)
        case .source(let source):
            guard let conversion = try? conversion(of: source) else { return .refused(.converterError) }
            // Markup can hold no characters of its own, and pasting nothing is worse than pasting what was copied (G2).
            if conversion.plain.allSatisfy(\.isWhitespace) { return .refused(.empty) }
            guard let item = try? pasteboardItem(for: conversion), destination.replaceContents(with: item) else {
                return .refused(.converterError)
            }
            return .converted
        }
    }

    private struct NotHeld: Error {}

    private func pasteboardItem(for conversion: Conversion) throws -> NSPasteboardItem {
        let html = #"<meta charset="utf-8">"# + conversion.html
        let contents: [(Data, NSPasteboard.PasteboardType)] = [
            (Pickle.encode([(PasteboardTypes.slackEntry, conversion.delta)]), PasteboardTypes.customData),
            (Data(html.utf8), .html),
            (try RichText.rtf(fromHTML: html), .rtf),
            (Data(conversion.plain.utf8), .string),
        ]
        let item = NSPasteboardItem()
        for (data, type) in contents {
            guard item.setData(data, forType: type) else { throw NotHeld() }
        }
        return item
    }

    private func conversion(of source: Source) throws -> Conversion {
        switch source {
        case .html(let html): try converter.convert(html, format: .html)
        case .rtf(let rtf): try converter.convert(RichText.html(fromRTF: rtf), format: .html)
        case .plain(let text): try converter.convert(text, format: .detect)
        }
    }
}

extension ConversionService {
    /// Runs the whole path a few times, a turn of the run loop apart, so AppKit's HTML reader is loaded and JavaScriptCore has
    /// compiled the converter before his first click.
    public func warmUp(_ rounds: Int = 40) {
        guard rounds > 0 else { return }
        _ = NSPasteboard.general.types
        if let conversion = try? converter.convert(Self.sample, format: .detect), let rtf = try? RichText.rtf(fromHTML: conversion.html) {
            _ = try? converter.convert(conversion.html, format: .html)
            _ = NSPasteboardItem().setData(rtf, forType: .rtf)
        }
        DispatchQueue.main.async { [self] in warmUp(rounds - 1) }
    }

    private static let sample = """
        # Title

        Some **bold**, _italic_, ~~struck~~ and `inline code`, with a [link](https://example.com).\\
        A second line, then ![an image](https://example.com/a.png).

        - one
          - nested
        - [ ] open
        - [x] done

        3. third
        4. fourth

        > A quote:
        > - with a list

        ---

        ```sh
        echo code
        ```

        | a | b |
        |---|---|
        | 1 | 2 |
        """
}
