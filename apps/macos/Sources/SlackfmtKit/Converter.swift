import Foundation
import JavaScriptCore

public struct Conversion: Equatable {
    public let delta: String
    public let html: String
    public let plain: String

    public init(delta: String, html: String, plain: String) {
        self.delta = delta
        self.html = html
        self.plain = plain
    }
}

/// The fork's core bundle in one JSContext, kept warm across conversions.
public final class Converter {
    public enum Format {
        case html
        case detect
    }

    public enum Failure: Error {
        case scriptDidNotLoad
        case threw
        case didNotSettle
        case badResult
        case testHook
    }

    public var throwsForTesting = false
    private let context: JSContext
    private let function: JSValue

    public init(script: String) throws {
        guard let context = JSContext() else { throw Failure.scriptDidNotLoad }
        context.evaluateScript(script)
        guard context.exception == nil,
              let function = context.objectForKeyedSubscript("slackfmt")?.objectForKeyedSubscript("convert"),
              function.isObject else { throw Failure.scriptDidNotLoad }
        self.context = context
        self.function = function
    }

    public func convert(_ text: String, format: Format) throws -> Conversion {
        if throwsForTesting { throw Failure.testHook }
        context.exception = nil
        let arguments: [Any] = format == .html ? [text, "html"] : [text]
        guard let promise = function.call(withArguments: arguments), context.exception == nil else { throw Failure.threw }

        var resolved: JSValue?
        var rejected = false
        let onResolve: @convention(block) (JSValue) -> Void = { resolved = $0 }
        let onReject: @convention(block) (JSValue) -> Void = { _ in rejected = true }
        promise.invokeMethod("then", withArguments: [
            JSValue(object: onResolve, in: context) as Any,
            JSValue(object: onReject, in: context) as Any,
        ])
        if rejected || context.exception != nil { throw Failure.threw }
        guard let resolved else { throw Failure.didNotSettle }
        guard let delta = string(resolved, "delta"), let html = string(resolved, "html"), let plain = string(resolved, "plain") else {
            throw Failure.badResult
        }
        return Conversion(delta: delta, html: html, plain: plain)
    }

    private func string(_ value: JSValue, _ key: String) -> String? {
        guard let property = value.forProperty(key), property.isString else { return nil }
        return property.toString()
    }
}
