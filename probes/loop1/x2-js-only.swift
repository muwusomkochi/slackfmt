// X2 diagnostic: times core's conversion of fixture-20k.md inside one warm JSContext, measured in
// JavaScript with no Swift bridging, from a plain release binary rather than the xctest host.
// Build and run: swiftc -O probes/loop1/x2-js-only.swift -o probes/loop1/build/x2-js-only && probes/loop1/build/x2-js-only
import Foundation
import JavaScriptCore

let loop1 = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let bundle = try String(contentsOf: loop1.appendingPathComponent("build/core.iife.js"), encoding: .utf8)
let fixtures = ProcessInfo.processInfo.environment["SLACKFMT_FIXTURES"]
    ?? FileManager.default.temporaryDirectory.appendingPathComponent("slackfmt-loop1-fixtures").path
let input = try String(contentsOfFile: fixtures + "/fixture-20k.md", encoding: .utf8)

let context = JSContext()!
context.exceptionHandler = { _, value in print("threw: \(value?.toString() ?? "")"); exit(1) }
context.evaluateScript(bundle)
context.setObject(input, forKeyedSubscript: "__in" as NSString)
context.evaluateScript("""
    globalThis.__t = null;
    (async () => {
      const t = [];
      for (let i = 0; i < 20; i++) {
        const s = Date.now();
        await slackfmtProbe.run(__in, "markdown");
        t.push(Date.now() - s);
      }
      globalThis.__t = t;
    })().catch((e) => { globalThis.__t = String(e); });
    """)
let times = context.objectForKeyedSubscript("__t").toArray() as? [Double] ?? []
guard times.count == 20 else { print("the loop did not finish: \(context.objectForKeyedSubscript("__t").toString() ?? "")"); exit(1) }
let sorted = times.sorted()
let fmt = { (v: Double) in String(format: "%.1f", v) }
print("JS-only run(), 20 warm runs (ms): \(times.map(fmt).joined(separator: ", "))")
print("median \(fmt((sorted[9] + sorted[10]) / 2)) ms, min \(fmt(sorted[0])) ms, max \(fmt(sorted[19])) ms")

// A JIT runs this loop in well under a second; JSC's interpreter alone takes several.
let loopMs = context.evaluateScript("""
    (() => { const s = Date.now(); let x = 0; for (let i = 0; i < 1e8; i++) { x = (x + i) | 0; } return Date.now() - s; })()
    """).toDouble()
print("1e8-iteration integer loop: \(fmt(loopMs)) ms")
