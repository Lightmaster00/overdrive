import AppKit
import ApplicationServices
import Carbon
import CoreAudio

// MARK: - Windows

@MainActor
enum WindowTools {
    static func hideAll() {
        for app in Apps.regular where app.bundleIdentifier != Apps.me { app.hide() }
    }

    static func hideOthers() {
        let front = Apps.frontmost?.processIdentifier
        for app in Apps.regular where app.processIdentifier != front && app.bundleIdentifier != Apps.me { app.hide() }
    }

    static func minimizeAll(exceptFront: Bool) {
        let front = Apps.frontmost?.processIdentifier
        for app in Apps.regular where !app.isHidden {
            if exceptFront && app.processIdentifier == front { continue }
            for window in AX.windows(of: app.processIdentifier) where AX.subrole(window) == "AXStandardWindow" {
                AX.setMinimized(window, true)
            }
        }
    }

    static func unminimizeFrontApp() {
        guard let app = Apps.frontmost else { return }
        for window in AX.windows(of: app.processIdentifier) where AX.isMinimized(window) {
            AX.setMinimized(window, false)
        }
    }

    // Front window placement

    private static func frontWindow() -> AXUIElement? {
        guard let app = Apps.frontmost else { return nil }
        return AX.focusedWindow(of: app.processIdentifier)
    }

    static func centerFrontWindow() {
        guard let window = frontWindow(), let frame = AX.frame(window),
              let screen = NSScreen.containing(axPoint: CGPoint(x: frame.midX, y: frame.midY)) else { return }
        let v = screen.visibleFrameTopLeft
        AX.setFrame(window, CGRect(x: v.midX - frame.width / 2, y: v.midY - frame.height / 2,
                                   width: frame.width, height: frame.height))
    }

    /// Previous frame of windows that were made to fill the screen (to restore them).
    private static var savedFrames: [UInt: CGRect] = [:]

    static func toggleFill(_ window: AXUIElement) {
        guard let frame = AX.frame(window),
              let screen = NSScreen.containing(axPoint: CGPoint(x: frame.midX, y: frame.midY)) else { return }
        let v = screen.visibleFrameTopLeft
        let key = UInt(CFHash(window))
        let filled = abs(frame.minX - v.minX) < 4 && abs(frame.minY - v.minY) < 4
            && abs(frame.width - v.width) < 8 && abs(frame.height - v.height) < 8
        if filled, let previous = savedFrames[key] {
            AX.setFrame(window, previous)
            savedFrames[key] = nil
        } else {
            savedFrames[key] = frame
            AX.setFrame(window, v)
        }
    }

    static func fillFrontWindow() {
        if let window = frontWindow() { toggleFill(window) }
    }

    // Window buttons

    private static var swallowMouseUp = false

    static func startButtonTweaks() {
        EventTap.shared.add("windows.buttons") { type, event in
            if type == .leftMouseUp, swallowMouseUp {
                swallowMouseUp = false
                return .consume
            }
            guard type == .leftMouseDown, !event.flags.contains(.maskAlternate) else { return .pass }
            let manager = ToolManager.shared
            let green = manager.tool("windows.greenFills").map(manager.isOn) == true
            let yellow = manager.tool("windows.yellowHides").map(manager.isOn) == true
            guard green || yellow, let element = AX.element(at: event.location) else { return .pass }
            let subrole = AX.subrole(element)
            if green, subrole == "AXFullScreenButton" || subrole == "AXZoomButton", let window = AX.window(of: element) {
                swallowMouseUp = true
                toggleFill(window)
                return .consume
            }
            if yellow, subrole == "AXMinimizeButton" {
                swallowMouseUp = true
                NSRunningApplication(processIdentifier: AX.pid(of: element))?.hide()
                return .consume
            }
            return .pass
        }
    }

    static func stopButtonTweaksIfUnused() {
        let manager = ToolManager.shared
        let used = ["windows.greenFills", "windows.yellowHides"].contains { manager.tool($0).map(manager.isOn) == true }
        if !used { EventTap.shared.remove("windows.buttons") }
    }

    // Unminimize when activated

    private static var activationObserver: NSObjectProtocol?

    static func startUnminimizeOnActivate() {
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            MainActor.assumeIsolated {
                guard let pid = app?.processIdentifier else { return }
                let windows = AX.windows(of: pid).filter { AX.subrole($0) == "AXStandardWindow" }
                // Only when every window is minimized: otherwise the app is already usable.
                guard !windows.isEmpty, windows.allSatisfy(AX.isMinimized) else { return }
                for window in windows { AX.setMinimized(window, false) }
            }
        }
    }

    static func stopUnminimizeOnActivate() {
        if let activationObserver { NSWorkspace.shared.notificationCenter.removeObserver(activationObserver) }
        activationObserver = nil
    }
}

// MARK: - Dock

@MainActor
enum DockTools {
    private static var swallowMouseUp = false

    /// Clicking the Dock icon of the app in front hides it (like Windows' taskbar).
    static func startClickToHide() {
        EventTap.shared.add("dock.clickToHide") { type, event in
            if type == .leftMouseUp, swallowMouseUp {
                swallowMouseUp = false
                return .consume
            }
            guard type == .leftMouseDown, event.modifiers.isEmpty,
                  let element = AX.element(at: event.location),
                  NSRunningApplication(processIdentifier: AX.pid(of: element))?.bundleIdentifier == "com.apple.dock",
                  AX.subrole(element) == "AXApplicationDockItem",
                  let url: URL = AX.attribute(element, kAXURLAttribute),
                  let front = Apps.frontmost, front.bundleURL?.standardizedFileURL == url.standardizedFileURL,
                  front.bundleIdentifier != Apps.finder || !AX.windows(of: front.processIdentifier).isEmpty
            else { return .pass }
            // With no window open, the click must still open one.
            guard !AX.windows(of: front.processIdentifier).isEmpty else { return .pass }
            swallowMouseUp = true
            front.hide()
            return .consume
        }
    }

    static func stopClickToHide() { EventTap.shared.remove("dock.clickToHide") }

    static var noDelay: Bool { Shell.defaultsRead("com.apple.dock", "autohide-delay") == "0" }

    static func setNoDelay(_ on: Bool) {
        if on {
            Shell.defaultsWrite("com.apple.dock", "autohide-delay", "float", "0")
            Shell.defaultsWrite("com.apple.dock", "autohide-time-modifier", "float", "0.35")
        } else {
            Shell.defaultsDelete("com.apple.dock", "autohide-delay")
            Shell.defaultsDelete("com.apple.dock", "autohide-time-modifier")
        }
        Shell.restart("Dock")
    }

    static func addSpacer(small: Bool) {
        let tile = small ? "{\"tile-type\"=\"small-spacer-tile\";}" : "{\"tile-type\"=\"spacer-tile\";}"
        Shell.run("/usr/bin/defaults", ["write", "com.apple.dock", "persistent-apps", "-array-add", tile])
        Shell.restart("Dock")
        feedback("dock.rectangle", S.spacerAdded)
    }
}

// MARK: - Apps

@MainActor
enum AppTools {
    static var excluded: Set<String> {
        Set(Prefs.strings("quitExclusions")).union([Apps.finder, Apps.me])
    }

    static func quitAll(exceptFront: Bool) {
        let front = Apps.frontmost?.processIdentifier
        var count = 0
        for app in Apps.regular {
            guard let id = app.bundleIdentifier, !excluded.contains(id) else { continue }
            if exceptFront && app.processIdentifier == front { continue }
            if app.terminate() { count += 1 }
        }
        feedback("xmark.circle", S.appsQuit(count))
    }

    // ⌘Q twice

    private static var lastQuitPress: (pid: pid_t, time: Date)?

    static func startQuitGuard() {
        EventTap.shared.add("apps.quitGuard") { type, event in
            guard type == .keyDown, event.keyCode == kVK_ANSI_Q, event.modifiers == .maskCommand,
                  let app = Apps.frontmost, app.bundleIdentifier != Apps.finder else { return .pass }
            if event.isAutoRepeat { return .consume }
            if let id = app.bundleIdentifier, Prefs.strings("quitGuardExclusions").contains(id) { return .pass }
            if let last = lastQuitPress, last.pid == app.processIdentifier, Date().timeIntervalSince(last.time) < 1.2 {
                lastQuitPress = nil
                return .pass
            }
            lastQuitPress = (app.processIdentifier, Date())
            feedback("command", S.pressAgainToQuit(app.localizedName ?? ""))
            return .consume
        }
    }

    static func stopQuitGuard() { EventTap.shared.remove("apps.quitGuard") }

    // Auto-hide inactive apps

    private static var lastActive: [pid_t: Date] = [:]
    private static var autoHideTimer: Timer?
    private static var autoHideObserver: NSObjectProtocol?

    static func startAutoHide() {
        let now = Date()
        for app in Apps.regular { lastActive[app.processIdentifier] = now }
        autoHideObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didDeactivateApplicationNotification, object: nil, queue: .main
        ) { note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            MainActor.assumeIsolated {
                if let pid = app?.processIdentifier { lastActive[pid] = Date() }
            }
        }
        autoHideTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            MainActor.assumeIsolated { hideInactive() }
        }
    }

    static func stopAutoHide() {
        autoHideTimer?.invalidate()
        autoHideTimer = nil
        if let autoHideObserver { NSWorkspace.shared.notificationCenter.removeObserver(autoHideObserver) }
        autoHideObserver = nil
    }

    private static func hideInactive() {
        let limit = TimeInterval(Prefs.int("autoHideMinutes", default: 10) * 60)
        let exclusions = Set(Prefs.strings("autoHideExclusions")).union([Apps.me])
        let now = Date()
        for app in Apps.regular where !app.isActive && !app.isHidden {
            guard let id = app.bundleIdentifier, !exclusions.contains(id) else { continue }
            let since = lastActive[app.processIdentifier] ?? now
            if lastActive[app.processIdentifier] == nil { lastActive[app.processIdentifier] = now }
            if now.timeIntervalSince(since) > limit { app.hide() }
        }
    }

    // Install apps from disk images

    private static var mountObserver: NSObjectProtocol?

    static func startDMGInstall() {
        mountObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didMountNotification, object: nil, queue: .main
        ) { note in
            let volume = note.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL
            MainActor.assumeIsolated {
                if let volume { offerInstall(from: volume) }
            }
        }
    }

    static func stopDMGInstall() {
        if let mountObserver { NSWorkspace.shared.notificationCenter.removeObserver(mountObserver) }
        mountObserver = nil
    }

    private static func offerInstall(from volume: URL) {
        let readOnly = (try? volume.resourceValues(forKeys: [.volumeIsReadOnlyKey]))?.volumeIsReadOnly ?? false
        guard readOnly, volume.path.hasPrefix("/Volumes/"),
              let items = try? FileManager.default.contentsOfDirectory(at: volume, includingPropertiesForKeys: nil) else { return }
        let apps = items.filter { $0.pathExtension == "app" }
        guard apps.count == 1, let app = apps.first else { return }
        let name = app.deletingPathExtension().lastPathComponent
        let destination = URL(fileURLWithPath: "/Applications").appendingPathComponent(app.lastPathComponent)

        let alert = NSAlert()
        alert.messageText = S.installTitle(name)
        alert.informativeText = FileManager.default.fileExists(atPath: destination.path)
            ? S.installReplaceDetail : S.installDetail
        alert.addButton(withTitle: S.install)
        alert.addButton(withTitle: S.notNow)
        if let icon = NSWorkspace.shared.icon(forFile: app.path) as NSImage? { alert.icon = icon }
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        DispatchQueue.global(qos: .userInitiated).async {
            var error: Error?
            do {
                if FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.trashItem(at: destination, resultingItemURL: nil)
                }
                try FileManager.default.copyItem(at: app, to: destination)
            } catch let e { error = e }
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    if let error {
                        showError(S.installFailed(name), error)
                        return
                    }
                    try? NSWorkspace.shared.unmountAndEjectDevice(at: volume)
                    NSWorkspace.shared.openApplication(at: destination, configuration: .init())
                    feedback("checkmark.circle", S.installed(name))
                }
            }
        }
    }

    // Stop Music from opening by itself

    private static var lastTrigger = Date.distantPast
    private static var launchObserver: NSObjectProtocol?
    private static var routeListener: PropertyListener?

    static func startStopMusic() {
        // Music opens by itself after the Play key or when headphones connect.
        EventTap.shared.add("apps.stopMusic") { type, event in
            if type.rawValue == 14, let e = NSEvent(cgEvent: event), e.subtype.rawValue == 8,
               (e.data1 & 0xFFFF0000) >> 16 == 16 /* NX_KEYTYPE_PLAY */ {
                lastTrigger = Date()
            }
            return .pass
        }
        routeListener = PropertyListener(.system, kAudioHardwarePropertyDefaultOutputDevice) {
            MainActor.assumeIsolated { lastTrigger = Date() }
        }
        launchObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main
        ) { note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            MainActor.assumeIsolated {
                guard app?.bundleIdentifier == "com.apple.Music", Date().timeIntervalSince(lastTrigger) < 5 else { return }
                app?.terminate()
            }
        }
    }

    static func stopStopMusic() {
        EventTap.shared.remove("apps.stopMusic")
        routeListener = nil
        if let launchObserver { NSWorkspace.shared.notificationCenter.removeObserver(launchObserver) }
        launchObserver = nil
    }
}

@MainActor
func showError(_ title: String, _ error: Error) {
    NSLog("Overdrive: \(title): \(error)")
    let alert = NSAlert()
    alert.messageText = title
    alert.informativeText = error.localizedDescription
    NSApp.activate(ignoringOtherApps: true)
    alert.runModal()
}
