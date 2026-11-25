import AppKit

/// V18's paths through NSAttributedString. AppKit's HTML reader runs on the main thread only.
public enum RichText {
    public static func rtf(fromHTML html: String) throws -> Data {
        let string = try NSAttributedString(
            data: Data(html.utf8),
            options: [.documentType: NSAttributedString.DocumentType.html, .characterEncoding: String.Encoding.utf8.rawValue],
            documentAttributes: nil)
        return try string.data(
            from: NSRange(location: 0, length: string.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
    }

    public static func html(fromRTF rtf: Data) throws -> String {
        let string = try NSAttributedString(
            data: rtf,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil)
        let data = try string.data(
            from: NSRange(location: 0, length: string.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.html, .characterEncoding: String.Encoding.utf8.rawValue])
        return String(decoding: data, as: UTF8.self)
    }
}
