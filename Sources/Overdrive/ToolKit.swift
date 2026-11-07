import AppKit
import Combine
import SwiftUI

enum ToolCategory: String, CaseIterable, Identifiable {
    case finder, windows, dock, apps, keyboard, mouse, screen, screenshots, audio, clipboard, files, display, system, utilities
    var id: String { rawValue }

    var title: String {
        switch self {
        case .finder: return "Finder"
        case .windows: return tr("Windows", "Fenêtres", "Ventanas", "Fenster", "ウインドウ")
        case .dock: return "Dock"
        case .apps: return tr("Apps", "Apps", "Apps", "Apps", "アプリ")
        case .keyboard: return tr("Keyboard", "Clavier", "Teclado", "Tastatur", "キーボード")
        case .mouse: return tr("Mouse & Trackpad", "Souris et trackpad", "Ratón y trackpad", "Maus & Trackpad", "マウスとトラックパッド")
        case .screen: return tr("Screen Capture", "Capture d'écran", "Captura de pantalla", "Bildschirm", "画面キャプチャ")
        case .screenshots: return tr("Screenshots", "Captures", "Capturas", "Bildschirmfotos", "スクリーンショット")
        case .audio: return tr("Audio", "Audio", "Audio", "Audio", "オーディオ")
        case .clipboard: return tr("Clipboard", "Presse-papiers", "Portapapeles", "Zwischenablage", "クリップボード")
        case .files: return tr("Files", "Fichiers", "Archivos", "Dateien", "ファイル")
        case .display: return tr("Display & Appearance", "Affichage et apparence", "Pantalla y apariencia", "Anzeige & Erscheinung", "ディスプレイと外観")
        case .system: return tr("System", "Système", "Sistema", "System", "システム")
        case .utilities: return tr("Utilities", "Utilitaires", "Utilidades", "Werkzeuge", "ユーティリティ")
        }
    }

    var symbol: String {
        switch self {
        case .finder: return "folder"
        case .windows: return "macwindow.on.rectangle"
        case .dock: return "dock.rectangle"
        case .apps: return "square.grid.2x2"
        case .keyboard: return "keyboard"
        case .mouse: return "computermouse"
        case .screen: return "text.viewfinder"
        case .screenshots: return "camera.viewfinder"
        case .audio: return "speaker.wave.2"
        case .clipboard: return "doc.on.clipboard"
        case .files: return "doc"
        case .display: return "circle.lefthalf.filled"
        case .system: return "gearshape.2"
        case .utilities: return "wrench.and.screwdriver"
        }
    }
}

/// A setting attached to a tool.
enum ToolOption {
    case number(key: String, title: String, range: ClosedRange<Int>, step: Int, defaultValue: Int, unit: String)
    case toggle(key: String, title: String, defaultValue: Bool)
    case folder(key: String, title: String, defaultPath: String)
    case choice(key: String, title: String, values: [(id: String, title: String)], defaultValue: String)
    case apps(key: String, title: String)
}

/// One feature of Overdrive.
/// - An **action** runs once (from the menu or its shortcut). "On" means shown in the menu.
/// - A **tweak** changes how the Mac behaves while it's on. Its shortcut turns it on or off.
@MainActor
final class Tool: Identifiable {
    enum Kind { case action, tweak }

    let id: String
    let category: ToolCategory
    let kind: Kind
    let title: String
    let detail: String
    let symbol: String
    var permissions: [Permission] = []
    var defaultOn = false
    var beta = false
    var options: [ToolOption] = []
    var perform: (@MainActor () -> Void)?
    var start: (@MainActor () -> Void)?
    var stop: (@MainActor () -> Void)?
    /// Current state of a toggle action (checkmark in the menu), e.g. Dark Mode.
    var state: (@MainActor () -> Bool)?

    init(_ id: String, _ category: ToolCategory, _ kind: Kind, symbol: String, title: String, detail: String) {
        self.id = id
        self.category = category
        self.kind = kind
        self.symbol = symbol
        self.title = title
        self.detail = detail
    }

    func with(_ change: (Tool) -> Void) -> Tool {
        change(self)
        return self
    }
}

@MainActor
final class ToolManager: ObservableObject {
    static let shared = ToolManager()

    let tools: [Tool]
    /// Bumped whenever something displayed changes.
    @Published private(set) var revision = 0
    private var running: Set<String> = []
    private var hotKeyIDs: [UInt32] = []

    private init() {
        tools = ToolCatalog.all()
        NotificationCenter.default.addObserver(forName: ShortcutStore.didChange, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { ToolManager.shared.registerShortcuts() }
        }
        NotificationCenter.default.addObserver(forName: ShortcutStore.recordingDidChange, object: nil, queue: .main) { note in
            MainActor.assumeIsolated {
                if (note.object as? Bool) == true {
                    ToolManager.shared.unregisterShortcuts()
                } else {
                    ToolManager.shared.registerShortcuts()
                }
            }
        }
    }

    func tool(_ id: String) -> Tool? { tools.first { $0.id == id } }

    func tools(in category: ToolCategory) -> [Tool] { tools.filter { $0.category == category } }

    func isOn(_ tool: Tool) -> Bool { Prefs.isOn(tool.id, default: tool.defaultOn) }

    func setOn(_ tool: Tool, _ on: Bool) {
        Prefs.setOn(tool.id, on)
        if tool.kind == .tweak {
            on ? startTweak(tool) : stopTweak(tool)
        }
        changed()
    }

    func startEnabledTweaks() {
        for tool in tools where tool.kind == .tweak && isOn(tool) { startTweak(tool) }
        registerShortcuts()
    }

    func stopAll() {
        for tool in tools where running.contains(tool.id) { stopTweak(tool) }
    }

    /// After an option changed: apply it by restarting the tweak.
    func optionChanged(_ tool: Tool) {
        if tool.kind == .tweak, running.contains(tool.id) {
            stopTweak(tool)
            startTweak(tool)
        }
        changed()
    }

    func run(_ tool: Tool) {
        switch tool.kind {
        case .action:
            tool.perform?()
        case .tweak:
            let on = !isOn(tool)
            setOn(tool, on)
            feedback(tool.symbol, "\(tool.title) — \(on ? S.on : S.off)")
        }
        changed()
    }

    func changed() { revision &+= 1 }

    private func startTweak(_ tool: Tool) {
        guard !running.contains(tool.id) else { return }
        running.insert(tool.id)
        tool.start?()
    }

    private func stopTweak(_ tool: Tool) {
        guard running.contains(tool.id) else { return }
        running.remove(tool.id)
        tool.stop?()
    }

    // MARK: Shortcuts

    func registerShortcuts() {
        unregisterShortcuts()
        for tool in tools {
            guard let combo = ShortcutStore.combo(for: tool.id) else { continue }
            if let id = HotKeyCenter.shared.register(keyCode: combo.keyCode, modifiers: combo.modifiers, handler: {
                if Prefs.playSoundOnShortcut { NSSound(named: "Tink")?.play() }
                ToolManager.shared.run(tool)
            }) {
                hotKeyIDs.append(id)
            }
        }
        for launcher in AppLaunchers.all {
            guard let combo = ShortcutStore.combo(for: launcher.shortcutID) else { continue }
            if let id = HotKeyCenter.shared.register(keyCode: combo.keyCode, modifiers: combo.modifiers, handler: {
                if Prefs.playSoundOnShortcut { NSSound(named: "Tink")?.play() }
                AppLaunchers.toggle(launcher)
            }) {
                hotKeyIDs.append(id)
            }
        }
    }

    func unregisterShortcuts() {
        for id in hotKeyIDs { HotKeyCenter.shared.unregister(id) }
        hotKeyIDs = []
    }
}

/// Apps opened or hidden with a global shortcut (Apps › App Shortcuts).
struct AppLauncher: Identifiable, Equatable {
    let bundleID: String
    var id: String { bundleID }
    var shortcutID: String { "app:\(bundleID)" }

    var url: URL? { NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) }
    var name: String {
        guard let url else { return bundleID }
        return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }
}

@MainActor
enum AppLaunchers {
    static var all: [AppLauncher] { Prefs.strings("appLaunchers").map(AppLauncher.init) }

    static func add(_ bundleID: String) {
        var list = Prefs.strings("appLaunchers")
        guard !list.contains(bundleID) else { return }
        list.append(bundleID)
        Prefs.setStrings("appLaunchers", list)
        ToolManager.shared.changed()
    }

    static func remove(_ launcher: AppLauncher) {
        Prefs.setStrings("appLaunchers", Prefs.strings("appLaunchers").filter { $0 != launcher.bundleID })
        ShortcutStore.set(nil, for: launcher.shortcutID)
        ToolManager.shared.changed()
    }

    /// Opens the app, or hides it if it's already in front.
    static func toggle(_ launcher: AppLauncher) {
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: launcher.bundleID).first,
           app.isActive {
            app.hide()
            return
        }
        guard let url = launcher.url else { return }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: config)
    }
}
