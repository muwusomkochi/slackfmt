import AppKit

/// A2, on A1's result: plain text by V15, public.html and public.rtf by V24.
func rowA2(_ how: String) {
    let report = Report("A2 after \(how)")
    let board = NSPasteboard.general
    let plain = board.string(forType: .string) ?? ""
    report.check(plain == Fixtures.text("fixture.txt"), "plain text equals fixture.txt byte for byte")
    for marker in ["**", "~~", "](", "- [", "```", "\\"] {
        report.check(!plain.contains(marker), "no \"\(marker)\" in the plain text")
    }
    checkHTML(report, board.string(forType: .html) ?? "")
    checkRTF(report, board.data(forType: .rtf) ?? Data())
    report.finish()
}

private func checkHTML(_ report: Report, _ html: String) {
    guard let document = try? XMLDocument(xmlString: "<html><body>\(html.replacingOccurrences(of: #"<meta charset="utf-8">"#, with: ""))</body></html>", options: [.documentTidyHTML]) else {
        return report.check(false, "public.html parses")
    }
    func texts(_ path: String) -> [String] {
        ((try? document.nodes(forXPath: path)) ?? []).map {
            ($0.stringValue ?? "").replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces)
        }
    }
    func has(_ what: String, _ path: String, _ expected: [String]) {
        let found = texts(path)
        report.check(found == expected, "public.html \(what)", found == expected ? "" : "\(found)")
    }
    has("bold <strong>", "//strong", ["Skills update"])
    has("italic <em>", "//em", ["wider"])
    has("strikethrough <s>", "//s", ["tighter"])
    has("inline code <code>", "//code[not(parent::pre)]", ["scripts/pack decision-panels"])
    has("link <a href>", "//a[@href='https://github.com/muwusomkochi/precedent']", ["precedent"])
    has("image link", "//a[@href='https://example.com/cover.png']", ["team cover"])
    has("image link with no alt", "//a[@href='https://example.com/no-alt.png']", ["https://example.com/no-alt.png"])
    has("bullet list <ul><li>", "/html/body/ul/li/a", ["precedent"])
    has("nested list inside its <li>", "/html/body/ul/li/ul/li", ["reader cut at 54fdad2"])
    has("task items' text starts with V14", "/html/body/ul/li[starts-with(normalize-space(.), '☐') or starts-with(normalize-space(.), '☑')]", ["☐ upload the decision-panels cut", "☑ ds-workflow seal"])
    has("ordered list past 1 as paragraphs starting \"n. \"", "//p[starts-with(normalize-space(.), '3. ') or starts-with(normalize-space(.), '4. ')]", ["3. third step keeps its number", "4. fourth follows"])
    has("no <ol> for it", "//ol", [])
    has("quote <blockquote>", "//blockquote/p", ["Upload only after the test panel:"])
    has("the quote's list as <ul>", "//blockquote/ul/li", ["render it live", "then upload"])
    has("code block <pre><code>", "//pre/code", ["scripts/pack decision-panels"])
}

private func checkRTF(_ report: Report, _ data: Data) {
    guard let rich = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil) else {
        return report.check(false, "public.rtf reads through NSAttributedString")
    }
    let string = rich.string as NSString
    func attribute<Value>(_ key: NSAttributedString.Key, of text: String, from: Int = 0) -> Value? {
        let range = string.range(of: text, range: NSRange(location: from, length: string.length - from))
        guard range.location != NSNotFound else { return nil }
        return rich.attribute(key, at: range.location, effectiveRange: nil) as? Value
    }
    func traits(_ text: String, from: Int = 0) -> NSFontDescriptor.SymbolicTraits {
        (attribute(.font, of: text, from: from) as NSFont?)?.fontDescriptor.symbolicTraits ?? []
    }
    report.check(traits("Skills update").contains(.bold), "public.rtf bold font trait")
    report.check(!traits("Panel cards").contains(.bold), "public.rtf plain text isn't bold")
    report.check(traits("wider").contains(.italic), "public.rtf italic font trait")
    report.check((attribute(.strikethroughStyle, of: "tighter") as Int?) == NSUnderlineStyle.single.rawValue, "public.rtf single strikethrough")
    report.check((attribute(.link, of: "precedent") as URL?)?.absoluteString == "https://github.com/muwusomkochi/precedent", "public.rtf link to the URL")
    report.check((attribute(.link, of: "team cover") as URL?)?.absoluteString == "https://example.com/cover.png", "public.rtf image link")
    let code = "scripts/pack decision-panels"
    let first = string.range(of: code)
    report.check(traits(code).contains(.monoSpace), "public.rtf fixed-pitch inline code")
    report.check(first.location != NSNotFound && traits(code, from: NSMaxRange(first)).contains(.monoSpace), "public.rtf fixed-pitch code block")
    report.note("public.rtf lists, tasks and quotes are judged in E2 (X8's branch)")
}
