// X5: registers V11's hotkey, Ctrl-Opt-Cmd-V, with RegisterEventHotKey as the app would (no
// options), prints the status, then logs each press it receives until the time runs out.
// Build and run: swiftc -O probes/loop1/x5-hotkey.swift -o probes/loop1/build/x5-hotkey && probes/loop1/build/x5-hotkey [seconds]
import AppKit
import Carbon.HIToolbox

let seconds = Double(CommandLine.arguments.dropFirst().first ?? "1800") ?? 1800
let stamp = { () -> String in
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd HH:mm:ss zzz"
    return f.string(from: Date())
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
let handler = InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
    print("\(stamp()) x5-hotkey received Ctrl-Opt-Cmd-V")
    fflush(stdout)
    return noErr
}, 1, &spec, nil, nil)

var ref: EventHotKeyRef?
let modifiers = UInt32(controlKey | optionKey | cmdKey)
let status = RegisterEventHotKey(UInt32(kVK_ANSI_V), modifiers, EventHotKeyID(signature: 0x534C_4B46, id: 1),
                                 GetApplicationEventTarget(), 0, &ref)
print("\(stamp()) InstallEventHandler status \(handler); RegisterEventHotKey(kVK_ANSI_V, controlKey|optionKey|cmdKey, options 0) status \(status)\(status == noErr ? " (noErr: registered)" : "")")
fflush(stdout)
guard status == noErr else { exit(1) }

DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
    UnregisterEventHotKey(ref)
    print("\(stamp()) x5-hotkey: \(Int(seconds)) s elapsed, unregistered")
    exit(0)
}
app.run()
