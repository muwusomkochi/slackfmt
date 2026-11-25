import AppKit
import Carbon.HIToolbox

/// V11's hotkey, ⌃⌥⌘V, by RegisterEventHotKey, which needs no permission (R14).
final class HotKey {
    private var reference: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, context in
            Unmanaged<HotKey>.fromOpaque(context!).takeUnretainedValue().action()
            return noErr
        }, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &handler)
        RegisterEventHotKey(
            UInt32(kVK_ANSI_V), UInt32(controlKey | optionKey | cmdKey),
            EventHotKeyID(signature: 0x534C_4B46, id: 1), GetApplicationEventTarget(), 0, &reference)
    }
}
