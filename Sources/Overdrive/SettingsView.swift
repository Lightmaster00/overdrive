import AppKit
import Combine
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class SettingsWindow {
    static let shared = SettingsWindow()
    private var window: NSWindow?

    func show(category: ToolCategory? = nil) {
        if window == nil {
            let controller = NSHostingController(rootView: SettingsView(manager: .shared))
            let w = NSWindow(contentViewController: controller)
            w.title = "Overdrive"
            w.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
            w.setContentSize(NSSize(width: 860, height: 620))
            w.minSize = NSSize(width: 720, height: 480)
            w.isReleasedWhenClosed = false
            w.center()
            w.setFrameAutosaveName("OverdriveSettings")
            window = w
        }
        if let category { SettingsNavigation.shared.selection = .category(category) }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

enum SettingsPage: Hashable {
    case general, appShortcuts, category(ToolCategory)
}

@MainActor
final class SettingsNavigation: ObservableObject {
    static let shared = SettingsNavigation()
    @Published var selection: SettingsPage? = .general
}

struct SettingsView: View {
    @ObservedObject var manager: ToolManager
    @ObservedObject private var navigation = SettingsNavigation.shared
    @State private var search = ""

    var body: some View {
        NavigationSplitView {
            List(selection: $navigation.selection) {
                Label(S.general, systemImage: "gearshape").tag(SettingsPage.general)
                Section(S.tools) {
                    ForEach(ToolCategory.allCases) { category in
                        Label(category.title, systemImage: category.symbol).tag(SettingsPage.category(category))
                    }
                    Label(S.appShortcuts, systemImage: "command").tag(SettingsPage.appShortcuts)
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 220)
        } detail: {
            Group {
                if !search.isEmpty {
                    ToolList(manager: manager, tools: manager.tools.filter {
                        $0.title.localizedCaseInsensitiveContains(search) || $0.detail.localizedCaseInsensitiveContains(search)
                    }, title: S.searchResults)
                } else {
                    switch navigation.selection ?? .general {
                    case .general: GeneralPage(manager: manager)
                    case .appShortcuts: AppShortcutsPage(manager: manager)
                    case .category(let c): ToolList(manager: manager, tools: manager.tools(in: c), title: c.title)
                    }
                }
            }
        }
        .searchable(text: $search, placement: .sidebar, prompt: S.searchTools)
        .onDisappear {
            if NSApp.windows.filter({ $0.isVisible && $0.styleMask.contains(.titled) }).isEmpty {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }
}

// MARK: - Tools

private struct ToolList: View {
    @ObservedObject var manager: ToolManager
    let tools: [Tool]
    let title: String

    var body: some View {
        Form {
            if tools.isEmpty {
                Text(S.noResults).foregroundStyle(.secondary)
            }
            ForEach(tools) { tool in
                Section { ToolRow(manager: manager, tool: tool) }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(title)
    }
}

private struct ToolRow: View {
    @ObservedObject var manager: ToolManager
    let tool: Tool

    var body: some View {
        let on = manager.isOn(tool)
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: tool.symbol)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 26, height: 26)
                    .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(tool.title).font(.system(size: 13, weight: .semibold))
                        if tool.beta {
                            Text("BETA").font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background(Color.orange.opacity(0.2), in: Capsule())
                                .foregroundStyle(.orange)
                        }
                        if let state = tool.state, state() {
                            Text(S.on).font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background(Color.green.opacity(0.18), in: Capsule())
                                .foregroundStyle(.green)
                        }
                    }
                    Text(tool.detail).font(.system(size: 12)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                if tool.kind == .tweak {
                    Toggle("", isOn: Binding(get: { on }, set: { manager.setOn(tool, $0) }))
                        .toggleStyle(.switch)
                        .labelsHidden()
                } else {
                    Button(S.run) { manager.run(tool) }
                }
            }

            ForEach(missingPermissions, id: \.self) { permission in
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    Text(S.needsPermission(permission.title)).font(.system(size: 11))
                    Spacer()
                    Button(S.grant) { permission.request() }.controlSize(.small)
                }
            }

            HStack {
                Text(tool.kind == .tweak ? S.shortcutToggles : S.shortcut)
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                Spacer()
                ShortcutRecorder(id: tool.id)
            }
            if tool.kind == .action {
                Toggle(S.showInMenu, isOn: Binding(get: { on }, set: { manager.setOn(tool, $0) }))
                    .font(.system(size: 12))
            }
            if tool.id == "finder.extension", on {
                HStack {
                    Text(S.extensionHint).font(.system(size: 11)).foregroundStyle(.secondary)
                    Spacer()
                    Button(S.openExtensionSettings) { FinderTools.openExtensionSettings() }.controlSize(.small)
                }
            }
            ForEach(Array(tool.options.enumerated()), id: \.offset) { _, option in
                OptionRow(manager: manager, tool: tool, option: option)
            }
        }
        .padding(.vertical, 4)
    }

    private var missingPermissions: [Permission] {
        tool.permissions.filter { $0.isGranted == false }
    }
}

private struct OptionRow: View {
    @ObservedObject var manager: ToolManager
    let tool: Tool
    let option: ToolOption

    var body: some View {
        switch option {
        case let .number(key, title, range, step, defaultValue, unit):
            let value = Prefs.int(key, default: defaultValue)
            HStack {
                Text(title).font(.system(size: 12))
                Spacer()
                Stepper(value: Binding(get: { value }, set: { Prefs.setInt(key, min(max($0, range.lowerBound), range.upperBound)); manager.optionChanged(tool) }),
                        in: range, step: step) {
                    Text("\(value) \(unit)").font(.system(size: 12).monospacedDigit())
                }
            }
        case let .toggle(key, title, defaultValue):
            Toggle(title, isOn: Binding(get: { Prefs.isOn(key, default: defaultValue) },
                                        set: { Prefs.setOn(key, $0); manager.optionChanged(tool) }))
                .font(.system(size: 12))
        case let .choice(key, title, values, defaultValue):
            Picker(title, selection: Binding(get: { Prefs.string(key) ?? defaultValue },
                                             set: { Prefs.setString(key, $0); manager.optionChanged(tool) })) {
                ForEach(values, id: \.id) { Text($0.title).tag($0.id) }
            }
            .font(.system(size: 12))
        case let .folder(key, title, defaultPath):
            let path = Prefs.string(key) ?? (defaultPath as NSString).expandingTildeInPath
            HStack {
                Text(title).font(.system(size: 12))
                Spacer()
                Text((path as NSString).abbreviatingWithTildeInPath).font(.system(size: 11)).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
                Button(S.choose) {
                    let panel = NSOpenPanel()
                    panel.canChooseDirectories = true
                    panel.canChooseFiles = false
                    panel.canCreateDirectories = true
                    if panel.runModal() == .OK, let url = panel.url {
                        Prefs.setString(key, url.path)
                        manager.optionChanged(tool)
                    }
                }
                .controlSize(.small)
            }
        case let .apps(key, title):
            let ids = Prefs.strings(key)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(title).font(.system(size: 12))
                    Spacer()
                    Button(S.addApp) {
                        if let id = pickApp() {
                            Prefs.setStrings(key, Array(Set(ids + [id])).sorted())
                            manager.optionChanged(tool)
                        }
                    }
                    .controlSize(.small)
                }
                ForEach(ids, id: \.self) { id in
                    HStack {
                        AppIcon(bundleID: id).frame(width: 16, height: 16)
                        Text(AppLauncher(bundleID: id).name).font(.system(size: 12))
                        Spacer()
                        Button {
                            Prefs.setStrings(key, ids.filter { $0 != id })
                            manager.optionChanged(tool)
                        } label: { Image(systemName: "minus.circle") }
                        .buttonStyle(.borderless)
                    }
                }
            }
        }
    }
}

@MainActor
func pickApp() -> String? {
    let panel = NSOpenPanel()
    panel.directoryURL = URL(fileURLWithPath: "/Applications")
    panel.allowedContentTypes = [.application]
    panel.canChooseDirectories = false
    guard panel.runModal() == .OK, let url = panel.url else { return nil }
    return Bundle(url: url)?.bundleIdentifier
}

private struct AppIcon: View {
    let bundleID: String
    var body: some View {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable()
        } else {
            Image(systemName: "app").resizable()
        }
    }
}

// MARK: - General

private struct GeneralPage: View {
    @ObservedObject var manager: ToolManager
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var autoUpdates = Prefs.autoCheckUpdates
    @State private var tick = 0
    private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 56, height: 56)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Overdrive").font(.system(size: 18, weight: .semibold))
                        Text(S.tagline).foregroundStyle(.secondary)
                        Text(S.versionLabel(Updater.currentVersion)).font(.caption).foregroundStyle(.tertiary)
                    }
                }
                .padding(.vertical, 4)
            }
            Section(S.permissions) {
                ForEach(Permission.allCases) { permission in
                    LabeledContent {
                        if permission.isGranted == true {
                            Label(S.granted, systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                        } else {
                            Button(permission.isGranted == nil ? S.openSettings : S.grant) { permission.request() }
                        }
                    } label: {
                        Text(permission.title)
                        Text(permission.detail)
                    }
                }
                .id(tick)
            }
            Section(S.general) {
                Toggle(S.launchAtLogin, isOn: Binding(get: { launchAtLogin }, set: { on in
                    do {
                        if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                    } catch { NSLog("Overdrive: launch at login: \(error)") }
                    launchAtLogin = SMAppService.mainApp.status == .enabled
                }))
                DefaultBrowserRow()
            }
            Section(S.updates) {
                Toggle(S.autoCheckUpdates, isOn: Binding(get: { autoUpdates }, set: { autoUpdates = $0; Prefs.autoCheckUpdates = $0 }))
                LabeledContent(S.checkForUpdates) {
                    Button(S.checkNow) { Updater.checkNow() }.disabled(!Updater.isConfigured)
                }
            }
            Section {
                HStack(spacing: 16) {
                    Link(S.website, destination: URL(string: "https://lightmaster00.github.io/overdrive/")!)
                    Link("GitHub", destination: URL(string: "https://github.com/Lightmaster00/overdrive")!)
                    Link(S.reportIssue, destination: URL(string: "https://github.com/Lightmaster00/overdrive/issues")!)
                    Spacer()
                    Button(S.resetShortcuts) { ShortcutStore.resetAll(manager.tools.map(\.id)) }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(S.general)
        .onReceive(timer) { _ in tick &+= 1 }
    }
}

private struct DefaultBrowserRow: View {
    @State private var current = SystemTools.defaultBrowser

    var body: some View {
        Picker(S.defaultBrowser, selection: Binding(get: { current?.standardizedFileURL }, set: { url in
            guard let url else { return }
            SystemTools.setDefaultBrowser(url)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { current = SystemTools.defaultBrowser }
        })) {
            ForEach(SystemTools.browsers.map(\.standardizedFileURL), id: \.self) { url in
                Text(FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: ""))
                    .tag(Optional(url))
            }
        }
    }
}

// MARK: - App shortcuts

private struct AppShortcutsPage: View {
    @ObservedObject var manager: ToolManager

    var body: some View {
        Form {
            Section {
                Text(S.appShortcutsDetail).foregroundStyle(.secondary)
                ForEach(AppLaunchers.all) { launcher in
                    HStack {
                        AppIcon(bundleID: launcher.bundleID).frame(width: 22, height: 22)
                        Text(launcher.name)
                        Spacer()
                        ShortcutRecorder(id: launcher.shortcutID)
                        Button { AppLaunchers.remove(launcher) } label: { Image(systemName: "minus.circle") }
                            .buttonStyle(.borderless)
                    }
                }
                Button(S.addApp) {
                    if let id = pickApp() { AppLaunchers.add(id) }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(S.appShortcuts)
        .id(manager.revision)
    }
}
