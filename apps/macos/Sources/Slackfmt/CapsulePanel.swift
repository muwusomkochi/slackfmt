import AppKit
import SlackfmtKit

final class CapsuleView: NSVisualEffectView {
    init(text: String) {
        super.init(frame: .zero)
        material = .hudWindow
        blendingMode = .behindWindow
        state = .active
        maskImage = Self.mask

        let check = NSImageView(image: NSImage(systemSymbolName: "checkmark", accessibilityDescription: nil) ?? NSImage())
        check.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        check.contentTintColor = .labelColor
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 13, weight: .medium)

        let stack = NSStackView(views: [check, label])
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: Capsule.height),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private static let mask: NSImage = {
        let radius = Capsule.height / 2
        let image = NSImage(size: NSSize(width: Capsule.height + 1, height: Capsule.height), flipped: false) { rect in
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }()
}

/// The done capsule (R32): no focus, no clicks, gone after V9's hold.
final class CapsulePanel: NSPanel {
    private var timer: ExactTimer?

    init() {
        let view = CapsuleView(text: Strings.done)
        super.init(contentRect: NSRect(origin: .zero, size: view.fittingSize), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        contentView = view
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        ignoresMouseEvents = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        animationBehavior = .none
        setAccessibilityElement(false)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func present() {
        let screens = NSScreen.screens.map { Capsule.Screen(frame: $0.frame, visibleFrame: $0.visibleFrame) }
        let size = contentView?.fittingSize ?? frame.size
        guard let place = Capsule.frame(size: size, screens: screens, pointer: NSEvent.mouseLocation) else { return }
        let timing = Capsule.Timing(reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)

        setFrame(place, display: true)
        alphaValue = timing.fadeIn == 0 ? 1 : 0
        orderFrontRegardless()
        StateLog.write("capsule shown")
        fade(to: 1, over: timing.fadeIn, curve: .easeOut)
        timer = ExactTimer(after: timing.fadeIn + timing.hold) { [weak self] in self?.dismiss(timing) }
    }

    private func dismiss(_ timing: Capsule.Timing) {
        fade(to: 0, over: timing.fadeOut, curve: .easeIn)
        timer = ExactTimer(after: timing.fadeOut) { [weak self] in
            self?.orderOut(nil)
            StateLog.write("capsule hidden")
            self?.timer = nil
        }
    }

    private func fade(to alpha: CGFloat, over duration: TimeInterval, curve: CAMediaTimingFunctionName) {
        guard duration > 0 else {
            alphaValue = alpha
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: curve)
            animator().alphaValue = alpha
        }
    }
}
