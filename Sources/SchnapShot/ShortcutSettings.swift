import SwiftUI
import AppKit
import Carbon
import ThumbnailCore

struct ShortcutSettings: View {
    @ObservedObject var model: AppModel
    @State private var draft = CaptureShortcut.standard
    @State private var recording = false
    @State private var monitor: Any?
    @State private var message: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Capture shortcut").font(.title2).fontWeight(.semibold)
            Text("Click Record, then press a key with Command, Option, or Control. Escape cancels recording.")
                .foregroundStyle(.secondary)
            HStack {
                Text(recording ? "Press your shortcut…" : draft.label).font(.title2.monospaced()).frame(maxWidth: .infinity)
                Button(recording ? "Cancel recording" : "Record shortcut") { recording ? stop() : start() }
            }.padding(16).background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
            Button("Restore default (⌥⌘4)") { stop(); draft = .standard; message = nil }
            Text("macOS screenshot shortcuts may already be reserved. Choose a different combination if registration fails.").font(.caption).foregroundStyle(.secondary)
            if let message { Text(message).foregroundStyle(.orange).font(.callout) }
            HStack {
                Button("Cancel") { model.settingsPresented = false }
                Spacer()
                Button("Save shortcut") {
                    do { try model.saveShortcut(draft); model.settingsPresented = false }
                    catch { message = error.localizedDescription }
                }.buttonStyle(.borderedProminent).disabled(recording || model.busy)
            }
        }.padding(24).frame(width: 440)
            .onAppear { draft = model.shortcut }
            .onDisappear { stop() }
    }
    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil; recording = false
    }
    private func start() {
        recording = true; message = nil
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { stop(); return nil }
            let flags = event.modifierFlags
            var modifiers: UInt32 = 0
            for (flag, carbon) in [(NSEvent.ModifierFlags.command, cmdKey), (.option, optionKey), (.control, controlKey), (.shift, shiftKey)] {
                if flags.contains(flag) { modifiers |= UInt32(carbon) }
            }
            let label = event.charactersIgnoringModifiers?.uppercased() ?? ""
            let value = CaptureShortcut(keyCode: UInt32(event.keyCode), modifiers: modifiers, keyLabel: label)
            guard value.isValid, !label.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
                message = "Use a letter, number, or symbol with Command, Option, or Control."; return nil
            }
            draft = value; stop(); return nil
        }
    }
}
