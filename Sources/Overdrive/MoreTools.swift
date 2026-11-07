import AppKit
import AudioToolbox
import Carbon
import CoreAudio
import IOKit.pwr_mgt

// MARK: - Audio

@MainActor
enum AudioTools {
    private static func address(_ selector: AudioObjectPropertySelector, _ scope: AudioObjectPropertyScope) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    static func defaultDevice(input: Bool) -> AudioDeviceID {
        (try? AudioObjectID.system.read(input ? kAudioHardwarePropertyDefaultInputDevice : kAudioHardwarePropertyDefaultOutputDevice,
                                        default: AudioDeviceID.unknown)) ?? .unknown
    }

    static func channels(_ device: AudioDeviceID, input: Bool) -> Int {
        var a = address(kAudioDevicePropertyStreamConfiguration, input ? kAudioObjectPropertyScopeInput : kAudioObjectPropertyScopeOutput)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(device, &a, 0, nil, &size) == noErr, size > 0 else { return 0 }
        let raw = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { raw.deallocate() }
        guard AudioObjectGetPropertyData(device, &a, 0, nil, &size, raw) == noErr else { return 0 }
        return UnsafeMutableAudioBufferListPointer(raw.assumingMemoryBound(to: AudioBufferList.self))
            .reduce(0) { $0 + Int($1.mNumberChannels) }
    }

    static func devices(input: Bool) -> [AudioDeviceID] {
        let all = (try? AudioObjectID.system.readArray(kAudioHardwarePropertyDevices, element: AudioDeviceID.unknown)) ?? []
        return all.filter { channels($0, input: input) > 0 && !$0.deviceUID.hasPrefix("com.lightmaster.") }
    }

    static func isMuted(input: Bool) -> Bool {
        let device = defaultDevice(input: input)
        var a = address(kAudioDevicePropertyMute, input ? kAudioObjectPropertyScopeInput : kAudioObjectPropertyScopeOutput)
        if AudioObjectHasProperty(device, &a) {
            var value: UInt32 = 0
            var size = UInt32(MemoryLayout<UInt32>.size)
            if AudioObjectGetPropertyData(device, &a, 0, nil, &size, &value) == noErr { return value != 0 }
        }
        return input && (volume(device, input: true) ?? 1) == 0
    }

    static func setMuted(_ muted: Bool, input: Bool) {
        let device = defaultDevice(input: input)
        var a = address(kAudioDevicePropertyMute, input ? kAudioObjectPropertyScopeInput : kAudioObjectPropertyScopeOutput)
        var settable: DarwinBoolean = false
        if AudioObjectHasProperty(device, &a), AudioObjectIsPropertySettable(device, &a, &settable) == noErr, settable.boolValue {
            var value: UInt32 = muted ? 1 : 0
            AudioObjectSetPropertyData(device, &a, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value)
            return
        }
        // Microphones without a mute switch: set the input volume to zero and back.
        if input {
            if muted {
                Prefs.setInt("micVolumeBeforeMute", Int((volume(device, input: true) ?? 1) * 100))
                setVolume(device, 0, input: true)
            } else {
                setVolume(device, Float(Prefs.int("micVolumeBeforeMute", default: 80)) / 100, input: true)
            }
        }
    }

    static func volume(_ device: AudioDeviceID, input: Bool) -> Float? {
        let scope = input ? kAudioObjectPropertyScopeInput : kAudioObjectPropertyScopeOutput
        for (selector, element) in [(kAudioHardwareServiceDeviceProperty_VirtualMainVolume, kAudioObjectPropertyElementMain),
                                    (kAudioDevicePropertyVolumeScalar, kAudioObjectPropertyElementMain),
                                    (kAudioDevicePropertyVolumeScalar, 1)] {
            var a = AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: element)
            guard AudioObjectHasProperty(device, &a) else { continue }
            var value: Float32 = 0
            var size = UInt32(MemoryLayout<Float32>.size)
            if AudioObjectGetPropertyData(device, &a, 0, nil, &size, &value) == noErr { return value }
        }
        return nil
    }

    static func setVolume(_ device: AudioDeviceID, _ v: Float, input: Bool) {
        let scope = input ? kAudioObjectPropertyScopeInput : kAudioObjectPropertyScopeOutput
        var value = Float32(min(max(v, 0), 1))
        var a = AudioObjectPropertyAddress(mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
                                           mScope: scope, mElement: kAudioObjectPropertyElementMain)
        var settable: DarwinBoolean = false
        if AudioObjectHasProperty(device, &a), AudioObjectIsPropertySettable(device, &a, &settable) == noErr, settable.boolValue,
           AudioObjectSetPropertyData(device, &a, 0, nil, UInt32(MemoryLayout<Float32>.size), &value) == noErr {
            return
        }
        for element: UInt32 in [kAudioObjectPropertyElementMain, 1, 2] {
            a = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyVolumeScalar, mScope: scope, mElement: element)
            if AudioObjectHasProperty(device, &a) {
                AudioObjectSetPropertyData(device, &a, 0, nil, UInt32(MemoryLayout<Float32>.size), &value)
            }
        }
    }

    static func toggleMute(input: Bool) {
        let muted = !isMuted(input: input)
        setMuted(muted, input: input)
        if input {
            feedback(muted ? "mic.slash.fill" : "mic.fill", muted ? S.micMuted : S.micOn)
        } else {
            feedback(muted ? "speaker.slash.fill" : "speaker.wave.2.fill", muted ? S.soundMuted : S.soundOn)
        }
    }

    static func cycle(input: Bool) {
        let list = devices(input: input)
        guard !list.isEmpty else { return }
        let current = defaultDevice(input: input)
        let next = list[((list.firstIndex(of: current) ?? -1) + 1) % list.count]
        var id = next
        var a = address(input ? kAudioHardwarePropertyDefaultInputDevice : kAudioHardwarePropertyDefaultOutputDevice,
                        kAudioObjectPropertyScopeGlobal)
        AudioObjectSetPropertyData(.system, &a, 0, nil, UInt32(MemoryLayout<AudioDeviceID>.size), &id)
        feedback(input ? "mic" : "hifispeaker", next.name)
    }

    // Cap the volume after wake or unlock (no surprise blast in a quiet room).

    private static var observers: [NSObjectProtocol] = []

    static func startVolumeCap() {
        let cap = {
            MainActor.assumeIsolated {
                let device = defaultDevice(input: false)
                let limit = Float(Prefs.int("volumeCap", default: 50)) / 100
                if let v = volume(device, input: false), v > limit { setVolume(device, limit, input: false) }
            }
        }
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { _ in cap() })
        observers.append(DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.screenIsUnlocked"), object: nil, queue: .main) { _ in cap() })
    }

    static func stopVolumeCap() {
        for o in observers {
            NSWorkspace.shared.notificationCenter.removeObserver(o)
            DistributedNotificationCenter.default().removeObserver(o)
        }
        observers = []
    }
}

// MARK: - Clipboard

@MainActor
enum ClipboardTools {
    static func clear() {
        NSPasteboard.general.clearContents()
        feedback("clipboard", S.clipboardCleared)
    }

    private static var timer: Timer?
    private static var lastChange = NSPasteboard.general.changeCount
    private static var changedAt = Date()

    static func startAutoClear() {
        lastChange = NSPasteboard.general.changeCount
        changedAt = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
            MainActor.assumeIsolated {
                let count = NSPasteboard.general.changeCount
                if count != lastChange {
                    lastChange = count
                    changedAt = Date()
                    return
                }
                let delay = TimeInterval(Prefs.int("clipboardSeconds", default: 60))
                guard Date().timeIntervalSince(changedAt) >= delay,
                      !(NSPasteboard.general.pasteboardItems ?? []).isEmpty else { return }
                NSPasteboard.general.clearContents()
                lastChange = NSPasteboard.general.changeCount
            }
        }
    }

    static func stopAutoClear() {
        timer?.invalidate()
        timer = nil
    }

    private static var lockObservers: [NSObjectProtocol] = []

    static func startClearOnLock() {
        let clear = { MainActor.assumeIsolated { NSPasteboard.general.clearContents() } }
        lockObservers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { _ in clear() })
        lockObservers.append(DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.screenIsLocked"), object: nil, queue: .main) { _ in clear() })
    }

    static func stopClearOnLock() {
        for o in lockObservers {
            NSWorkspace.shared.notificationCenter.removeObserver(o)
            DistributedNotificationCenter.default().removeObserver(o)
        }
        lockObservers = []
    }
}

// MARK: - Files

@MainActor
enum FileTools {
    static var downloads: URL { FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0] }

    /// Files still being downloaded.
    nonisolated static func isInProgress(_ url: URL) -> Bool {
        ["download", "crdownload", "part", "partial", "opdownload"].contains(url.pathExtension.lowercased())
    }

    static func emptyTrash() {
        let alert = NSAlert()
        alert.messageText = S.emptyTrashTitle
        alert.informativeText = S.emptyTrashDetail
        alert.addButton(withTitle: S.emptyTrash)
        alert.addButton(withTitle: S.cancel)
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        Shell.appleScriptAsync("tell application \"Finder\" to empty trash")
    }

    static func ejectAll() {
        let keys: [URLResourceKey] = [.volumeIsEjectableKey, .volumeIsRemovableKey, .volumeIsRootFileSystemKey, .volumeNameKey]
        let exclusions = Set(Prefs.strings("ejectExclusions").map { $0.lowercased() })
        let volumes = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) ?? []
        var count = 0
        for volume in volumes {
            guard let values = try? volume.resourceValues(forKeys: Set(keys)),
                  values.volumeIsRootFileSystem != true,
                  values.volumeIsEjectable == true || values.volumeIsRemovable == true,
                  !exclusions.contains((values.volumeName ?? "").lowercased()) else { continue }
            if (try? NSWorkspace.shared.unmountAndEjectDevice(at: volume)) != nil { count += 1 }
        }
        feedback("eject", S.disksEjected(count))
    }

    // Archive old Downloads

    private static var archiveTimer: Timer?

    static func startArchiveDownloads() {
        archiveDownloads()
        archiveTimer = Timer.scheduledTimer(withTimeInterval: 6 * 3600, repeats: true) { _ in
            MainActor.assumeIsolated { archiveDownloads() }
        }
    }

    static func stopArchiveDownloads() {
        archiveTimer?.invalidate()
        archiveTimer = nil
    }

    static func archiveDownloads() {
        let days = Prefs.int("downloadsDays", default: 30)
        let folder = downloads
        DispatchQueue.global(qos: .utility).async {
            archive(in: folder, olderThan: days, into: folder.appendingPathComponent(S.archiveFolderName)) { _ in true }
        }
    }

    /// Moves the items of a folder added more than `days` ago into an archive subfolder.
    nonisolated static func archive(in folder: URL, olderThan days: Int, into archive: URL, where include: (URL) -> Bool) {
        let keys: [URLResourceKey] = [.addedToDirectoryDateKey, .creationDateKey]
        guard let items = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: keys,
                                                                         options: [.skipsHiddenFiles]) else { return }
        let limit = Date().addingTimeInterval(-TimeInterval(max(days, 1)) * 86400)
        for item in items where item.standardizedFileURL != archive.standardizedFileURL && !isInProgress(item) && include(item) {
            let values = try? item.resourceValues(forKeys: Set(keys))
            guard let date = values?.addedToDirectoryDate ?? values?.creationDate, date < limit else { continue }
            try? FileManager.default.createDirectory(at: archive, withIntermediateDirectories: true)
            let target = FinderTools.uniqueURL(in: archive, name: item.lastPathComponent)
            try? FileManager.default.moveItem(at: item, to: target)
        }
    }

    // Watch Downloads: lowercase extensions, AirDrop folder

    private static var watcher: DispatchSourceFileSystemObject?
    private static var watchFD: Int32 = -1

    /// Starts or stops the Downloads watcher depending on the tools that need it.
    static func updateDownloadsWatcher() {
        let manager = ToolManager.shared
        let needed = ["files.lowercase", "files.airdrop"].contains { manager.tool($0).map(manager.isOn) == true }
        if needed, watcher == nil {
            let fd = open(downloads.path, O_EVTONLY)
            guard fd >= 0 else { return }
            watchFD = fd
            let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .rename], queue: .main)
            source.setEventHandler {
                MainActor.assumeIsolated {
                    // Wait for writes to settle.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { MainActor.assumeIsolated { processDownloads() } }
                }
            }
            source.setCancelHandler { close(fd) }
            source.resume()
            watcher = source
            processDownloads()
        } else if !needed, let watcher {
            watcher.cancel()
            self.watcher = nil
        }
    }

    private static func processDownloads() {
        let manager = ToolManager.shared
        let lowercase = manager.tool("files.lowercase").map(manager.isOn) == true
        let airdrop = manager.tool("files.airdrop").map(manager.isOn) == true
        let folder = downloads
        let airdropFolder = URL(fileURLWithPath: Prefs.string("airdropFolder") ?? folder.appendingPathComponent("AirDrop").path)
        DispatchQueue.global(qos: .utility).async {
            guard let items = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil,
                                                                             options: [.skipsHiddenFiles]) else { return }
            for item in items where !isInProgress(item) {
                if airdrop, isFromAirDrop(item), airdropFolder.standardizedFileURL != folder.standardizedFileURL {
                    try? FileManager.default.createDirectory(at: airdropFolder, withIntermediateDirectories: true)
                    let target = FinderTools.uniqueURL(in: airdropFolder, name: item.lastPathComponent)
                    if (try? FileManager.default.moveItem(at: item, to: target)) != nil { continue }
                }
                if lowercase {
                    let ext = item.pathExtension
                    guard !ext.isEmpty, ext != ext.lowercased(), !FinderTools.isDirectory(item.path) else { continue }
                    let renamed = item.deletingPathExtension().appendingPathExtension(ext.lowercased())
                    // Case-insensitive disks: renaming in two steps.
                    let temp = item.deletingLastPathComponent().appendingPathComponent(".overdrive-\(UUID().uuidString)")
                    if (try? FileManager.default.moveItem(at: item, to: temp)) != nil {
                        if (try? FileManager.default.moveItem(at: temp, to: renamed)) == nil {
                            try? FileManager.default.moveItem(at: temp, to: item)
                        }
                    }
                }
            }
        }
    }

    /// Files received with AirDrop are quarantined by "sharingd".
    nonisolated static func isFromAirDrop(_ url: URL) -> Bool {
        var buffer = [UInt8](repeating: 0, count: 256)
        let n = getxattr(url.path, "com.apple.quarantine", &buffer, buffer.count, 0, XATTR_NOFOLLOW)
        guard n > 0 else { return false }
        let value = String(decoding: buffer.prefix(n), as: UTF8.self)
        return value.contains(";sharingd;") || value.contains(";AirDrop;")
    }
}

// MARK: - Screenshots

@MainActor
enum ScreenshotTools {
    static var folder: URL {
        if let path = Shell.defaultsRead("com.apple.screencapture", "location"), !path.isEmpty {
            let expanded = (path as NSString).expandingTildeInPath
            if FinderTools.isDirectory(expanded) { return URL(fileURLWithPath: expanded) }
        }
        return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]
    }

    /// Screenshots carry the kMDItemIsScreenCapture attribute, whatever the language of their name.
    nonisolated static func isScreenshot(_ url: URL) -> Bool {
        getxattr(url.path, "com.apple.metadata:kMDItemIsScreenCapture", nil, 0, 0, 0) > 0
    }

    nonisolated static func latest(in folder: URL) -> URL? {
        let items = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.creationDateKey],
                                                                  options: [.skipsHiddenFiles])) ?? []
        return items.filter(isScreenshot).max {
            let a = (try? $0.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            let b = (try? $1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            return a < b
        }
    }

    static func openLatest() {
        if let url = latest(in: folder) {
            NSWorkspace.shared.open(url)
        } else {
            feedback("camera.viewfinder", S.noScreenshot)
        }
    }

    // Copy new screenshots to the clipboard

    private static var watcher: DispatchSourceFileSystemObject?
    private static var lastCopied: URL?

    static func startAutoCopy() {
        lastCopied = latest(in: folder)
        let fd = open(folder.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write], queue: .main)
        source.setEventHandler {
            MainActor.assumeIsolated {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    MainActor.assumeIsolated {
                        guard let url = latest(in: folder), url != lastCopied,
                              let image = NSImage(contentsOf: url) else { return }
                        lastCopied = url
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.writeObjects([image])
                    }
                }
            }
        }
        source.setCancelHandler { close(fd) }
        source.resume()
        watcher = source
    }

    static func stopAutoCopy() {
        watcher?.cancel()
        watcher = nil
    }

    static func setSetting(_ key: String, _ value: Bool) {
        Shell.defaultsWrite("com.apple.screencapture", key, "bool", value ? "true" : "false")
        Shell.restart("SystemUIServer")
    }

    // Archive old screenshots

    private static var archiveTimer: Timer?

    static func startArchive() {
        archive()
        archiveTimer = Timer.scheduledTimer(withTimeInterval: 6 * 3600, repeats: true) { _ in
            MainActor.assumeIsolated { archive() }
        }
    }

    static func stopArchive() {
        archiveTimer?.invalidate()
        archiveTimer = nil
    }

    private static func archive() {
        let days = Prefs.int("screenshotDays", default: 7)
        let folder = self.folder
        DispatchQueue.global(qos: .utility).async {
            FileTools.archive(in: folder, olderThan: days, into: folder.appendingPathComponent(S.screenshotArchiveName),
                              where: isScreenshot)
        }
    }
}

// MARK: - Display and appearance

@MainActor
enum DisplayTools {
    static var isDark: Bool { UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark" }

    static func toggleDarkMode() {
        Shell.appleScriptAsync("""
        tell application "System Events" to tell appearance preferences to set dark mode to not dark mode
        """)
    }

    // Night Shift and True Tone (CoreBrightness, private framework)

    private static let coreBrightness: Bool = {
        dlopen("/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness", RTLD_NOW) != nil
    }()

    private static func client(_ name: String) -> NSObject? {
        guard coreBrightness, let cls = NSClassFromString(name) as? NSObject.Type else { return nil }
        return cls.init()
    }

    private static func callBool(_ object: NSObject, _ selector: String, _ value: Bool) {
        let sel = NSSelectorFromString(selector)
        guard object.responds(to: sel) else { return }
        typealias Setter = @convention(c) (AnyObject, Selector, Bool) -> Bool
        let imp = object.method(for: sel)
        _ = unsafeBitCast(imp, to: Setter.self)(object, sel, value)
    }

    private static let blueLight = client("CBBlueLightClient")
    private static let trueToneClient = client("CBTrueToneClient")

    static var nightShiftAvailable: Bool { blueLight != nil }

    static var nightShiftOn: Bool {
        guard let blueLight else { return false }
        let sel = NSSelectorFromString("getBlueLightStatus:")
        guard blueLight.responds(to: sel) else { return false }
        // Status struct: active (BOOL), enabled (BOOL), …
        let status = UnsafeMutableRawPointer.allocate(byteCount: 64, alignment: 8)
        defer { status.deallocate() }
        status.initializeMemory(as: UInt8.self, repeating: 0, count: 64)
        typealias Getter = @convention(c) (AnyObject, Selector, UnsafeMutableRawPointer) -> Bool
        _ = unsafeBitCast(blueLight.method(for: sel), to: Getter.self)(blueLight, sel, status)
        return status.load(as: UInt8.self) != 0
    }

    static func toggleNightShift() {
        guard let blueLight else { return feedback("moon", S.notAvailable) }
        let on = !nightShiftOn
        callBool(blueLight, "setEnabled:", on)
        feedback(on ? "moon.fill" : "moon", "Night Shift — \(on ? S.on : S.off)")
    }

    static var trueToneOn: Bool {
        guard let trueToneClient, trueToneClient.responds(to: NSSelectorFromString("enabled")) else { return false }
        return (trueToneClient.value(forKey: "enabled") as? Bool) ?? false
    }

    static func toggleTrueTone() {
        guard let trueToneClient, (trueToneClient.value(forKey: "supported") as? Bool) == true else {
            return feedback("sun.max", S.notAvailable)
        }
        let on = !trueToneOn
        callBool(trueToneClient, "setEnabled:", on)
        feedback("sun.max", "True Tone — \(on ? S.on : S.off)")
    }

    // Grayscale (UniversalAccess, private framework)

    private typealias GrayscaleGet = @convention(c) () -> Bool
    private typealias GrayscaleSet = @convention(c) (Bool) -> Void
    private static let universalAccess = dlopen("/System/Library/PrivateFrameworks/UniversalAccess.framework/UniversalAccess", RTLD_NOW)

    static var grayscaleOn: Bool {
        guard let universalAccess, let sym = dlsym(universalAccess, "UAGrayscaleIsEnabled") else { return false }
        return unsafeBitCast(sym, to: GrayscaleGet.self)()
    }

    static func toggleGrayscale() {
        guard let universalAccess, let sym = dlsym(universalAccess, "UAGrayscaleSetEnabled") else {
            return feedback("circle.lefthalf.filled", S.notAvailable)
        }
        unsafeBitCast(sym, to: GrayscaleSet.self)(!grayscaleOn)
    }

    // Desktop icons

    static var desktopIconsShown: Bool { Shell.defaultsRead("com.apple.finder", "CreateDesktop") != "0" }

    static func toggleDesktopIcons() {
        let show = !desktopIconsShown
        Shell.defaultsWrite("com.apple.finder", "CreateDesktop", "bool", show ? "true" : "false")
        Shell.restart("Finder")
    }

    // Hot corners

    private static let corners = ["wvous-tl-corner", "wvous-tr-corner", "wvous-bl-corner", "wvous-br-corner"]

    static var hotCornersOn: Bool { Prefs.strings("savedHotCorners").isEmpty }

    static func toggleHotCorners() {
        if hotCornersOn {
            let saved = corners.map { Shell.defaultsRead("com.apple.dock", $0) ?? "1" }
            Prefs.setStrings("savedHotCorners", saved)
            for corner in corners { Shell.defaultsWrite("com.apple.dock", corner, "int", "1") }
            feedback("rectangle.dashed", S.hotCornersOff)
        } else {
            for (corner, value) in zip(corners, Prefs.strings("savedHotCorners")) {
                Shell.defaultsWrite("com.apple.dock", corner, "int", value)
            }
            Prefs.setStrings("savedHotCorners", [])
            feedback("rectangle.dashed", S.hotCornersOn)
        }
        Shell.restart("Dock")
    }

    static func sleepDisplays() { Shell.runAsync("/usr/bin/pmset", ["displaysleepnow"]) }

    static func startScreenSaver() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/CoreServices/ScreenSaverEngine.app"))
    }
}

// MARK: - System

@MainActor
enum SystemTools {
    static func lockScreen() {
        typealias Lock = @convention(c) () -> Void
        if let lib = dlopen("/System/Library/PrivateFrameworks/login.framework/Versions/Current/login", RTLD_NOW),
           let sym = dlsym(lib, "SACLockScreenImmediate") {
            unsafeBitCast(sym, to: Lock.self)()
        } else {
            EventTap.postKey(kVK_ANSI_Q, flags: [.maskCommand, .maskControl])
        }
    }

    static func flushDNS() {
        Shell.appleScriptAsync("""
        do shell script "dscacheutil -flushcache; killall -HUP mDNSResponder" with administrator privileges
        """) { status, _ in
            if status == 0 { feedback("network", S.dnsFlushed) }
        }
    }

    // Keep awake

    private static var assertion: IOPMAssertionID = 0
    static var isAwake: Bool { assertion != 0 }

    static func toggleKeepAwake() {
        if assertion != 0 {
            IOPMAssertionRelease(assertion)
            assertion = 0
            feedback("cup.and.saucer", S.keepAwakeOff)
        } else {
            let type = Prefs.isOn("keepAwake.display", default: true)
                ? kIOPMAssertionTypePreventUserIdleDisplaySleep : kIOPMAssertionTypePreventUserIdleSystemSleep
            IOPMAssertionCreateWithName(type as CFString, IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                        "Overdrive: Keep Awake" as CFString, &assertion)
            feedback("cup.and.saucer.fill", S.keepAwakeOn)
        }
    }

    // Default browser

    static var browsers: [URL] {
        guard let probe = URL(string: "https://example.com") else { return [] }
        return NSWorkspace.shared.urlsForApplications(toOpen: probe)
    }

    static var defaultBrowser: URL? {
        URL(string: "https://example.com").flatMap { NSWorkspace.shared.urlForApplication(toOpen: $0) }
    }

    static func setDefaultBrowser(_ app: URL) {
        Task {
            try? await NSWorkspace.shared.setDefaultApplication(at: app, toOpenURLsWithScheme: "http")
            try? await NSWorkspace.shared.setDefaultApplication(at: app, toOpenURLsWithScheme: "https")
        }
    }

    // TextEdit opens a blank document

    static func setTextEditBlank(_ on: Bool) {
        if on {
            Shell.defaultsWrite("com.apple.TextEdit", "NSShowAppCentricOpenPanelInsteadOfUntitledFile", "bool", "false")
        } else {
            Shell.defaultsDelete("com.apple.TextEdit", "NSShowAppCentricOpenPanelInsteadOfUntitledFile")
        }
    }

    static func openPane(_ url: String) {
        if let u = URL(string: url) { NSWorkspace.shared.open(u) }
    }
}

// MARK: - Utilities

@MainActor
enum UtilityTools {
    // Shortcuts app

    private(set) static var shortcuts: [String] = []

    static func refreshShortcuts() {
        Shell.runAsync("/usr/bin/shortcuts", ["list"]) { status, output in
            guard status == 0 else { return }
            shortcuts = output.split(separator: "\n").map(String.init).filter { !$0.isEmpty }.sorted()
        }
    }

    static func runShortcut(_ name: String) {
        Shell.runAsync("/usr/bin/shortcuts", ["run", name])
    }

    // Clear notifications (Accessibility, best effort)

    static func clearNotifications() {
        guard let center = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.notificationcenterui").first else { return }
        let app = AX.app(center.processIdentifier)
        var cleared = 0
        func visit(_ element: AXUIElement, depth: Int) {
            guard depth < 12 else { return }
            var names: CFArray?
            if AXUIElementCopyActionNames(element, &names) == .success, let actions = names as? [String] {
                // "Clear All" for groups first, then "Close" for single notifications.
                if let action = actions.first(where: { $0.localizedCaseInsensitiveContains("clear all") })
                    ?? actions.first(where: { $0.localizedCaseInsensitiveContains("close") }) {
                    if AXUIElementPerformAction(element, action as CFString) == .success { cleared += 1 }
                }
            }
            for child in (AX.attribute(element, kAXChildrenAttribute) as [AXUIElement]?) ?? [] {
                visit(child, depth: depth + 1)
            }
        }
        for _ in 0..<3 {
            let windows: [AXUIElement] = AX.attribute(app, kAXWindowsAttribute) ?? []
            for window in windows { visit(window, depth: 0) }
        }
        feedback("bell.slash", cleared > 0 ? S.notificationsCleared : S.noNotifications)
    }
}
