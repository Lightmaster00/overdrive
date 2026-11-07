import AppKit
import SwiftUI

@main
struct OverdriveMain {
    static func main() {
        MainActor.assumeIsolated {
            let app = NSApplication.shared
            let delegate = AppDelegate()
            app.delegate = delegate
            app.setActivationPolicy(.accessory)
            withExtendedLifetime(delegate) { app.run() }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private var manager: ToolManager { .shared }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = Brand.menuBarIcon()
        item.button?.setAccessibilityLabel("Overdrive")
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        statusItem = item

        manager.startEnabledTweaks()
        Updater.startAutomaticChecks()

        if !UserDefaults.standard.bool(forKey: "app.launchedBefore") {
            UserDefaults.standard.set(true, forKey: "app.launchedBefore")
            SettingsWindow.shared.show()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        manager.stopAll()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        SettingsWindow.shared.show()
        return false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    // MARK: Menu (rebuilt each time it opens, so states are current)

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        var first = true
        for category in ToolCategory.allCases {
            let actions = manager.tools(in: category).filter { $0.kind == .action && manager.isOn($0) }
            guard !actions.isEmpty else { continue }
            if !first { menu.addItem(.separator()) }
            first = false
            menu.addItem(NSMenuItem.sectionHeader(title: category.title))
            for tool in actions { menu.addItem(item(for: tool)) }
        }

        if let shortcutsTool = manager.tool("utilities.shortcuts"), manager.isOn(shortcutsTool) {
            UtilityTools.refreshShortcuts()
            let item = NSMenuItem(title: S.shortcutsApp, action: nil, keyEquivalent: "")
            item.image = NSImage(systemSymbolName: "square.stack.3d.up", accessibilityDescription: nil)
            let sub = NSMenu()
            if UtilityTools.shortcuts.isEmpty {
                sub.addItem(NSMenuItem(title: S.noShortcuts, action: nil, keyEquivalent: ""))
            }
            for name in UtilityTools.shortcuts {
                let entry = NSMenuItem(title: name, action: #selector(runShortcut(_:)), keyEquivalent: "")
                entry.target = self
                entry.representedObject = name
                sub.addItem(entry)
            }
            item.submenu = sub
            menu.addItem(.separator())
            menu.addItem(item)
        }

        menu.addItem(.separator())
        let settings = NSMenuItem(title: S.settingsMenu, action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        let updates = NSMenuItem(title: S.checkForUpdates, action: #selector(checkUpdates), keyEquivalent: "")
        updates.target = self
        menu.addItem(updates)
        menu.addItem(NSMenuItem(title: S.quit, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    private func item(for tool: Tool) -> NSMenuItem {
        let item = NSMenuItem(title: tool.title, action: #selector(runTool(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = tool.id
        item.image = NSImage(systemSymbolName: tool.symbol, accessibilityDescription: nil)
        if let state = tool.state { item.state = state() ? .on : .off }
        if let combo = ShortcutStore.combo(for: tool.id), let key = combo.menuKey {
            item.keyEquivalent = key
            item.keyEquivalentModifierMask = combo.menuModifiers
        }
        return item
    }

    @objc private func runTool(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String, let tool = manager.tool(id) else { return }
        // Let the menu close first (screen captures must not include it).
        DispatchQueue.main.async { MainActor.assumeIsolated { self.manager.run(tool) } }
    }

    @objc private func runShortcut(_ sender: NSMenuItem) {
        if let name = sender.representedObject as? String { UtilityTools.runShortcut(name) }
    }

    @objc private func openSettings() { SettingsWindow.shared.show() }
    @objc private func checkUpdates() { Updater.checkNow() }
}
