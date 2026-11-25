import AppKit
import ScreenCaptureKit

/// Tells which V16 symbol a screenshot of the status item shows.
enum Glyph {
    static let names = ["number", "checkmark", "nosign"]
    private static let side = 48

    static func capture(_ frame: CGRect) async -> CGImage? {
        let rect = CGRect(x: frame.midX - 12, y: frame.midY - 12, width: 24, height: 24)
        guard #available(macOS 15.2, *) else { return nil }
        return try? await SCScreenshotManager.captureImage(in: rect)
    }

    /// Each symbol's overlap (intersection over union) with the screenshot's glyph, best first.
    static func scores(_ image: CGImage) -> [(name: String, score: Double)] {
        let seen = mask(image)
        return names.map { name in (name, best(seen, mask(reference(name)))) }.sorted { $0.score > $1.score }
    }

    private static func reference(_ name: String) -> CGImage {
        let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil)!
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 16, weight: .regular))!
        let fit = min(1, 18 / symbol.size.width, 18 / symbol.size.height)
        let size = NSSize(width: symbol.size.width * fit * 2, height: symbol.size.height * fit * 2)
        let rep = bitmap()
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: side, height: side).fill()
        symbol.draw(in: NSRect(x: (CGFloat(side) - size.width) / 2, y: (CGFloat(side) - size.height) / 2, width: size.width, height: size.height))
        NSGraphicsContext.restoreGraphicsState()
        return rep.cgImage!
    }

    private static func bitmap() -> NSBitmapImageRep {
        NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side, bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    }

    /// The pixels that stand out from the background, which is the image's median brightness.
    private static func mask(_ image: CGImage) -> [Bool] {
        let rep = bitmap()
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.current?.cgContext.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
        NSGraphicsContext.restoreGraphicsState()
        var light: [Double] = []
        for y in 0..<side {
            for x in 0..<side {
                let color = rep.colorAt(x: x, y: y) ?? .clear
                light.append(0.3 * color.redComponent + 0.6 * color.greenComponent + 0.1 * color.blueComponent)
            }
        }
        let background = light.sorted()[light.count / 2]
        let furthest = light.map { abs($0 - background) }.max() ?? 1
        return light.map { abs($0 - background) > 0.5 * furthest && furthest > 0.1 }
    }

    private static func best(_ a: [Bool], _ b: [Bool]) -> Double {
        var score = 0.0
        for dy in -4...4 {
            for dx in -4...4 {
                var both = 0, either = 0
                for y in 0..<side {
                    for x in 0..<side {
                        let (sx, sy) = (x + dx, y + dy)
                        let p = a[y * side + x]
                        let q = sx >= 0 && sy >= 0 && sx < side && sy < side && b[sy * side + sx]
                        if p && q { both += 1 }
                        if p || q { either += 1 }
                    }
                }
                if either > 0 { score = max(score, Double(both) / Double(either)) }
            }
        }
        return score
    }
}
