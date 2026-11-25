import Foundation

enum FirstRun {
    private static let key = "hasRunBefore"

    /// True once, until `--reset-first-run`.
    static func claim() -> Bool {
        guard !UserDefaults.standard.bool(forKey: key) else { return false }
        UserDefaults.standard.set(true, forKey: key)
        return true
    }

    static func reset() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
