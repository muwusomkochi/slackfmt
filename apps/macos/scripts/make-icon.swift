// Writes Resources/AppIcon.icns: the hash, white, on a graphite rounded square (#1d1d1f), on the macOS icon grid (docs/DS.md).
// Run from apps/macos: swift scripts/make-icon.swift
import AppKit

func draw(pixels: Int) -> NSBitmapImageRep {
    let size = CGFloat(pixels)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    // The macOS grid: an 824 pt square with a 185.4 pt radius on a 1024 pt canvas.
    let square = NSRect(x: 0, y: 0, width: size, height: size).insetBy(dx: size * 100 / 1024, dy: size * 100 / 1024)
    NSColor(srgbRed: 0x1D / 255, green: 0x1D / 255, blue: 0x1F / 255, alpha: 1).setFill()
    NSBezierPath(roundedRect: square, xRadius: size * 185.4 / 1024, yRadius: size * 185.4 / 1024).fill()
    let configuration = NSImage.SymbolConfiguration(pointSize: size * 0.4, weight: .semibold)
        .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
    let hash = NSImage(systemSymbolName: "number", accessibilityDescription: nil)!.withSymbolConfiguration(configuration)!
    hash.draw(in: NSRect(x: (size - hash.size.width) / 2, y: (size - hash.size.height) / 2, width: hash.size.width, height: hash.size.height))
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let iconset = URL(fileURLWithPath: "build/AppIcon.iconset", isDirectory: true)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
        try draw(pixels: base * scale).representation(using: .png, properties: [:])!.write(to: iconset.appendingPathComponent(name))
    }
}
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", "Resources/AppIcon.icns"]
try iconutil.run()
iconutil.waitUntilExit()
print("wrote Resources/AppIcon.icns")
