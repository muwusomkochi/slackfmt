import AppKit

/// The done capsule's place and timing (V9, V17).
public enum Capsule {
    public struct Screen {
        public let frame: CGRect
        public let visibleFrame: CGRect

        public init(frame: CGRect, visibleFrame: CGRect) {
            self.frame = frame
            self.visibleFrame = visibleFrame
        }
    }

    public struct Timing: Equatable {
        public let fadeIn: TimeInterval
        public let hold: TimeInterval
        public let fadeOut: TimeInterval

        public init(fadeIn: TimeInterval, hold: TimeInterval, fadeOut: TimeInterval) {
            self.fadeIn = fadeIn
            self.hold = hold
            self.fadeOut = fadeOut
        }

        public init(reduceMotion: Bool) {
            self.init(fadeIn: reduceMotion ? 0 : 0.12, hold: 1.0, fadeOut: reduceMotion ? 0 : 0.2)
        }
    }

    public static let height: CGFloat = 36
    public static let bottomMargin: CGFloat = 72

    /// Centred on the pointer's screen, its bottom edge above that screen's visible frame.
    public static func frame(size: CGSize, screens: [Screen], pointer: CGPoint) -> CGRect? {
        let holdsPointer = { (screen: Screen) in NSMouseInRect(pointer, screen.frame, false) }
        guard let screen = screens.first(where: holdsPointer) ?? screens.first else { return nil }
        return CGRect(
            x: screen.frame.midX - size.width / 2,
            y: screen.visibleFrame.minY + bottomMargin,
            width: size.width,
            height: size.height)
    }
}
