import AppKit

/// X2's loop: one warm JSContext converts the input `runs` times; each run writes V3's pickle,
/// public.html, public.rtf and public.utf8-plain-text to the general pasteboard, and is timed from
/// the call into the JSContext until writeObjects has returned with changeCount incremented.
/// The HTML and plain text come from entry.ts's stand-ins, not core's planned toHtml or V15.
public struct FourTypeTiming {
    public var totals: [Double] = []
    public var stages: [String: [Double]] = [:]
    public var firstRun = ""

    public static func run(core: Core, input: String, runs: Int = 20) throws -> FourTypeTiming {
        var result = FourTypeTiming()
        for run in 1...runs {
            let start = DispatchTime.now()
            var mark = start
            func lap(_ name: String) {
                result.stages[name, default: []].append(ms(since: mark))
                mark = DispatchTime.now()
            }
            let out = try core.run(input, format: "markdown")
            lap("js")
            let pickle = Pickle.encode([("slack/texty", out.delta)])
            lap("pickle")
            let rtf = try Rich.rtf(Rich.attributed(html: out.html))
            lap("rtf")
            let count = Board.write(pickle: pickle, html: out.html, rtf: rtf, plain: out.plain)
            lap("write")
            result.totals.append(ms(since: start))
            guard count.after > count.before else { throw ProbeError("changeCount did not increment on run \(run)") }
            if run == 1 {
                let decoded = try Pickle.decode(pickle)
                guard decoded.count == 1, decoded[0].0 == "slack/texty", decoded[0].1 == out.delta else {
                    throw ProbeError("the pickle did not decode by V3 to the same Delta")
                }
                result.firstRun = "Delta \(out.delta.utf8.count) bytes (\(try summarize(delta: out.delta))); pickle \(pickle.count) bytes, decodes by V3 to the same Delta; public.html \(out.html.utf8.count) bytes; public.rtf \(rtf.count) bytes; plain \(out.plain.utf16.count) UTF-16 units"
            }
        }
        return result
    }

    public var median: Double { ProbeKit.median(totals) }

    public func report(_ label: String) -> [String] {
        let fmt = { (v: Double) in String(format: "%.1f", v) }
        var lines = ["\(label) run 1 outputs: \(firstRun)",
                     "\(label) runs (ms): \(totals.map(fmt).joined(separator: ", "))"]
        for name in ["js", "pickle", "rtf", "write"] {
            let values = stages[name]!
            lines.append("\(label) stage \(name): median \(fmt(ProbeKit.median(values))) ms, max \(fmt(values.max()!)) ms")
        }
        lines.append("\(label) median of \(totals.count): \(fmt(median)) ms, min \(fmt(totals.min()!)) ms, max \(fmt(totals.max()!)) ms; budget 300 ms (V7)")
        return lines
    }
}
