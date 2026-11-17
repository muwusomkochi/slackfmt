// X4: reads what Slack desktop put on the general pasteboard, decodes org.chromium.web-custom-data
// by V3, and prints each op's attributes without its text. The full slack/texty JSON is written
// outside the repo (to the fixtures folder) and printed after a marker line, for the handback only.
// Run after each copy: swift run x4-decode <label>
// Or watch: swift run x4-decode watch <seconds> decodes each new copy as copy-1, copy-2, ... and
// names only the types of a copy that holds no org.chromium.web-custom-data.
import AppKit
import ProbeKit

let board = NSPasteboard.general

func decode(_ label: String) -> Bool {
    print("x4 \(label): changeCount \(board.changeCount)")
    for (index, item) in (board.pasteboardItems ?? []).enumerated() {
        print("x4 \(label): item \(index) types: \(item.types.map(\.rawValue).joined(separator: ", "))")
    }
    guard let data = board.data(forType: Board.customData) else {
        print("x4 \(label): no org.chromium.web-custom-data on the pasteboard")
        return false
    }
    print("x4 \(label): org.chromium.web-custom-data \(data.count) bytes")
    do {
        let entries = try Pickle.decode(data)
        print("x4 \(label): decodes by V3: yes, \(entries.count) entries: \(entries.map { "\($0.0) (\($0.1.utf16.count) UTF-16 units)" }.joined(separator: ", "))")
        guard let texty = entries.first(where: { $0.0 == "slack/texty" })?.1 else {
            print("x4 \(label): no slack/texty entry")
            return false
        }
        let object = try JSONSerialization.jsonObject(with: Data(texty.utf8)) as? [String: Any]
        let ops = object?["ops"] as? [[String: Any]] ?? []
        print("x4 \(label): slack/texty parses as JSON with \(ops.count) ops")
        for (index, op) in ops.enumerated() {
            guard let attributes = op["attributes"] as? [String: Any] else { continue }
            let insert = op["insert"]
            let shape = (insert as? String).map { $0.allSatisfy { $0 == "\n" } ? "newline x\($0.count)" : "text" } ?? "embed"
            let attrs = attributes.keys.sorted().map { key -> String in
                let value = attributes[key]!
                let rendered = (try? JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed, .sortedKeys]))
                    .flatMap { String(data: $0, encoding: .utf8) } ?? "\(value)"
                return "\(key)=\(rendered)"
            }
            print("x4 \(label): op \(index) \(shape): \(attrs.joined(separator: ", "))")
        }
        let file = Paths.fixtures.appendingPathComponent("x4-\(label).slack-texty.json")
        try texty.write(to: file, atomically: true, encoding: .utf8)
        print("x4 \(label): full JSON written to \(file.path)")
        print("----- full slack/texty JSON (handback only, not for RESULTS.md) -----")
        print(texty)
        return true
    } catch {
        print("x4 \(label): decodes by V3: no, \(error)")
        return false
    }
}

let args = Array(CommandLine.arguments.dropFirst())
if args.first == "watch" {
    let deadline = Date().addingTimeInterval(Double(args.dropFirst().first ?? "3600") ?? 3600)
    var last = board.changeCount
    var copies = 0
    print("x4 watch: from changeCount \(last) until \(deadline)")
    setvbuf(stdout, nil, _IOLBF, 0)
    while Date() < deadline {
        Thread.sleep(forTimeInterval: 0.25)
        let now = board.changeCount
        guard now != last else { continue }
        last = now
        copies += 1
        print("x4 watch: \(Date()) copy-\(copies)")
        if board.data(forType: Board.customData) == nil {
            print("x4 copy-\(copies): changeCount \(now); no org.chromium.web-custom-data; types: \((board.types ?? []).map(\.rawValue).joined(separator: ", "))")
        } else {
            _ = decode("copy-\(copies)")
        }
    }
    print("x4 watch: stopped at \(Date())")
} else {
    exit(decode(args.first ?? "copy") ? 0 : 1)
}
