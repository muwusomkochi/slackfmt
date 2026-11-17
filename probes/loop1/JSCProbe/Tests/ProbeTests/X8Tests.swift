import AppKit
import ProbeKit
import XCTest

/// X8: fixture.html (Appendix E) read through NSAttributedString, then written as RTF and read back,
/// with each V24 feature's RTF attribute checked at both stages. The spans come from fixture.html
/// at run time, so no fixture text sits in this file, and the log names features, not text.
final class X8Tests: XCTestCase {
    struct Spans {
        var strong: [String] = [], em: [String] = [], strike: [String] = [], code: [String] = []
        var links: [(text: String, href: String)] = []
        var bullets: [String] = [], nested: [String] = [], tasks: [String] = []
        var ordered: [String] = [], orderedStart = 1
        var quote: [String] = [], quotedItems: [String] = [], codeLines: [String] = []
    }

    static func tidy(_ s: String) -> String {
        s.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces)
    }

    static func ownText(_ li: XMLNode) -> String {
        var text = ""
        for child in li.children ?? [] {
            if let name = child.name, ["ul", "ol"].contains(name) { break }
            text += child.stringValue ?? ""
        }
        return tidy(text)
    }

    static func spans(_ html: String) throws -> Spans {
        let doc = try XMLDocument(xmlString: "<html><body>\(html)</body></html>", options: [.documentTidyHTML])
        func nodes(_ xpath: String) throws -> [XMLNode] { try doc.nodes(forXPath: xpath) }
        func texts(_ xpath: String) throws -> [String] { try nodes(xpath).map { tidy($0.stringValue ?? "") } }
        var s = Spans()
        s.strong = try texts("//strong")
        s.em = try texts("//em")
        s.strike = try texts("//del | //s")
        s.code = try texts("//code[not(parent::pre)]")
        s.links = try nodes("//a[@href]").map { node in
            (tidy(node.stringValue ?? ""), (node as? XMLElement)?.attribute(forName: "href")?.stringValue ?? "")
        }
        let top = try nodes("/html/body/ul/li")
        let isTask = { (li: XMLNode) in
            ((li as? XMLElement)?.elements(forName: "input").isEmpty == false) || ["☐", "☑"].contains(ownText(li).first ?? " ")
        }
        s.bullets = top.filter { !isTask($0) }.map(ownText)
        s.tasks = top.filter(isTask).map(ownText)
        s.nested = try nodes("//li/ul/li").map(ownText)
        let ol = try nodes("//ol").first as? XMLElement
        s.orderedStart = Int(ol?.attribute(forName: "start")?.stringValue ?? "1") ?? 1
        s.ordered = try nodes("//ol/li").map(ownText)
        s.quote = try texts("//blockquote/p")
        s.quotedItems = try nodes("//blockquote//li").map(ownText)
        s.codeLines = try nodes("//pre/code").flatMap { ($0.stringValue ?? "").split(separator: "\n").map { tidy(String($0)) } }
        return s
    }

    struct Check { let feature: String; let v24: String; let results: [Bool]; let detail: String; let present: String }

    static func check(_ a: NSAttributedString, _ s: Spans) -> [Check] {
        let string = a.string as NSString
        func range(_ text: String) -> NSRange? {
            let r = string.range(of: text)
            return r.location == NSNotFound ? nil : r
        }
        func fonts(_ r: NSRange) -> [NSFont] {
            var out: [NSFont] = []
            a.enumerateAttribute(.font, in: r) { value, _, _ in if let f = value as? NSFont { out.append(f) } }
            return out
        }
        func allFonts(_ text: String, _ test: (NSFont) -> Bool) -> Bool {
            guard let r = range(text) else { return false }
            let f = fonts(r)
            return !f.isEmpty && f.allSatisfy(test)
        }
        let bold = { (f: NSFont) in f.fontDescriptor.symbolicTraits.contains(.bold) }
        let italic = { (f: NSFont) in f.fontDescriptor.symbolicTraits.contains(.italic) }
        let mono = { (f: NSFont) in f.isFixedPitch || f.fontDescriptor.symbolicTraits.contains(.monoSpace) }
        func paragraph(_ text: String) -> NSParagraphStyle? {
            guard let r = range(text) else { return nil }
            return a.attribute(.paragraphStyle, at: r.location, effectiveRange: nil) as? NSParagraphStyle
        }
        func lists(_ text: String) -> [NSTextList] { paragraph(text)?.textLists ?? [] }
        func paragraphText(_ text: String) -> String {
            guard let r = range(text) else { return "" }
            var p = string.substring(with: string.paragraphRange(for: r))
            if p.hasPrefix("\t"), let second = p.dropFirst().firstIndex(of: "\t") { p = String(p[p.index(after: second)...]) }
            return p
        }
        func scalar(_ text: String) -> String {
            guard let first = paragraphText(text).unicodeScalars.first else { return "none" }
            return CharacterSet.letters.contains(first) ? "a letter" : String(format: "U+%04X", first.value)
        }
        func count(_ results: [Bool]) -> String { "\(results.filter { $0 }.count)/\(results.count)" }
        func describe(_ text: String?) -> String {
            guard let text, let r = range(text) else { return "span not found" }
            let attrs = a.attributes(at: r.location, effectiveRange: nil)
            var parts: [String] = []
            if let f = attrs[.font] as? NSFont {
                let t = f.fontDescriptor.symbolicTraits
                let traits = [(t.contains(.bold), "bold"), (t.contains(.italic), "italic"), (mono(f), "fixed-pitch")].filter(\.0).map(\.1)
                parts.append("font \(f.fontName) \(Int(f.pointSize)) pt" + (traits.isEmpty ? "" : " (\(traits.joined(separator: ", ")))"))
            }
            if let v = attrs[.strikethroughStyle] as? Int, v != 0 { parts.append("strikethrough \(v)") }
            if let v = attrs[.underlineStyle] as? Int, v != 0 { parts.append("underline \(v)") }
            if attrs[.link] != nil { parts.append("link") }
            if let p = attrs[.paragraphStyle] as? NSParagraphStyle {
                var ps = ["head indent \(Int(p.headIndent))", "first-line indent \(Int(p.firstLineHeadIndent))"]
                if !p.textLists.isEmpty { ps.append("text lists " + p.textLists.map { "\($0.markerFormat.rawValue) from \($0.startingItemNumber)" }.joined(separator: " > ")) }
                if !p.textBlocks.isEmpty { ps.append("text blocks \(p.textBlocks.count)") }
                parts.append("paragraph (\(ps.joined(separator: ", ")))")
            }
            let shown: Set<String> = ["NSFont", "NSStrikethrough", "NSUnderline", "NSLink", "NSParagraphStyle"]
            let others = attrs.keys.map(\.rawValue).filter { !shown.contains($0) }.sorted()
            if !others.isEmpty { parts.append("also " + others.joined(separator: ", ")) }
            return parts.joined(separator: "; ")
        }

        var checks: [Check] = []
        func add(_ feature: String, _ v24: String, _ results: [Bool], _ detail: String = "", sample: String? = nil) {
            checks.append(Check(feature: feature, v24: v24, results: results,
                                detail: detail.isEmpty ? count(results) : "\(count(results)); \(detail)", present: describe(sample)))
        }

        add("bold", "bold font trait", s.strong.map { allFonts($0, bold) }, sample: s.strong.first)
        add("italic", "italic font trait", s.em.map { allFonts($0, italic) }, sample: s.em.first)
        let strike = s.strike.map { text -> Bool in
            guard let r = range(text) else { return false }
            var ok = true
            a.enumerateAttribute(.strikethroughStyle, in: r) { v, _, _ in if (v as? Int) != NSUnderlineStyle.single.rawValue { ok = false } }
            return ok
        }
        add("strikethrough", "single strikethrough style", strike, sample: s.strike.first)
        add("inline code", "fixed-pitch font", s.code.map { allFonts($0, mono) }, sample: s.code.first)
        let links = s.links.map { link -> Bool in
            guard let r = range(link.text) else { return false }
            let v = a.attribute(.link, at: r.location, effectiveRange: nil)
            return (v as? URL)?.absoluteString == link.href || (v as? String) == link.href
        }
        add("link", "link attribute to the URL", links, sample: s.links.first?.text)
        let bulletFormats = Set(s.bullets.compactMap { lists($0).last?.markerFormat.rawValue })
        add("bullet list", "a text list with a disc marker", s.bullets.map { lists($0).last?.markerFormat == .disc },
            "marker formats seen: \(bulletFormats.sorted().joined(separator: " "))", sample: s.bullets.first)
        let orderedLists = s.ordered.map { lists($0).last }
        let orderedOK = orderedLists.map { $0?.markerFormat == .decimal && $0?.startingItemNumber == s.orderedStart }
        add("ordered list", "a text list with decimal markers from n", orderedOK,
            "n = \(s.orderedStart); seen: \(orderedLists.map { l in l.map { "\($0.markerFormat.rawValue) from \($0.startingItemNumber)" } ?? "no list" }.joined(separator: ", "))", sample: s.ordered.first)
        let v14: Set<Character> = ["☐", "☑"]
        add("task item", "a list item whose text starts with V14", s.tasks.map { !lists($0).isEmpty && v14.contains(paragraphText($0).first ?? " ") },
            "first character after the list marker: \(s.tasks.map(scalar).joined(separator: ", ")); in a text list: \(s.tasks.map { !lists($0).isEmpty })", sample: s.tasks.first)
        add("nested list", "a second text-list level", s.nested.map { lists($0).count >= 2 },
            "levels seen: \(s.nested.map { String(lists($0).count) }.joined(separator: ", "))", sample: s.nested.first)
        add("quote", "a paragraph head indent above 0", s.quote.map { (paragraph($0)?.headIndent ?? 0) > 0 },
            "head indents: \(s.quote.map { String(format: "%.0f", paragraph($0)?.headIndent ?? -1) }.joined(separator: ", ")); quoted list items' head indents \(s.quotedItems.map { String(format: "%.0f", paragraph($0)?.headIndent ?? -1) }.joined(separator: ", ")), list levels \(s.quotedItems.map { String(lists($0).count) }.joined(separator: ", "))", sample: s.quote.first)
        add("code block", "fixed-pitch font on every line", s.codeLines.map { allFonts($0, mono) }, sample: s.codeLines.first)
        return checks
    }

    @discardableResult
    static func run(_ html: String, _ label: String) throws -> [String] {
        let spans = try spans(html)
        let imported = try Rich.attributed(html: html)
        let rtf = try Rich.rtf(imported)
        let readBack = try Rich.attributed(rtf: rtf)
        print("\(label) input \(html.utf8.count) bytes -> NSAttributedString \(imported.length) units -> RTF \(rtf.count) bytes -> read back \(readBack.length) units")
        let stages = [("html import", check(imported, spans)), ("rtf read back", check(readBack, spans))]
        var missing: [String] = []
        for index in stages[0].1.indices {
            let line = stages.map { stage in
                let c = stage.1[index]
                let ok = !c.results.isEmpty && c.results.allSatisfy { $0 }
                if stage.0 == "rtf read back", !ok { missing.append(c.feature) }
                return "\(stage.0): \(ok ? "present" : "ABSENT") (\(c.detail))"
            }
            let c = stages[1].1[index]
            print("\(label) \(c.feature) [V24 RTF: \(c.v24)]: \(line.joined(separator: " | "))")
            print("\(label) \(c.feature) RTF attributes present: \(c.present)")
        }
        print("\(label) features absent after the RTF read back: \(missing.isEmpty ? "none" : missing.joined(separator: ", "))")
        return missing
    }

    func testX8RichCopyCarriesV24Attributes() throws {
        XCTAssertEqual(try Self.run(try Paths.fixture("fixture.html"), "X8 fixture.html"), [])
    }

    /// Supplementary, not X8's call: fixture.html in V24's HTML shape, with each checkbox input as
    /// V14's box and <del> as <s>, to tell a fixture difference from an NSAttributedString loss.
    func testX8SupplementaryV24ShapedHtml() throws {
        let html = try Paths.fixture("fixture.html")
            .replacingOccurrences(of: "<input[^>]*checked[^>]*>", with: "☑", options: .regularExpression)
            .replacingOccurrences(of: "<input[^>]*>", with: "☐", options: .regularExpression)
            .replacingOccurrences(of: "<del>", with: "<s>").replacingOccurrences(of: "</del>", with: "</s>")
        try Self.run(html, "X8 supplementary V24-shaped")
    }
}
