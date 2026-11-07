import AppKit
import Carbon
import CoreGraphics

/// One event tap shared by every tool that needs to see or change keyboard and mouse events.
/// Requires the Accessibility permission. Handlers run on the main thread and must be fast:
/// they decide, then do any slow work asynchronously.
@MainActor
final class EventTap {
    static let shared = EventTap()

    enum Result { case pass, consume }
    typealias Handler = (CGEventType, CGEvent) -> Result

    /// Marks events Overdrive posts itself, so handlers never see them.
    nonisolated static let syntheticMarker: Int64 = 0x4F56_4452

    private var handlers: [(id: String, handler: Handler)] = []
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var retryTimer: Timer?

    var isRunning: Bool { tap.map { CGEvent.tapIsEnabled(tap: $0) } ?? false }

    func add(_ id: String, _ handler: @escaping Handler) {
        handlers.removeAll { $0.id == id }
        handlers.append((id, handler))
        startIfNeeded()
    }

    func remove(_ id: String) {
        handlers.removeAll { $0.id == id }
        if handlers.isEmpty { stop() }
    }

    /// Called again when the Accessibility permission is granted.
    func startIfNeeded() {
        guard tap == nil, !handlers.isEmpty else { return }
        guard AXIsProcessTrusted() else {
            // Try again regularly: the permission may be granted later.
            if retryTimer == nil {
                retryTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
                    MainActor.assumeIsolated {
                        guard AXIsProcessTrusted() else { return }
                        EventTap.shared.retryTimer?.invalidate()
                        EventTap.shared.retryTimer = nil
                        EventTap.shared.startIfNeeded()
                    }
                }
            }
            return
        }
        var mask: CGEventMask = 0
        for type: CGEventType in [.keyDown, .keyUp, .flagsChanged, .leftMouseDown, .leftMouseUp, .rightMouseDown,
                                  .rightMouseUp, .otherMouseDown, .otherMouseUp, .scrollWheel] {
            mask |= 1 << type.rawValue
        }
        mask |= 1 << 14 // NX_SYSDEFINED: media keys
        let callback: CGEventTapCallBack = { _, type, event, _ in
            MainActor.assumeIsolated { EventTap.shared.handle(type, event) }
        }
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                          options: .defaultTap, eventsOfInterest: mask,
                                          callback: callback, userInfo: nil) else {
            NSLog("Overdrive: could not create the event tap")
            return
        }
        self.tap = tap
        source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        source = nil
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        if event.getIntegerValueField(.eventSourceUserData) == Self.syntheticMarker {
            return Unmanaged.passUnretained(event)
        }
        for entry in handlers where entry.handler(type, event) == .consume {
            return nil
        }
        return Unmanaged.passUnretained(event)
    }

    // MARK: Posting events

    nonisolated static func postKey(_ keyCode: Int, flags: CGEventFlags = [], to pid: pid_t? = nil) {
        let source = CGEventSource(stateID: .hidSystemState)
        for down in [true, false] {
            guard let e = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(keyCode), keyDown: down) else { continue }
            e.flags = flags
            e.setIntegerValueField(.eventSourceUserData, value: syntheticMarker)
            if let pid { e.postToPid(pid) } else { e.post(tap: .cgSessionEventTap) }
        }
    }
}

extension CGEvent {
    var keyCode: Int { Int(getIntegerValueField(.keyboardEventKeycode)) }

    /// Only the four modifiers that matter for shortcuts.
    var modifiers: CGEventFlags {
        flags.intersection([.maskCommand, .maskShift, .maskAlternate, .maskControl])
    }

    var isAutoRepeat: Bool { getIntegerValueField(.keyboardEventAutorepeat) != 0 }
}
