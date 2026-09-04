import SwiftUI
import ThumbnailCore

struct PresetForm: View {
    @ObservedObject var model: AppModel
    let preset: GenerationPreset
    let close: () -> Void
    @State private var draft = GenerationPreset.thumbnail
    @State private var width = "1200"
    @State private var height = "630"
    @State private var saveError: String?
    @State private var saved = false
    private var candidate: GenerationPreset {
        var value = draft
        value.size = .init(width: Int(width) ?? 0, height: Int(height) ?? 0)
        return value
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(model.library.presets.contains(where: { $0.id == preset.id }) ? "Edit preset" : "New preset").font(.headline)
                    Spacer()
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Name").font(.caption).foregroundStyle(.secondary)
                    TextField("e.g. App icon", text: $draft.name).textFieldStyle(.roundedBorder).accessibilityLabel("Preset name")
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Prompt").font(.caption).foregroundStyle(.secondary)
                    TextEditor(text: $draft.prompt).font(.body).frame(height: 100)
                        .padding(6).background(Color.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.35)))
                        .accessibilityLabel("Generation prompt")
                    Text("Describe what to create. Output dimensions are added automatically.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Divider()
                HStack { Text("Output size").font(.headline); Spacer(); Text("Ratio \(candidate.size.ratioLabel)").monospacedDigit().foregroundStyle(.secondary) }
                HStack(spacing: 6) {
                    ForEach(OutputSize.presets, id: \.0) { label, value in
                        Button(label) { width = String(value.width); height = String(value.height) }
                            .font(.caption).frame(maxWidth: .infinity)
                    }
                }
                HStack(alignment: .bottom, spacing: 10) {
                    VStack(alignment: .leading, spacing: 5) { Text("Width").font(.caption); TextField("Width", text: $width).accessibilityLabel("Width in pixels") }
                    Text("×").padding(.bottom, 5)
                    VStack(alignment: .leading, spacing: 5) { Text("Height").font(.caption); TextField("Height", text: $height).accessibilityLabel("Height in pixels") }
                    Text("px").foregroundStyle(.secondary).padding(.bottom, 5)
                }.textFieldStyle(.roundedBorder)
                Text("Sent with prompt: \(candidate.size.width)x\(candidate.size.height) pixels · \(candidate.size.ratioLabel)")
                    .font(.caption).foregroundStyle(.secondary)
                if let validation = candidate.validationError { Text(validation).font(.caption).foregroundStyle(.orange) }
                if let saveError { Text(saveError).font(.caption).foregroundStyle(.orange) }
                if saved { Label("Preset saved. Used for future captures.", systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(.green) }
                Divider()
                HStack {
                    Button("Cancel", action: close)
                    Spacer()
                    Button("Save preset") { save(generate: false) }
                        .buttonStyle(.borderedProminent).disabled(candidate.validationError != nil || model.busy)
                }
                Text("Saving does not generate an image or use credits.")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(20)
        }.frame(width: 430).frame(maxHeight: 660)
            .onAppear { load(preset) }
            .onChange(of: candidate) { _, _ in saved = false; saveError = nil }
    }
    private func load(_ preset: GenerationPreset) {
        draft = preset; width = String(preset.size.width); height = String(preset.size.height)
        saved = false; saveError = nil
    }
    private func save(generate: Bool) {
        do {
            try model.savePreset(candidate)
            draft = model.activePreset
            saved = true; saveError = nil
            close()
        } catch { saveError = error.localizedDescription }
    }
}

struct PresetPopover: View {
    @ObservedObject var model: AppModel
    @State private var editing: GenerationPreset?
    var body: some View {
        Group {
            if let editing {
                PresetForm(model: model, preset: editing) { self.editing = nil }.id(editing.id)
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Presets").font(.title2).fontWeight(.semibold)
                        Spacer()
                        Button { add() } label: { Image(systemName: "plus") }
                            .help("Add preset").accessibilityLabel("Add preset")
                    }
                    Text("Click a card to use it. Hover to edit.").font(.caption).foregroundStyle(.secondary)
                    ScrollView {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                            ForEach(model.library.presets) { preset in
                                PresetCard(preset: preset, selected: model.library.selectedID == preset.id,
                                    select: { model.selectPreset(preset.id) }, edit: { editing = preset })
                            }
                            Button { add() } label: {
                                VStack(spacing: 12) { Image(systemName: "plus").font(.title2); Text("New preset").font(.callout) }
                                    .frame(maxWidth: .infinity).frame(height: 176)
                                    .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
                            }.buttonStyle(.plain).accessibilityLabel("New preset")
                        }.padding(2)
                    }.frame(maxHeight: 390)
                    HStack {
                        Text("Using \(model.activePreset.name)").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button("Done") { model.sizePresented = false }
                        if model.sourceURL != nil {
                            Button("Generate") { model.sizePresented = false; model.generate() }
                                .buttonStyle(.borderedProminent).disabled(!model.canGenerate)
                        }
                    }
                }.padding(20).frame(width: 600)
            }
        }.disabled(model.busy)
    }
    private func add() {
        editing = GenerationPreset(name: "", prompt: "Create an image inspired by this screenshot.", size: model.size)
    }
}

private struct PresetCard: View {
    let preset: GenerationPreset
    let selected: Bool
    let select: () -> Void
    let edit: () -> Void
    @State private var hovering = false
    @FocusState private var focused: Bool
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: select) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: selected ? "checkmark.circle.fill" : "rectangle")
                            .foregroundStyle(selected ? Color.blue : Color.secondary)
                        Spacer()
                    }.frame(height: 24)
                    Text(preset.name).font(.headline).lineLimit(1)
                    Text("\(preset.size.label) · \(preset.size.ratioLabel)").font(.caption).monospacedDigit().foregroundStyle(.secondary)
                    Text(preset.prompt).font(.caption).foregroundStyle(.secondary).lineLimit(3)
                    Spacer(minLength: 0)
                }.padding(12).frame(maxWidth: .infinity, alignment: .leading).frame(height: 176)
                    .background(selected ? Color.blue.opacity(0.13) : Color.white.opacity(hovering ? 0.08 : 0.04), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected ? Color.blue : Color.clear, lineWidth: 2))
            }.buttonStyle(.plain).focused($focused)
                .accessibilityLabel("Use \(preset.name), \(preset.size.label)\(selected ? ", selected" : "")")
                .contextMenu { Button("Edit preset", action: edit) }
            Button("Edit", action: edit).font(.caption).padding(10)
                .opacity(hovering || focused ? 1 : 0)
                .accessibilityLabel("Edit \(preset.name)")
        }.onHover { hovering = $0 }
    }
}
