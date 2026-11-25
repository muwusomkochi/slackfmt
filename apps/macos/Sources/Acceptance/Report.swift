import Foundation

/// One acceptance row's checks, printed as they run.
final class Report {
    let row: String
    private(set) var failures = 0
    private var checks = 0

    init(_ row: String) {
        self.row = row
        print("== \(row)")
    }

    func check(_ passed: Bool, _ what: String, _ detail: String = "") {
        checks += 1
        if !passed { failures += 1 }
        print("\(passed ? "ok  " : "FAIL") \(what)\(detail.isEmpty ? "" : ": \(detail)")")
    }

    func note(_ text: String) { print("note \(text)") }

    func finish() {
        print("\(row) \(failures == 0 ? "PASSED" : "FAILED"): \(checks - failures) of \(checks) checks")
    }
}

func median(_ values: [Double]) -> Double {
    let sorted = values.sorted()
    let middle = sorted.count / 2
    return sorted.count % 2 == 1 ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2
}

func format(_ value: Double) -> String { String(format: "%.1f", value) }
