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
    //
    // Header, then the on/off controls as tiles (like Control Center, the menu stays open),
    // then one-shot actions grouped by category, the running tweaks, and the app's own items.

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let shown = manager.tools.filter { $0.kind == .action && manager.isOn($0) }
        let toggles = shown.filter { $0.state != nil }
        let actions = shown.filter { $0.state == nil }
        let tweaks = manager.tools.filter { $0.kind == .tweak }

        menu.addItem(hosted(MenuHeader(activeTweaks: tweaks.filter { manager.isOn($0) }.count)))

        if !toggles.isEmpty {
            // States are read here, before SwiftUI lays anything out: some of them run a command
            // and wait for it, which must never happen inside a SwiftUI update.
            menu.addItem(hosted(QuickTiles(initial: QuickTiles.read(toggles.map(\.id)))))
        }

        if !actions.isEmpty {
            menu.addItem(.separator())
            menu.addItem(NSMenuItem.sectionHeader(title: S.actionsHeader))
            for category in ToolCategory.allCases {
                let inCategory = actions.filter { $0.category == category }
                guard !inCategory.isEmpty else { continue }
                if inCategory.count == 1 {
                    menu.addItem(item(for: inCategory[0]))
                    continue
                }
                let parent = NSMenuItem(title: category.title, action: nil, keyEquivalent: "")
                parent.image = Self.symbol(category.symbol)
                let sub = NSMenu()
                for tool in inCategory { sub.addItem(item(for: tool)) }
                parent.submenu = sub
                menu.addItem(parent)
            }
        }

        if toggles.isEmpty && actions.isEmpty {
            let empty = NSMenuItem(title: S.menuEmpty, action: #selector(openSettings), keyEquivalent: "")
            empty.target = self
            empty.image = Self.symbol("plus.circle")
            menu.addItem(empty)
        }

        menu.addItem(.separator())
        let tweaksItem = NSMenuItem(title: S.tweaksMenu, action: nil, keyEquivalent: "")
        tweaksItem.image = Self.symbol("slider.horizontal.3")
        let tweaksMenu = NSMenu()
        for category in ToolCategory.allCases {
            let inCategory = tweaks.filter { $0.category == category }
            guard !inCategory.isEmpty else { continue }
            if !tweaksMenu.items.isEmpty { tweaksMenu.addItem(.separator()) }
            tweaksMenu.addItem(NSMenuItem.sectionHeader(title: category.title))
            for tool in inCategory {
                let entry = item(for: tool)
                entry.state = manager.isOn(tool) ? .on : .off
                tweaksMenu.addItem(entry)
            }
        }
        tweaksItem.submenu = tweaksMenu
        menu.addItem(tweaksItem)

        if let shortcutsTool = manager.tool("utilities.shortcuts"), manager.isOn(shortcutsTool) {
            UtilityTools.refreshShortcuts()
            let item = NSMenuItem(title: S.shortcutsApp, action: nil, keyEquivalent: "")
            item.image = Self.symbol("square.stack.3d.up")
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
            menu.addItem(item)
        }

        menu.addItem(.separator())
        let settings = NSMenuItem(title: S.settingsMenu, action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        settings.image = Self.symbol("gearshape")
        menu.addItem(settings)
        let updates = NSMenuItem(title: S.checkForUpdates, action: #selector(checkUpdates), keyEquivalent: "")
        updates.target = self
        updates.image = Self.symbol("arrow.triangle.2.circlepath")
        menu.addItem(updates)
        let quit = NSMenuItem(title: S.quit, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.image = Self.symbol("power")
        menu.addItem(quit)
    }

    private static func symbol(_ name: String) -> NSImage? {
        NSImage(systemSymbolName: name, accessibilityDescription: nil)
    }

    /// A SwiftUI view as a menu item, sized to fit.
    private func hosted<V: View>(_ view: V) -> NSMenuItem {
        let host = NSHostingView(rootView: view)
        host.frame = NSRect(origin: .zero, size: host.fittingSize)
        let item = NSMenuItem()
        item.view = host
        return item
    }

    private func item(for tool: Tool) -> NSMenuItem {
        let item = NSMenuItem(title: tool.title, action: #selector(runTool(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = tool.id
        item.image = Self.symbol(tool.symbol)
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

// MARK: - Menu views

private let menuWidth: CGFloat = 300

/// The app, and what it is doing right now.
private struct MenuHeader: View {
    let activeTweaks: Int

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage ?? NSImage())
                .resizable()
                .interpolation(.high)
                .frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text("Overdrive").font(.system(size: 13, weight: .semibold))
                Text(S.activeTweaks(activeTweaks)).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .frame(width: menuWidth)
    }
}

/// On/off controls as round tiles: the state shows at a glance, and the menu stays open.
private struct QuickTiles: View {
    struct Entry: Identifiable, Equatable {
        let id: String
        var on: Bool
    }

    @State private var entries: [Entry]

    init(initial: [Entry]) {
        _entries = State(initialValue: initial)
    }

    /// Reads the current states. Call outside SwiftUI updates only.
    @MainActor static func read(_ ids: [String]) -> [Entry] {
        ids.compactMap { id in
            guard let tool = ToolManager.shared.tool(id) else { return nil }
            return Entry(id: id, on: tool.state?() ?? false)
        }
    }

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 4), spacing: 10) {
            ForEach(entries) { entry in
                if let tool = ToolManager.shared.tool(entry.id) {
                    QuickTile(tool: tool, on: entry.on) { toggle(entry.id) }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(width: menuWidth)
    }

    private func toggle(_ id: String) {
        guard let tool = ToolManager.shared.tool(id), let index = entries.firstIndex(where: { $0.id == id }) else { return }
        // Show the new state at once, run the tool after this update, then read the real states
        // again (some change a moment later: Finder, Dock…).
        entries[index].on.toggle()
        let ids = entries.map(\.id)
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                ToolManager.shared.run(tool)
                entries = Self.read(ids)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            MainActor.assumeIsolated { entries = Self.read(ids) }
        }
    }
}

private struct QuickTile: View {
    let tool: Tool
    let on: Bool
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                ZStack {
                    Circle()
                        .fill(on ? Color.accentColor : Color.primary.opacity(hover ? 0.16 : 0.09))
                    Image(systemName: tool.symbol)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(on ? Color.white : Color.primary)
                }
                .frame(width: 40, height: 40)
                Text(tool.title)
                    .font(.system(size: 10))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(height: 26, alignment: .top)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .help(tool.detail)
        .animation(.easeOut(duration: 0.15), value: on)
    }
}
