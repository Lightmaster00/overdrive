import AppKit
import Carbon
import CoreGraphics

@MainActor
enum KeyboardTools {
    // MARK: Hyper key

    /// HID usages: Caps Lock and F18 (Caps Lock is remapped to F18, which then acts as ⌃⌥⇧⌘).
    nonisolated static let capsLockUsage: UInt64 = 0x7_0000_0039
    nonisolated static let f18Usage: UInt64 = 0x7_0000_006D

    private static var hyperDown = false
    private static var hyperUsed = false
    private static var wakeObserver: NSObjectProtocol?

    private static var mappingTimer: Timer?

    static func startHyper() {
        // Caps Lock is only remapped once the event tap runs (Accessibility allowed):
        // otherwise it would become a dead key.
        mappingTimer?.invalidate()
        mappingTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            MainActor.assumeIsolated {
                guard EventTap.shared.isRunning else { return }
                timer.invalidate()
                mappingTimer = nil
                applyCapsLockMapping(true)
            }
        }
        // Mappings are lost after sleep on some keyboards: apply again on wake.
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                if EventTap.shared.isRunning { applyCapsLockMapping(true) }
            }
        }
        EventTap.shared.add("keyboard.hyper") { type, event in
            if event.keyCode == kVK_F18, type == .keyDown || type == .keyUp {
                if type == .keyDown {
                    if !event.isAutoRepeat {
                        hyperDown = true
                        hyperUsed = false
                    }
                } else {
                    hyperDown = false
                    if !hyperUsed, Prefs.isOn("keyboard.hyper.escape", default: true) {
                        EventTap.postKey(kVK_Escape)
                    }
                }
                return .consume
            }
            if hyperDown, type == .keyDown || type == .keyUp {
                hyperUsed = true
                event.flags.formUnion([.maskCommand, .maskAlternate, .maskControl, .maskShift])
            }
            return .pass
        }
    }

    static func stopHyper() {
        mappingTimer?.invalidate()
        mappingTimer = nil
        EventTap.shared.remove("keyboard.hyper")
        if let wakeObserver { NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver) }
        wakeObserver = nil
        applyCapsLockMapping(false)
        hyperDown = false
    }

    /// Adds or removes Caps Lock → F18 in the user key mappings, keeping any other mapping.
    nonisolated static func applyCapsLockMapping(_ on: Bool) {
        let current = Shell.run("/usr/bin/hidutil", ["property", "--get", "UserKeyMapping"]).output
        var pairs = parseMappings(current).filter { $0.src != capsLockUsage }
        if on { pairs.append((capsLockUsage, f18Usage)) }
        let json = "{\"UserKeyMapping\":[" + pairs.map {
            "{\"HIDKeyboardModifierMappingSrc\":\($0.src),\"HIDKeyboardModifierMappingDst\":\($0.dst)}"
        }.joined(separator: ",") + "]}"
        Shell.run("/usr/bin/hidutil", ["property", "--set", json])
    }

    /// Reads hidutil's output ("HIDKeyboardModifierMappingDst = …; …Src = …;" blocks).
    nonisolated static func parseMappings(_ text: String) -> [(src: UInt64, dst: UInt64)] {
        var result: [(UInt64, UInt64)] = []
        for block in text.components(separatedBy: "}") {
            func value(_ name: String) -> UInt64? {
                guard let range = block.range(of: name) else { return nil }
                let rest = block[range.upperBound...].drop { !$0.isNumber }
                return UInt64(rest.prefix { $0.isNumber })
            }
            if let src = value("HIDKeyboardModifierMappingSrc"), let dst = value("HIDKeyboardModifierMappingDst") {
                result.append((src, dst))
            }
        }
        return result
    }

    // MARK: Caps Lock delay

    static func setCapsLockDelay(removed: Bool) {
        Shell.runAsync("/usr/bin/hidutil", ["property", "--set", "{\"CapsLockDelayOverride\":\(removed ? 0 : 75)}"])
    }

    // MARK: Safari: Delete goes back

    static func startSafariDelete() {
        EventTap.shared.add("keyboard.safariDelete") { type, event in
            guard type == .keyDown, event.keyCode == kVK_Delete, Apps.isFrontmost("com.apple.Safari"),
                  event.modifiers.isEmpty || event.modifiers == .maskShift, !AX.isEditingText() else { return .pass }
            let key = event.modifiers == .maskShift ? kVK_ANSI_RightBracket : kVK_ANSI_LeftBracket
            if let safari = Apps.frontmost { EventTap.postKey(key, flags: .maskCommand, to: safari.processIdentifier) }
            return .consume
        }
    }

    static func stopSafariDelete() { EventTap.shared.remove("keyboard.safariDelete") }
}

// MARK: - Mouse and trackpad

@MainActor
enum MouseTools {
    // Three-finger click = middle click (MultitouchSupport, private framework).

    private typealias DeviceList = @convention(c) () -> Unmanaged<CFArray>
    private typealias FrameCallback = @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, Int32, Double, Int32) -> Int32
    private typealias Register = @convention(c) (UnsafeMutableRawPointer, FrameCallback) -> Void
    private typealias Start = @convention(c) (UnsafeMutableRawPointer, Int32) -> Void
    private typealias Stop = @convention(c) (UnsafeMutableRawPointer) -> Void

    /// Fingers currently on the trackpad (written by the multitouch thread).
    nonisolated(unsafe) private static var fingers: Int32 = 0
    private static var devices: [UnsafeMutableRawPointer] = []
    /// Keeps the device objects alive while they are used.
    private static var deviceObjects: [AnyObject] = []
    private static var convertingUp = false

    static func startMiddleClick() {
        guard let lib = dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_NOW),
              let listSym = dlsym(lib, "MTDeviceCreateList"),
              let registerSym = dlsym(lib, "MTRegisterContactFrameCallback"),
              let startSym = dlsym(lib, "MTDeviceStart") else {
            NSLog("Overdrive: MultitouchSupport unavailable")
            return
        }
        let list = unsafeBitCast(listSym, to: DeviceList.self)().takeRetainedValue() as [AnyObject]
        let register = unsafeBitCast(registerSym, to: Register.self)
        let start = unsafeBitCast(startSym, to: Start.self)
        let callback: FrameCallback = { _, _, count, _, _ in
            MouseTools.fingers = count
            return 0
        }
        deviceObjects = list
        devices = list.map { Unmanaged.passUnretained($0).toOpaque() }
        for device in devices {
            register(device, callback)
            start(device, 0)
        }
        EventTap.shared.add("mouse.middleClick") { type, event in
            if type == .leftMouseDown, fingers == 3 {
                event.type = .otherMouseDown
                event.setIntegerValueField(.mouseEventButtonNumber, value: 2)
                convertingUp = true
            } else if type == .leftMouseUp, convertingUp {
                event.type = .otherMouseUp
                event.setIntegerValueField(.mouseEventButtonNumber, value: 2)
                convertingUp = false
            }
            return .pass
        }
    }

    static func stopMiddleClick() {
        EventTap.shared.remove("mouse.middleClick")
        if let lib = dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_NOW),
           let stopSym = dlsym(lib, "MTDeviceStop") {
            let stop = unsafeBitCast(stopSym, to: Stop.self)
            for device in devices { stop(device) }
        }
        devices = []
        deviceObjects = []
        fingers = 0
    }

    // Center the pointer after wake or unlock

    private static var observers: [NSObjectProtocol] = []

    static func startCenterOnWake() {
        let center = { MainActor.assumeIsolated { centerPointer() } }
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { _ in center() })
        observers.append(DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.screenIsUnlocked"), object: nil, queue: .main) { _ in center() })
    }

    static func stopCenterOnWake() {
        for o in observers {
            NSWorkspace.shared.notificationCenter.removeObserver(o)
            DistributedNotificationCenter.default().removeObserver(o)
        }
        observers = []
    }

    static func centerPointer() {
        let bounds = CGDisplayBounds(CGMainDisplayID())
        CGWarpMouseCursorPosition(CGPoint(x: bounds.midX, y: bounds.midY))
        CGAssociateMouseAndMouseCursorPosition(1)
    }
}
