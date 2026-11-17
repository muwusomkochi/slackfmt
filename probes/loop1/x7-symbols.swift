// X7: do V16's SF Symbols exist? Run: swift probes/loop1/x7-symbols.swift
// Also prints the macOS release each symbol first shipped in, from the system's own
// CoreGlyphs availability table, since this Mac isn't on macOS 14.
import AppKit

let names = ["number", "checkmark", "nosign"]
let table = NSDictionary(contentsOfFile: "/System/Library/CoreServices/CoreGlyphs.bundle/Contents/Resources/name_availability.plist")
let symbols = table?["symbols"] as? [String: String] ?? [:]
let releases = table?["year_to_release"] as? [String: [String: String]] ?? [:]

var missing = 0
for name in names {
    let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
    let since = symbols[name].map { year in "symbol set \(year), first on macOS \(releases[year]?["macOS"] ?? "unknown")" } ?? "not in the availability table"
    if let image {
        print("\(name): image, \(Int(image.size.width))x\(Int(image.size.height)) pt, template \(image.isTemplate); \(since)")
    } else {
        missing += 1
        print("\(name): nil; \(since)")
    }
}
print(missing == 0 ? "all three returned an image" : "\(missing) returned nil")
exit(missing == 0 ? 0 : 1)
