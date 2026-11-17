import Foundation
import JavaScriptCore

public enum Paths {
    static let loop1 = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent()

    public static var bundle: URL {
        if let path = ProcessInfo.processInfo.environment["SLACKFMT_BUNDLE"] { return URL(fileURLWithPath: path) }
        return loop1.appendingPathComponent("build/core.iife.js")
    }

    public static var fixtures: URL {
        if let path = ProcessInfo.processInfo.environment["SLACKFMT_FIXTURES"] { return URL(fileURLWithPath: path) }
        return FileManager.default.temporaryDirectory.appendingPathComponent("slackfmt-loop1-fixtures")
    }

    public static func fixture(_ name: String) throws -> String {
        try String(contentsOf: fixtures.appendingPathComponent(name), encoding: .utf8)
    }
}

public struct ProbeError: Error, CustomStringConvertible {
    public let description: String
    public init(_ description: String) { self.description = description }
}

/// One JSContext holding the core bundle, kept warm across calls.
public final class Core {
    public let context: JSContext
    public private(set) var loadMs: Double = 0
    private var lastException: String?

    public init(bundle: URL = Paths.bundle) throws {
        let source = try String(contentsOf: bundle, encoding: .utf8)
        guard let context = JSContext() else { throw ProbeError("JSContext() returned nil") }
        self.context = context
        let start = DispatchTime.now()
        context.exceptionHandler = { [weak self] _, value in
            let stack = value?.objectForKeyedSubscript("stack")?.toString() ?? ""
            self?.lastException = "\(value?.toString() ?? "unknown")\n\(stack)"
        }
        context.evaluateScript(source, withSourceURL: bundle)
        loadMs = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1e6
        if let error = lastException { throw ProbeError("bundle threw on load: \(error)") }
        guard context.objectForKeyedSubscript("slackfmtProbe")?.isObject == true else {
            throw ProbeError("bundle loaded but slackfmtProbe is missing")
        }
    }

    private func call(_ expression: String, input: String, format: String) throws -> JSValue {
        lastException = nil
        context.setObject(input, forKeyedSubscript: "__in" as NSString)
        context.setObject(format, forKeyedSubscript: "__fmt" as NSString)
        context.evaluateScript("""
            globalThis.__r = undefined; globalThis.__e = undefined;
            \(expression).then((r) => { globalThis.__r = r; }, (e) => { globalThis.__e = String(e && e.stack ? e + "\\n" + e.stack : e); });
            """)
        if let error = lastException { throw ProbeError("threw: \(error)") }
        if let rejected = context.objectForKeyedSubscript("__e"), !rejected.isUndefined {
            throw ProbeError("rejected: \(rejected.toString() ?? "")")
        }
        guard let result = context.objectForKeyedSubscript("__r"), !result.isUndefined else {
            throw ProbeError("the promise had not settled when evaluateScript returned")
        }
        return result
    }

    public func convert(_ input: String, format: String) throws -> String {
        try call("slackfmtProbe.convert(__in, { format: __fmt })", input: input, format: format).toString()
    }

    public func run(_ input: String, format: String) throws -> (delta: String, html: String, plain: String) {
        let r = try call("slackfmtProbe.run(__in, __fmt)", input: input, format: format)
        return (r.forProperty("delta").toString(), r.forProperty("html").toString(), r.forProperty("plain").toString())
    }
}
