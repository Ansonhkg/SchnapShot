import SwiftUI
import ThumbnailCore

struct EditorView: View {
    @ObservedObject var model: AppModel
    private let surface = Color(red: 0.13, green: 0.14, blue: 0.17)
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                if !model.account.isEmpty {
                    Label("Codex connected", systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button { model.settingsPresented = true } label: { Image(systemName: "gearshape") }
                    .help("Settings").accessibilityLabel("Settings")
                Button { model.sizePresented.toggle() } label: {
                    HStack(spacing: 8) { Text("\(model.activePreset.name) · \(model.size.label)").monospacedDigit(); Image(systemName: "chevron.down").font(.caption) }
                }
                .disabled(model.busy)
                .popover(isPresented: $model.sizePresented, arrowEdge: .bottom) { PresetPopover(model: model) }
                .accessibilityLabel("Preset \(model.activePreset.name), \(model.size.label)")
            }.padding(.horizontal, 20).padding(.vertical, 12)
            HStack(alignment: .top, spacing: 10) {
                Text("Prompt").foregroundStyle(.secondary)
                Text(model.activePreset.prompt).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                Text(model.size.ratioLabel).monospacedDigit().foregroundStyle(.secondary)
            }.font(.caption).padding(.horizontal, 20).padding(.bottom, 12)
            ZStack {
                surface
                if model.phase == .welcome || (model.account.isEmpty && model.phase != .connecting) {
                    welcome
                } else if let image = model.preview {
                    Image(nsImage: image).resizable().aspectRatio(contentMode: .fit)
                        .padding(28).opacity(model.phase == .generating ? 0.38 : 1)
                        .accessibilityLabel(model.phase == .generating ? "Captured screenshot" : "Thumbnail preview")
                    if model.phase == .generating {
                        VStack(spacing: 16) {
                            ProgressView().controlSize(.large)
                            Text(model.status).font(.headline)
                            Text(model.size.label).foregroundStyle(.secondary).monospacedDigit()
                        }.padding(24).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                    }
                    if model.copied {
                        VStack { Spacer(); Label("Copied to clipboard", systemImage: "checkmark.circle.fill")
                            .padding(.horizontal, 18).padding(.vertical, 12).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10)).padding(.bottom, 36) }
                    }
                } else if model.phase == .connecting {
                    VStack(spacing: 16) { ProgressView(); Text("Connecting to Codex…").foregroundStyle(.secondary) }
                } else {
                    VStack(spacing: 18) {
                        Image(systemName: "viewfinder").font(.system(size: 48, weight: .light)).foregroundStyle(.blue)
                        Text("Your next image starts here.").font(.title2).fontWeight(.medium)
                        Text("Capture an area. Codex uses your saved preset.").foregroundStyle(.secondary)
                        Button("Capture area  \(model.shortcut.label)") { model.capture() }.buttonStyle(.borderedProminent).controlSize(.large)
                        Button("Open an image…") { model.openImage() }.buttonStyle(.plain).foregroundStyle(.secondary)
                    }
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
            if let error = model.error {
                VStack(alignment: .leading, spacing: 8) {
                    Label(error, systemImage: "exclamationmark.triangle").font(.callout).textSelection(.enabled)
                    HStack {
                        if error.contains("Screen") { Button("Open System Settings") { model.showPrivacySettings() } }
                        if model.sourceURL != nil && !model.account.isEmpty { Button("Try again") { model.generate() } }
                        Button("Retry connection") { model.connect() }
                        Spacer()
                        Button("Dismiss") { model.error = nil }
                    }
                }.padding(16).background(Color.orange.opacity(0.13))
            }
            if !model.shortcutAvailable {
                Text("\(model.shortcut.label) could not be registered. Choose another shortcut in Settings or use the capture button.")
                    .font(.caption).foregroundStyle(.orange).padding(8)
            }
            if let outputSize = model.outputSize, let name = model.outputPresetName, model.canCopy {
                Text("Current image: \(name) · \(outputSize.label) · \(outputSize.ratioLabel)")
                    .font(.caption).foregroundStyle(.secondary).padding(.bottom, 8)
            }
            Divider()
            HStack(spacing: 10) {
                Button { model.capture() } label: { Label("New capture", systemImage: "camera") }
                    .disabled(model.busy || model.account.isEmpty)
                Text(model.status).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                Spacer()
                if model.phase == .generating || model.phase == .capturing { Button("Cancel") { model.cancel() }.keyboardShortcut(.cancelAction) }
                else {
                    Button("Save…") { model.save() }.disabled(!model.canCopy).keyboardShortcut("s", modifiers: .command)
                    Button { model.copy() } label: { Label(model.copied ? "Copied" : "Copy", systemImage: model.copied ? "checkmark" : "doc.on.doc") }
                        .buttonStyle(.borderedProminent).disabled(!model.canCopy).keyboardShortcut("c", modifiers: .command)
                }
            }.padding(16)
        }
        .frame(minWidth: 640, minHeight: 480)
        .background(Color(red: 0.1, green: 0.11, blue: 0.13))
        .preferredColorScheme(.dark)
        .tint(.blue)
        .sheet(isPresented: $model.settingsPresented) { ShortcutSettings(model: model) }
    }

    private var welcome: some View {
        VStack(spacing: 18) {
            Image(nsImage: NSApp.applicationIconImage).resizable().interpolation(.high).frame(width: 88, height: 88)
                .accessibilityLabel("SchnapShot")
            Text("From screenshot to anything").font(.title).fontWeight(.medium)
            Text("Choose a preset. Capture an area. Copy and go.").foregroundStyle(.secondary)
            if let code = model.deviceCode { Text(code).font(.title2.monospaced()).textSelection(.enabled) }
            Button(model.loginInProgress ? "Continue in browser" : "Connect Codex") { model.login() }
                .buttonStyle(.borderedProminent).controlSize(.large)
            if model.loginInProgress { Button("Cancel sign-in") { model.cancelLogin() } }
            else { Button("Use a device code instead") { model.login(device: true) }.buttonStyle(.plain).font(.caption).foregroundStyle(.secondary) }
            Text("Selected screenshots are sent to OpenAI. Generation uses your Codex limits.\nSign-in is managed by Codex and stored in your Mac’s Keychain.")
                .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.top, 12)
        }.padding(32)
    }
}
