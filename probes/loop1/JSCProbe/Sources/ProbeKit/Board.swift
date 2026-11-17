import AppKit
import CryptoKit

public enum Rich {
    public static func attributed(html: String) throws -> NSAttributedString {
        try NSAttributedString(
            data: Data(html.utf8),
            options: [.documentType: NSAttributedString.DocumentType.html, .characterEncoding: String.Encoding.utf8.rawValue],
            documentAttributes: nil)
    }

    public static func rtf(_ string: NSAttributedString) throws -> Data {
        try string.data(
            from: NSRange(location: 0, length: string.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
    }

    public static func attributed(rtf: Data) throws -> NSAttributedString {
        try NSAttributedString(data: rtf, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil)
    }
}

public enum Board {
    public static let customData = NSPasteboard.PasteboardType("org.chromium.web-custom-data")
    public static let html = NSPasteboard.PasteboardType("public.html")
    public static let rtf = NSPasteboard.PasteboardType("public.rtf")
    public static let plain = NSPasteboard.PasteboardType("public.utf8-plain-text")

    /// Clears the general pasteboard and writes one item holding the given types, in V4's order.
    /// Returns the changeCount before and after.
    @discardableResult
    public static func write(pickle: Data?, html: String?, rtf: Data?, plain: String) -> (before: Int, after: Int) {
        let board = NSPasteboard.general
        let before = board.changeCount
        let item = NSPasteboardItem()
        if let pickle { item.setData(pickle, forType: customData) }
        if let html { item.setData(Data(html.utf8), forType: Self.html) }
        if let rtf { item.setData(rtf, forType: Self.rtf) }
        item.setData(Data(plain.utf8), forType: Self.plain)
        board.clearContents()
        board.writeObjects([item])
        return (before, board.changeCount)
    }
}

public func sha256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

public func sha256(_ string: String) -> String { sha256(Data(string.utf8)) }

public func ms(since start: DispatchTime) -> Double {
    Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1e6
}

public func median(_ values: [Double]) -> Double {
    let s = values.sorted()
    return s.count % 2 == 1 ? s[s.count / 2] : (s[s.count / 2 - 1] + s[s.count / 2]) / 2
}

/// A Delta summarised without its text: op count, newline count, and each attribute key with how
/// many ops carry it, so the public log never holds fixture text.
public func summarize(delta: String) throws -> String {
    guard let object = try JSONSerialization.jsonObject(with: Data(delta.utf8)) as? [String: Any],
          let ops = object["ops"] as? [[String: Any]] else { throw ProbeError("not a Delta: no ops array") }
    var keys: [String: Int] = [:]
    var values: [String: Set<String>] = [:]
    for op in ops {
        for (key, value) in op["attributes"] as? [String: Any] ?? [:] {
            keys[key, default: 0] += 1
            if key != "link" { values[key, default: []].insert("\(value)") }
        }
    }
    let lines = ops.reduce(0) { $0 + (($1["insert"] as? String)?.filter { $0 == "\n" }.count ?? 0) }
    let attrs = keys.keys.sorted().map { key in
        let vals = values[key].map { " = " + $0.sorted().joined(separator: "|") } ?? ""
        return "\(key) x\(keys[key]!)\(vals)"
    }.joined(separator: ", ")
    return "\(ops.count) ops, \(lines) newlines; attributes: \(attrs.isEmpty ? "none" : attrs)"
}
