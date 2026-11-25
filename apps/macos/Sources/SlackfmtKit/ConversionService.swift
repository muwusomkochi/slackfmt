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
            guard let item = try? pasteboardItem(for: source) else { return .refused(.converterError) }
            destination.clearContents()
            destination.writeObjects([item])
            return .converted
        }
    }

    private func pasteboardItem(for source: Source) throws -> NSPasteboardItem {
        let conversion = try conversion(of: source)
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
    /// Loads AppKit's HTML reader and lets JavaScriptCore compile the converter, so his first click doesn't pay for either.
    public func warmUp() {
        guard let conversion = try? converter.convert("**warm**\n\n- [ ] up", format: .detect) else { return }
        _ = try? RichText.rtf(fromHTML: conversion.html)
    }
}
