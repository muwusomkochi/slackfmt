import AppKit

public enum Outcome: Equatable {
    case converted
    case refused(Refusal)
}

/// "Convert" in the PRD's sense: read a source pasteboard, write the general one.
public final class ConversionService {
    public let converter: Converter

    public init(converter: Converter) {
        self.converter = converter
    }

    public func convert(from source: NSPasteboard, to destination: NSPasteboard) -> Outcome {
        switch PasteboardReader.read(source) {
        case .refused(let refusal):
            return .refused(refusal)
        case .source(let source):
            guard let conversion = try? conversion(of: source) else { return .refused(.converterError) }
            // Markup can hold no characters of its own, and pasting nothing is worse than pasting what was copied (G2).
            if conversion.plain.allSatisfy(\.isWhitespace) { return .refused(.empty) }
            guard let item = try? pasteboardItem(for: conversion) else { return .refused(.converterError) }
            destination.clearContents()
            destination.writeObjects([item])
            return .converted
        }
    }

    private func pasteboardItem(for conversion: Conversion) throws -> NSPasteboardItem {
        let html = #"<meta charset="utf-8">"# + conversion.html
        let item = NSPasteboardItem()
        item.setData(Pickle.encode([(PasteboardTypes.slackEntry, conversion.delta)]), forType: PasteboardTypes.customData)
        item.setData(Data(html.utf8), forType: .html)
        item.setData(try RichText.rtf(fromHTML: html), forType: .rtf)
        item.setData(Data(conversion.plain.utf8), forType: .string)
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
