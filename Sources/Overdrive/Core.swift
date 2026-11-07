import AppKit
import ApplicationServices
import Foundation

// MARK: - Preferences

enum PrefKey {
    static let skippedVersion = "updates.skippedVersion"
}

enum Prefs {
    static let defaults = UserDefaults.standard

    static var autoCheckUpdates: Bool {
        get { defaults.object(forKey: "updates.autoCheck") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "updates.autoCheck") }
    }

    static var playSoundOnShortcut: Bool {
        get { defaults.bool(forKey: "shortcuts.playSound") }
        set { defaults.set(newValue, forKey: "shortcuts.playSound") }
    }

    /// Whether a tool is turned on (tweaks) or shown in the menu (actions).
    static func isOn(_ id: String, default value: Bool) -> Bool {
        defaults.object(forKey: "tool.\(id)") as? Bool ?? value
    }

    static func setOn(_ id: String, _ on: Bool) {
        defaults.set(on, forKey: "tool.\(id)")
    }

    static func int(_ key: String, default value: Int) -> Int {
        defaults.object(forKey: "option.\(key)") as? Int ?? value
    }

    static func setInt(_ key: String, _ value: Int) { defaults.set(value, forKey: "option.\(key)") }

    static func string(_ key: String) -> String? { defaults.string(forKey: "option.\(key)") }
    static func setString(_ key: String, _ value: String?) { defaults.set(value, forKey: "option.\(key)") }

    static func strings(_ key: String) -> [String] { defaults.stringArray(forKey: "option.\(key)") ?? [] }
    static func setStrings(_ key: String, _ value: [String]) { defaults.set(value, forKey: "option.\(key)") }
}

// MARK: - Shell and AppleScript

enum Shell {
    /// Runs a program and returns its output (trimmed). Never uses a shell: no injection possible.
    @discardableResult
    static func run(_ path: String, _ arguments: [String], timeout: TimeInterval = 20) -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do { try process.run() } catch { return (-1, error.localizedDescription) }
        // Stop a program that hangs (osascript waiting for an app, for example).
        let timer = DispatchSource.makeTimerSource(queue: .global())
        timer.schedule(deadline: .now() + timeout)
        timer.setEventHandler { if process.isRunning { process.terminate() } }
        timer.resume()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        timer.cancel()
        let text = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        return (process.terminationStatus, text)
    }

    /// Runs off the main thread and calls back on the main thread.
    static func runAsync(_ path: String, _ arguments: [String],
                         completion: (@MainActor @Sendable (Int32, String) -> Void)? = nil) {
        DispatchQueue.global(qos: .userInitiated).async {
            let result = run(path, arguments)
            if let completion {
                DispatchQueue.main.async { MainActor.assumeIsolated { completion(result.status, result.output) } }
            }
        }
    }

    static func defaultsWrite(_ domain: String, _ key: String, _ type: String, _ value: String) {
        run("/usr/bin/defaults", ["write", domain, key, "-\(type)", value])
    }

    static func defaultsDelete(_ domain: String, _ key: String) {
        run("/usr/bin/defaults", ["delete", domain, key])
    }

    static func defaultsRead(_ domain: String, _ key: String) -> String? {
        let r = run("/usr/bin/defaults", ["read", domain, key])
        return r.status == 0 ? r.output : nil
    }

    static func restart(_ process: String) {
        run("/usr/bin/killall", [process])
    }

    /// Runs an AppleScript with osascript (the system asks once for permission to control the app).
    /// Values are passed as arguments (`item n of argv`), never pasted into the script.
    @discardableResult
    static func appleScript(_ source: String, _ arguments: [String] = []) -> (status: Int32, output: String) {
        run("/usr/bin/osascript", ["-e", "on run argv", "-e", source, "-e", "end run"] + arguments)
    }

    static func appleScriptAsync(_ source: String, _ arguments: [String] = [],
                                 completion: (@MainActor @Sendable (Int32, String) -> Void)? = nil) {
        runAsync("/usr/bin/osascript", ["-e", "on run argv", "-e", source, "-e", "end run"] + arguments,
                 completion: completion)
    }

    /// Escapes a string for a quoted AppleScript literal (used only for fixed, known values).
    static func quoted(_ s: String) -> String {
        "\"" + s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }
}

// MARK: - Permissions

enum Permission: String, CaseIterable, Identifiable {
    case accessibility, screenRecording, automation
    var id: String { rawValue }

    var title: String {
        switch self {
        case .accessibility: return S.permAccessibility
        case .screenRecording: return S.permScreenRecording
        case .automation: return S.permAutomation
        }
    }

    var detail: String {
        switch self {
        case .accessibility: return S.permAccessibilityDetail
        case .screenRecording: return S.permScreenRecordingDetail
        case .automation: return S.permAutomationDetail
        }
    }

    /// nil when it can't be known in advance (automation is asked per app, on first use).
    var isGranted: Bool? {
        switch self {
        case .accessibility: return AXIsProcessTrusted()
        case .screenRecording: return CGPreflightScreenCaptureAccess()
        case .automation: return nil
        }
    }

    func request() {
        switch self {
        case .accessibility:
            let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
            _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
            openSettings()
        case .screenRecording:
            if !CGRequestScreenCaptureAccess() { openSettings() }
        case .automation:
            openSettings()
        }
    }

    func openSettings() {
        let anchor: String
        switch self {
        case .accessibility: anchor = "Privacy_Accessibility"
        case .screenRecording: anchor = "Privacy_ScreenCapture"
        case .automation: anchor = "Privacy_Automation"
        }
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Accessibility (AX)

enum AX {
    static let system = AXUIElementCreateSystemWide()

    static func attribute<T>(_ element: AXUIElement, _ name: String) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value as? T
    }

    static func set(_ element: AXUIElement, _ name: String, _ value: CFTypeRef) {
        AXUIElementSetAttributeValue(element, name as CFString, value)
    }

    static func app(_ pid: pid_t) -> AXUIElement {
        let e = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(e, 0.25)
        return e
    }

    static func windows(of pid: pid_t) -> [AXUIElement] {
        attribute(app(pid), kAXWindowsAttribute) ?? []
    }

    static func focusedWindow(of pid: pid_t) -> AXUIElement? {
        attribute(app(pid), kAXFocusedWindowAttribute)
    }

    static func role(_ e: AXUIElement) -> String? { attribute(e, kAXRoleAttribute) }
    static func subrole(_ e: AXUIElement) -> String? { attribute(e, kAXSubroleAttribute) }

    static func isMinimized(_ window: AXUIElement) -> Bool {
        (attribute(window, kAXMinimizedAttribute) as Bool?) ?? false
    }

    static func setMinimized(_ window: AXUIElement, _ minimized: Bool) {
        set(window, kAXMinimizedAttribute, minimized as CFBoolean)
    }

    /// Whether the keyboard focus is in a text field (so typing shortcuts must not be changed).
    static func isEditingText() -> Bool {
        AXUIElementSetMessagingTimeout(system, 0.15)
        guard let focused: AXUIElement = attribute(system, kAXFocusedUIElementAttribute) else { return false }
        let role = self.role(focused) ?? ""
        if ["AXTextField", "AXTextArea", "AXComboBox", "AXSearchField"].contains(role) { return true }
        let editable: Bool? = attribute(focused, "AXEditable")
        return editable == true
    }

    /// Whether the keyboard focus is on Finder's file list (icon, list, column or gallery view),
    /// and not on a button, a sheet or a text field.
    static func isBrowsingFiles() -> Bool {
        AXUIElementSetMessagingTimeout(system, 0.15)
        guard let focused: AXUIElement = attribute(system, kAXFocusedUIElementAttribute) else { return false }
        if isEditingText() { return false }
        return ["AXOutline", "AXList", "AXBrowser", "AXTable", "AXGroup", "AXScrollArea"].contains(role(focused) ?? "")
    }

    static func element(at point: CGPoint) -> AXUIElement? {
        var element: AXUIElement?
        AXUIElementSetMessagingTimeout(system, 0.15)
        guard AXUIElementCopyElementAtPosition(system, Float(point.x), Float(point.y), &element) == .success else {
            return nil
        }
        return element
    }

    static func pid(of element: AXUIElement) -> pid_t {
        var pid: pid_t = 0
        AXUIElementGetPid(element, &pid)
        return pid
    }

    static func window(of element: AXUIElement) -> AXUIElement? {
        attribute(element, kAXWindowAttribute)
    }

    static func setFrame(_ window: AXUIElement, _ frame: CGRect) {
        var origin = frame.origin
        var size = frame.size
        if let p = AXValueCreate(.cgPoint, &origin) { set(window, kAXPositionAttribute, p) }
        if let s = AXValueCreate(.cgSize, &size) { set(window, kAXSizeAttribute, s) }
    }

    static func frame(_ window: AXUIElement) -> CGRect? {
        guard let p: AXValue = attribute(window, kAXPositionAttribute),
              let s: AXValue = attribute(window, kAXSizeAttribute) else { return nil }
        var origin = CGPoint.zero, size = CGSize.zero
        AXValueGetValue(p, .cgPoint, &origin)
        AXValueGetValue(s, .cgSize, &size)
        return CGRect(origin: origin, size: size)
    }

    static func press(_ element: AXUIElement) {
        AXUIElementPerformAction(element, kAXPressAction as CFString)
    }
}

// MARK: - Screen geometry

extension NSScreen {
    /// The visible frame in Accessibility coordinates (origin at the top left of the main screen).
    var visibleFrameTopLeft: CGRect {
        let main = NSScreen.screens.first?.frame.height ?? frame.height
        let v = visibleFrame
        return CGRect(x: v.minX, y: main - v.maxY, width: v.width, height: v.height)
    }

    /// The screen containing a point given in Accessibility coordinates.
    static func containing(axPoint p: CGPoint) -> NSScreen? {
        let main = NSScreen.screens.first?.frame.height ?? 0
        let flipped = CGPoint(x: p.x, y: main - p.y)
        return NSScreen.screens.first { $0.frame.contains(flipped) } ?? NSScreen.main
    }
}

// MARK: - Apps

enum Apps {
    static var regular: [NSRunningApplication] {
        NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
    }

    static var frontmost: NSRunningApplication? { NSWorkspace.shared.frontmostApplication }

    static func isFrontmost(_ bundleID: String) -> Bool {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier == bundleID
    }

    static let finder = "com.apple.finder"
    static let me = Bundle.main.bundleIdentifier ?? "com.lightmaster.overdrive"
}

@MainActor
func feedback(_ symbol: String, _ text: String) {
    HUD.shared.show(symbol: symbol, text: text)
}
