// X3: writes fixture.md's four types to the general pasteboard for a paste into Slack desktop.
// The pickle holds core's Delta of fixture.md (V3, V22); public.html is fixture.html (Appendix E,
// fixture.md as a browser copies it) and public.rtf that HTML through NSAttributedString; the plain
// text is entry.ts's stand-in. fixture.html keeps the two hard breaks the upstream converter drops,
// so the paste shows which type Slack read.
// `x3-write control` writes the pickle and plain text only.
import Foundation
import ProbeKit

do {
    let control = CommandLine.arguments.dropFirst().first == "control"
    let core = try Core()
    let out = try core.run(try Paths.fixture("fixture.md"), format: "markdown")
    let pickle = Pickle.encode([("slack/texty", out.delta)])
    let html = control ? nil : try Paths.fixture("fixture.html")
    let rtf = try html.map { try Rich.rtf(Rich.attributed(html: $0)) }
    let count = Board.write(pickle: pickle, html: html, rtf: rtf, plain: out.plain)
    var written = ["org.chromium.web-custom-data \(pickle.count) bytes (Delta sha256 \(sha256(out.delta)))"]
    if let html, let rtf { written += ["public.html \(html.utf8.count) bytes", "public.rtf \(rtf.count) bytes"] }
    written.append("public.utf8-plain-text \(out.plain.utf8.count) bytes")
    print("x3-write \(control ? "control" : "test"): changeCount \(count.before) -> \(count.after); one item holding \(written.joined(separator: "; "))")
} catch {
    print("x3-write failed: \(error)")
    exit(1)
}
