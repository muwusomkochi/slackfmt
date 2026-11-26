import AppKit
import Carbon.HIToolbox

/// A4's copies from real apps. Finder puts the file's icon, as public.tiff, beside its file URL, and V25 picks the file.
func rowA4Apps(_ app: App, _ trigger: Trigger, only: String) async {
    let image = NSTemporaryDirectory() + "slackfmt-accept/made-up-image.png"
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 64, pixelsHigh: 64, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: image))

    func copy(_ bundle: String, _ open: [String], close: Bool) -> Bool {
        _ = output("/usr/bin/open", open)
        for _ in 0..<50 {
            pause(0.1)
            if NSWorkspace.shared.frontmostApplication?.bundleIdentifier == bundle { break }
        }
        guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == bundle else {
            print("note front instead: \(NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "?")")
            return false
        }
        pause(1.2)
        let before = NSPasteboard.general.changeCount
        if bundle == "com.apple.finder" {
            chooseCopyInFinder()
        } else {
            Input.key(kVK_ANSI_C, flags: .maskCommand)
        }
        let copied = Clipboard.waitForChange(after: before, timeout: 3_000) != nil
        pause(0.5)
        if close {
            Input.key(kVK_ANSI_W, flags: .maskCommand)
            pause(0.5)
        }
        return copied
    }
    let text = NSTemporaryDirectory() + "slackfmt-accept/made-up.txt"
    try? "made-up text\n".write(toFile: text, atomically: true, encoding: .utf8)
    for (name, bundle, open, close, reason) in [
        ("a text file copied in Finder", "com.apple.finder", ["-R", text], true, "Files can't be converted"),
        ("an image copied from Preview", "com.apple.Preview", ["-a", "Preview", image], true, "Images can't be converted"),
    ] where name.contains(only) {
        guard copy(bundle, open, close: close) else {
            print("FAIL A4 \(name): nothing was copied")
            continue
        }
        await rowRefusedAsCopied(app, trigger, row: "A4 \(name)", reason: reason, glyph: false)
    }
}

/// Finder's Edit > Copy "name", whose title carries the selected file's name.
private func chooseCopyInFinder() {
    guard let finder = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first,
          let bar = AX.element(AXUIElementCreateApplication(finder.processIdentifier), "AXMenuBar"),
          let edit = AX.children(bar).first(where: { AX.string($0, "AXTitle") == "Edit" }) else {
        return print("note Finder's menu bar wasn't readable")
    }
    AX.press(edit)
    pause(0.5)
    let items = AX.children(edit).first.map(AX.children) ?? []
    if let copy = items.first(where: { AX.string($0, "AXTitle")?.hasPrefix("Copy") == true && AX.attribute($0, "AXEnabled") as? Bool == true }) {
        print("note Finder's menu item: \(AX.string(copy, "AXTitle") ?? "")")
        AX.press(copy)
    } else {
        print("note Finder's Edit menu: \(items.compactMap { AX.string($0, "AXTitle") }.joined(separator: " · "))")
        Menus.cancel()
    }
}
