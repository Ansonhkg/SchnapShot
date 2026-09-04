import AppKit
import SwiftUI
import ThumbnailCore

@main
struct SchnapShotMain {
    @MainActor static func main() {
        let app = NSApplication.shared
        AppMigration.preparePreferences()
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuItemValidation {
    let model = AppModel()
    private var window: NSWindow!
    private var statusItem: NSStatusItem!
    private var hotkey: Hotkey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"), let icon = NSImage(contentsOf: iconURL) {
            NSApp.applicationIconImage = icon
        }
        buildMenus()
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 980, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "SchnapShot"
        window.minSize = NSSize(width: 640, height: 480)
        window.isReleasedWhenClosed = false; window.delegate = self
        window.appearance = NSAppearance(named: .darkAqua)
        window.contentView = NSHostingView(rootView: EditorView(model: model))
        window.center(); window.setFrameAutosaveName("SchnapShotEditor")
        model.showWindow = { [weak self] in self?.showEditor() }
        model.hideWindow = { NSApp.hide(nil) }
        hotkey = Hotkey { [weak self] in Task { @MainActor in
            guard let self, !self.model.settingsPresented else { return }; self.model.capture()
        } }
        model.shortcutAvailable = hotkey?.register(model.shortcut) == true
        model.updateShortcut = { [weak self] value in
            guard let self else { return false }
            if value == self.model.shortcut && self.model.shortcutAvailable { return true }
            let replacement = Hotkey { [weak self] in Task { @MainActor in
                guard let self, !self.model.settingsPresented else { return }; self.model.capture()
            } }
            guard replacement.register(value) else { return false }
            self.hotkey = replacement
            self.refreshShortcutLabels(value.label)
            return true
        }
        showEditor(); model.connect()
    }

    private func buildMenus() {
        let menu = NSMenu()
        let appItem = NSMenuItem(); let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About SchnapShot", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        let settings = NSMenuItem(title: "Settings…", action: #selector(settings), keyEquivalent: ",")
        settings.target = self; appMenu.addItem(settings)
        appMenu.addItem(withTitle: "Quit SchnapShot", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu; menu.addItem(appItem)
        let file = NSMenuItem(title: "File", action: nil, keyEquivalent: ""); file.submenu = actionsMenu(title: "File")
        let save = NSMenuItem(title: "Save image…", action: #selector(saveDocument(_:)), keyEquivalent: "s")
        save.target = self; file.submenu?.insertItem(save, at: 2)
        menu.addItem(file)
        let edit = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        let editMenu = NSMenu(title: "Edit")
        for (title, selector, key) in [("Cut", "cut:", "x"), ("Copy", "copy:", "c"), ("Paste", "paste:", "v"), ("Select All", "selectAll:", "a")] {
            editMenu.addItem(withTitle: title, action: Selector(selector), keyEquivalent: key)
        }
        edit.submenu = editMenu; menu.addItem(edit); NSApp.mainMenu = menu
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "viewfinder", accessibilityDescription: "SchnapShot")
        statusItem.button?.toolTip = "SchnapShot · Capture area (\(model.shortcut.label))"
        statusItem.menu = actionsMenu()
    }

    private func actionsMenu(title: String = "SchnapShot") -> NSMenu {
        let menu = NSMenu(title: title)
        for (name, selector) in [("Capture area  \(model.shortcut.label)", #selector(capture)), ("Open image…", #selector(openImage)),
            ("Show editor", #selector(showEditor)), ("Presets & prompt…", #selector(outputSize)),
            ("Capture shortcut…", #selector(settings)), ("Show saved captures", #selector(showCaptures)), ("Sign out of SchnapShot", #selector(signOut))] {
            let item = NSMenuItem(title: name, action: selector, keyEquivalent: ""); item.target = self; menu.addItem(item)
        }
        menu.addItem(.separator()); menu.addItem(withTitle: "Quit SchnapShot", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        return menu
    }

    @objc func capture() { model.capture() }
    @objc func settings() { showEditor(); model.sizePresented = false; model.settingsPresented = true }
    private func refreshShortcutLabels(_ label: String) {
        for menu in [NSApp.mainMenu?.items.first(where: { $0.title == "File" })?.submenu, statusItem.menu].compactMap({ $0 }) {
            menu.items.first(where: { $0.action == #selector(capture) })?.title = "Capture area  \(label)"
        }
        statusItem.button?.toolTip = "SchnapShot · Capture area (\(label))"
    }
    @objc func openImage() { showEditor(); model.openImage() }
    @objc func outputSize() { showEditor(); if !model.busy { model.sizePresented = true } }
    @objc func showCaptures() { model.revealStorage() }
    @objc func signOut() { model.signOut() }
    @objc func copy(_ sender: Any?) { model.copy() }
    @objc func saveDocument(_ sender: Any?) { model.save() }
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(copy(_:)) || menuItem.action == #selector(saveDocument(_:)) { return model.canCopy }
        if menuItem.action == #selector(capture) || menuItem.action == #selector(openImage) || menuItem.action == #selector(signOut) { return !model.busy && !model.account.isEmpty }
        if menuItem.action == #selector(outputSize) { return !model.busy }
        return true
    }
    @objc func showEditor() { window?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showEditor(); return true }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationWillTerminate(_ notification: Notification) { model.shutdown() }
}
