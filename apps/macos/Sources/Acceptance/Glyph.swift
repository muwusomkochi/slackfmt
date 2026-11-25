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

    static func save(_ image: CGImage, _ path: String) {
        try? NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
    }

    /// How well each symbol matches the screenshot's glyph, best first: the share of each one's pixels that lie within a pixel of
    /// the other's, since a thin stroke that lands half a pixel off overlaps little of itself.
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
        func near(_ mask: [Bool], _ x: Int, _ y: Int) -> Bool {
            for ny in max(0, y - 1)...min(side - 1, y + 1) {
                for nx in max(0, x - 1)...min(side - 1, x + 1) where mask[ny * side + nx] { return true }
            }
            return false
        }
        func covered(_ these: [Bool], by those: [Bool], _ dx: Int, _ dy: Int) -> Double {
            var total = 0, hits = 0
            for y in 0..<side {
                for x in 0..<side where these[y * side + x] {
                    total += 1
                    let (sx, sy) = (x + dx, y + dy)
                    if sx >= 0, sy >= 0, sx < side, sy < side, near(those, sx, sy) { hits += 1 }
                }
            }
            return total == 0 ? 0 : Double(hits) / Double(total)
        }
        var score = 0.0
        for dy in -4...4 {
            for dx in -4...4 {
                let (p, q) = (covered(a, by: b, dx, dy), covered(b, by: a, -dx, -dy))
                if p + q > 0 { score = max(score, 2 * p * q / (p + q)) }
            }
        }
        return score
    }
}
