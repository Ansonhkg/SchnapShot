import Carbon
import ThumbnailCore

final class Hotkey {
    private var hotkey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private let action: () -> Void
    init(action: @escaping () -> Void) { self.action = action }
    func register(_ shortcut: CaptureShortcut = .standard) -> Bool {
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, _, data in
            guard let data else { return noErr }
            Unmanaged<Hotkey>.fromOpaque(data).takeUnretainedValue().action()
            return noErr
        }, 1, &type, pointer, &handler)
        guard status == noErr else { return false }
        let id = EventHotKeyID(signature: 0x43533441, id: 1)
        return RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers, id, GetApplicationEventTarget(), 0, &hotkey) == noErr
    }
    deinit { if let hotkey { UnregisterEventHotKey(hotkey) }; if let handler { RemoveEventHandler(handler) } }
}
