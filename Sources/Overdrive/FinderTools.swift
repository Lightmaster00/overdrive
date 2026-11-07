import AppKit
import Carbon
import CryptoKit

/// Finder improvements: cut and paste, Return to open, Delete to trash, new text file,
/// and the actions of the Finder context menu (sent by the Finder extension).
@MainActor
enum FinderTools {
    // MARK: Finder state (AppleScript)

    /// POSIX paths of the items selected in the front Finder window.
    nonisolated static func selection() -> [String] {
        let r = Shell.appleScript("""
        tell application "Finder"
            set out to ""
            repeat with anItem in (get selection as alias list)
                set out to out & POSIX path of anItem & linefeed
            end repeat
            return out
        end tell
        """)
        guard r.status == 0 else { return [] }
        return r.output.split(separator: "\n").map(String.init).filter { $0.hasPrefix("/") }
    }

    /// Folder shown in the front Finder window (the Desktop when there is none).
    nonisolated static func currentFolder() -> String? {
        let r = Shell.appleScript("""
        tell application "Finder"
            if (count of Finder windows) > 0 then
                try
                    return POSIX path of (target of front Finder window as alias)
                end try
            end if
            return POSIX path of (desktop as alias)
        end tell
        """)
        guard r.status == 0, r.output.hasPrefix("/") else { return nil }
        return r.output
    }

    nonisolated static func reveal(_ paths: [String], rename: Bool = false) {
        let urls = paths.map { URL(fileURLWithPath: $0) }
        DispatchQueue.main.async {
            NSWorkspace.shared.activateFileViewerSelecting(urls)
            if rename, let finder = NSRunningApplication.runningApplications(withBundleIdentifier: Apps.finder).first {
                // Return starts renaming the selected item.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    EventTap.postKey(kVK_Return, to: finder.processIdentifier)
                }
            }
        }
    }

    /// A name that doesn't exist yet in a folder ("untitled 2.txt"…).
    nonisolated static func uniqueURL(in folder: URL, name: String) -> URL {
        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        var candidate = folder.appendingPathComponent(name)
        var n = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            let numbered = ext.isEmpty ? "\(base) \(n)" : "\(base) \(n).\(ext)"
            candidate = folder.appendingPathComponent(numbered)
            n += 1
        }
        return candidate
    }

    private static var finderIsFront: Bool { Apps.isFrontmost(Apps.finder) }

    // MARK: Cut and paste

    private static var cutPaths: [String] = []

    static func startCutPaste() {
        EventTap.shared.add("finder.cutPaste") { type, event in
            guard type == .keyDown, finderIsFront, event.modifiers == .maskCommand, !event.isAutoRepeat else { return .pass }
            switch event.keyCode {
            case kVK_ANSI_X:
                guard !AX.isEditingText() else { return .pass }
                DispatchQueue.global(qos: .userInitiated).async {
                    let paths = selection()
                    DispatchQueue.main.async {
                        MainActor.assumeIsolated {
                            guard !paths.isEmpty else { return }
                            cutPaths = paths
                            feedback("scissors", S.itemsCut(paths.count))
                        }
                    }
                }
                return .consume
            case kVK_ANSI_C:
                cutPaths = [] // a new copy cancels the cut
                return .pass
            case kVK_ANSI_V:
                guard !cutPaths.isEmpty, !AX.isEditingText() else { return .pass }
                let paths = cutPaths
                cutPaths = []
                DispatchQueue.global(qos: .userInitiated).async {
                    guard let folder = currentFolder() else { return }
                    let moved = move(paths, to: URL(fileURLWithPath: folder))
                    reveal(moved)
                }
                return .consume
            default:
                return .pass
            }
        }
    }

    static func stopCutPaste() {
        EventTap.shared.remove("finder.cutPaste")
        cutPaths = []
    }

    /// Moves files, never overwriting (a number is added to the name). Returns the new paths.
    nonisolated static func move(_ paths: [String], to folder: URL) -> [String] {
        var result: [String] = []
        for path in paths {
            let source = URL(fileURLWithPath: path)
            // Moving into itself or to the same place does nothing.
            if source.deletingLastPathComponent().standardizedFileURL == folder.standardizedFileURL { continue }
            if source.standardizedFileURL == folder.standardizedFileURL { continue }
            if folder.standardizedFileURL.path.hasPrefix(source.standardizedFileURL.path + "/") { continue }
            let target = uniqueURL(in: folder, name: source.lastPathComponent)
            do {
                try FileManager.default.moveItem(at: source, to: target)
                result.append(target.path)
            } catch {
                NSLog("Overdrive: could not move \(path): \(error.localizedDescription)")
            }
        }
        return result
    }

    // MARK: Keys in Finder: Return, Delete, ⌥N

    static func startReturnOpens() {
        EventTap.shared.add("finder.returnOpens") { type, event in
            guard type == .keyDown, finderIsFront else { return .pass }
            let mods = event.modifiers
            switch event.keyCode {
            case kVK_Return where mods.isEmpty:
                guard !AX.isEditingText() else { return .pass }
                if let finder = Apps.frontmost { EventTap.postKey(kVK_DownArrow, flags: .maskCommand, to: finder.processIdentifier) }
                return .consume
            case kVK_Return where mods == .maskShift, kVK_F2 where mods.isEmpty:
                guard !AX.isEditingText() else { return .pass }
                if let finder = Apps.frontmost { EventTap.postKey(kVK_Return, to: finder.processIdentifier) }
                return .consume
            default:
                return .pass
            }
        }
    }

    static func stopReturnOpens() { EventTap.shared.remove("finder.returnOpens") }

    static func startDeleteToTrash() {
        EventTap.shared.add("finder.deleteToTrash") { type, event in
            guard type == .keyDown, finderIsFront, event.keyCode == kVK_Delete || event.keyCode == kVK_ForwardDelete,
                  event.modifiers.isEmpty, !AX.isEditingText() else { return .pass }
            if let finder = Apps.frontmost { EventTap.postKey(kVK_Delete, flags: .maskCommand, to: finder.processIdentifier) }
            return .consume
        }
    }

    static func stopDeleteToTrash() { EventTap.shared.remove("finder.deleteToTrash") }

    static func startNewFileShortcut() {
        EventTap.shared.add("finder.newTextFile") { type, event in
            guard type == .keyDown, finderIsFront, event.keyCode == kVK_ANSI_N, event.modifiers == .maskAlternate,
                  !AX.isEditingText() else { return .pass }
            newTextFile(in: nil)
            return .consume
        }
    }

    static func stopNewFileShortcut() { EventTap.shared.remove("finder.newTextFile") }

    /// Creates "untitled.txt" in a folder (the current Finder folder by default) and starts renaming it.
    static func newTextFile(in folder: String?) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let folder = folder ?? currentFolder() else { return }
            let url = uniqueURL(in: URL(fileURLWithPath: folder), name: S.untitledFileName)
            guard FileManager.default.createFile(atPath: url.path, contents: Data()) else { return }
            reveal([url.path], rename: true)
        }
    }

    // MARK: Open a window when Finder is activated

    private static var activationObserver: NSObjectProtocol?
    private static var lastClick = (time: Date.distantPast, onDesktopOrFinder: false)

    static func startOpenWindowOnActivate() {
        // Clicking the desktop also activates Finder: that must not open a window.
        EventTap.shared.add("finder.openWindow") { type, event in
            guard type == .leftMouseDown else { return .pass }
            let pid = AX.element(at: event.location).map(AX.pid(of:)) ?? 0
            let finderPID = NSRunningApplication.runningApplications(withBundleIdentifier: Apps.finder).first?.processIdentifier
            lastClick = (Date(), pid == finderPID)
            return .pass
        }
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            MainActor.assumeIsolated {
                guard app?.bundleIdentifier == Apps.finder else { return }
                if lastClick.onDesktopOrFinder, Date().timeIntervalSince(lastClick.time) < 1 { return }
                Shell.appleScriptAsync("""
                tell application "Finder"
                    if (count of Finder windows) = 0 then
                        make new Finder window
                        activate
                    end if
                end tell
                """)
            }
        }
    }

    static func stopOpenWindowOnActivate() {
        EventTap.shared.remove("finder.openWindow")
        if let activationObserver { NSWorkspace.shared.notificationCenter.removeObserver(activationObserver) }
        activationObserver = nil
    }

    // MARK: Actions

    static var hiddenFilesShown: Bool { Shell.defaultsRead("com.apple.finder", "AppleShowAllFiles") == "1" }

    static func toggleHiddenFiles() {
        let show = !hiddenFilesShown
        Shell.defaultsWrite("com.apple.finder", "AppleShowAllFiles", "bool", show ? "true" : "false")
        Shell.restart("Finder")
        feedback(show ? "eye" : "eye.slash", show ? S.hiddenFilesShown : S.hiddenFilesHidden)
    }

    static func copyPathOfSelection() {
        DispatchQueue.global(qos: .userInitiated).async {
            let paths = selection()
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    guard !paths.isEmpty else { return feedback("questionmark.folder", S.nothingSelected) }
                    copyToPasteboard(paths.map { $0.hasSuffix("/") && $0.count > 1 ? String($0.dropLast()) : $0 }
                        .joined(separator: "\n"))
                    feedback("doc.on.doc", S.pathCopied)
                }
            }
        }
    }

    static func openTerminalHere() {
        DispatchQueue.global(qos: .userInitiated).async {
            let selected = selection()
            var folder = currentFolder()
            if selected.count == 1, selected[0].hasSuffix("/") { folder = selected[0] }
            guard let folder else { return }
            openTerminal(at: folder)
        }
    }

    nonisolated static func openTerminal(at folder: String) {
        Shell.run("/usr/bin/open", ["-a", "Terminal", folder])
    }

    static func toggleFinder() {
        if let finder = NSRunningApplication.runningApplications(withBundleIdentifier: Apps.finder).first, finder.isActive {
            finder.hide()
        } else {
            Shell.appleScriptAsync("""
            tell application "Finder"
                if (count of Finder windows) = 0 then make new Finder window
                activate
            end tell
            """)
        }
    }

    static func copyToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    // MARK: Finder extension (context menu)

    static let extensionID = "com.lightmaster.overdrive.finder"
    static let extensionNotification = Notification.Name("com.lightmaster.overdrive.finder.action")
    private static var extensionObserver: NSObjectProtocol?

    static func startExtension() {
        Shell.runAsync("/usr/bin/pluginkit", ["-e", "use", "-i", extensionID])
        // Requests from the Finder extension: it is sandboxed, so the app does the file work.
        // Distributed notifications can only come from local processes (never from a web page).
        extensionObserver = DistributedNotificationCenter.default().addObserver(
            forName: extensionNotification, object: nil, queue: .main
        ) { note in
            let payload = note.object as? String
            MainActor.assumeIsolated {
                guard ToolManager.shared.tool("finder.extension").map(ToolManager.shared.isOn) == true,
                      let payload else { return }
                handleExtensionRequest(payload)
            }
        }
    }

    static func stopExtension() {
        Shell.runAsync("/usr/bin/pluginkit", ["-e", "ignore", "-i", extensionID])
        if let extensionObserver { DistributedNotificationCenter.default().removeObserver(extensionObserver) }
        extensionObserver = nil
    }

    static func openExtensionSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.ExtensionsPreferences") {
            NSWorkspace.shared.open(url)
        }
    }

    struct ExtensionRequest: Codable {
        var action: String
        var paths: [String]
        var target: String?
    }

    static func handleExtensionRequest(_ json: String) {
        guard let request = try? JSONDecoder().decode(ExtensionRequest.self, from: Data(json.utf8)) else { return }
        // Only existing absolute paths.
        let paths = request.paths.filter { $0.hasPrefix("/") && FileManager.default.fileExists(atPath: $0) }
        let target = request.target.flatMap { FileManager.default.fileExists(atPath: $0) ? $0 : nil }
        switch request.action {
        case "newTextFile":
            newTextFile(in: target ?? paths.first.map { ($0 as NSString).deletingLastPathComponent })
        case "terminal":
            let folder = paths.count == 1 && isDirectory(paths[0]) ? paths[0] : target ?? paths.first.map {
                ($0 as NSString).deletingLastPathComponent
            }
            if let folder { DispatchQueue.global().async { openTerminal(at: folder) } }
        case "checksum":
            copyChecksums(paths)
        case "executable":
            for path in paths { makeExecutable(path) }
            feedback("terminal", S.madeExecutable(paths.count))
        case "symlink":
            for path in paths {
                let source = URL(fileURLWithPath: path)
                let link = uniqueURL(in: source.deletingLastPathComponent(), name: S.symlinkName(source.lastPathComponent))
                try? FileManager.default.createSymbolicLink(at: link, withDestinationURL: source)
            }
        case "unquarantine":
            for path in paths { removeQuarantine(path) }
            feedback("checkmark.shield", S.unquarantined(paths.count))
        case "toggleHidden":
            toggleHiddenFiles()
        case "deleteNow":
            deleteImmediately(paths)
        case "copyContents":
            if let path = paths.first, let text = try? String(contentsOfFile: path, encoding: .utf8) {
                copyToPasteboard(text)
                feedback("doc.on.clipboard", S.contentsCopied)
            }
        default:
            break
        }
    }

    nonisolated static func isDirectory(_ path: String) -> Bool {
        var dir: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &dir) && dir.boolValue
    }

    nonisolated static func makeExecutable(_ path: String) {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let mode = (attrs[.posixPermissions] as? NSNumber)?.uint16Value else { return }
        // Execute permission wherever there is read permission.
        let exec = (mode & 0o444) >> 2
        try? FileManager.default.setAttributes([.posixPermissions: NSNumber(value: mode | exec)], ofItemAtPath: path)
    }

    nonisolated static func removeQuarantine(_ path: String) {
        removexattr(path, "com.apple.quarantine", XATTR_NOFOLLOW)
        guard isDirectory(path), let e = FileManager.default.enumerator(atPath: path) else { return }
        while let sub = e.nextObject() as? String {
            removexattr((path as NSString).appendingPathComponent(sub), "com.apple.quarantine", XATTR_NOFOLLOW)
        }
    }

    static func copyChecksums(_ paths: [String]) {
        let files = paths.filter { !isDirectory($0) }
        guard !files.isEmpty else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            let lines = files.compactMap { path -> String? in
                guard let hash = sha256(path) else { return nil }
                return files.count == 1 ? hash : "\(hash)  \((path as NSString).lastPathComponent)"
            }
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    copyToPasteboard(lines.joined(separator: "\n"))
                    feedback("number", S.checksumCopied)
                }
            }
        }
    }

    /// SHA-256 of a file, read in 1 MB chunks (works with very large files).
    nonisolated static func sha256(_ path: String) -> String? {
        guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? handle.close() }
        var hasher = SHA256()
        while true {
            let chunk = handle.readData(ofLength: 1 << 20)
            if chunk.isEmpty { break }
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    static func deleteImmediately(_ paths: [String]) {
        guard !paths.isEmpty else { return }
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = S.deleteNowTitle(paths.count)
        alert.informativeText = S.deleteNowDetail
        alert.addButton(withTitle: S.delete)
        alert.addButton(withTitle: S.cancel)
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        for path in paths {
            do { try FileManager.default.removeItem(atPath: path) } catch {
                NSLog("Overdrive: could not delete \(path): \(error.localizedDescription)")
            }
        }
    }
}
