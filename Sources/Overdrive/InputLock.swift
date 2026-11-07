import AppKit
import Carbon
import SwiftUI

/// Cleaning Mode (black screen, keyboard and mouse locked) and Cat Mode (input locked, screen on).
/// Hold Escape for two seconds to leave.
@MainActor
enum InputLock {
    private static var windows: [NSWindow] = []
    private static var escapeSince: Date?
    private static var exitTimer: Timer?
    private static var startedAt = Date()
    /// Safety net: the lock never lasts more than this.
    private static let maximumDuration: TimeInterval = 15 * 60
    private static let model = LockModel()

    static var isActive: Bool { !windows.isEmpty }

    static func start(cleaning: Bool) {
        guard !isActive else { return }
        guard AXIsProcessTrusted() else { return Permission.accessibility.request() }
        model.cleaning = cleaning
        model.progress = 0
        startedAt = Date()
        for screen in NSScreen.screens {
            let window = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
            window.level = .screenSaver
            window.isOpaque = cleaning
            window.backgroundColor = cleaning ? .black : .clear
            window.ignoresMouseEvents = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            window.contentView = NSHostingView(rootView: LockView(model: model))
            window.setFrame(screen.frame, display: true)
            window.orderFrontRegardless()
            windows.append(window)
        }
        if cleaning { NSCursor.hide() }
        EventTap.shared.add("inputLock") { type, event in
            if event.keyCode == kVK_Escape {
                if type == .keyDown, escapeSince == nil { escapeSince = Date() }
                if type == .keyUp { escapeSince = nil; model.progress = 0 }
            }
            // Everything is swallowed: keys, clicks, scrolling, media keys.
            return .consume
        }
        exitTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            MainActor.assumeIsolated {
                if Date().timeIntervalSince(startedAt) > maximumDuration { return stop() }
                // If the event tap stopped (permission removed), the input is no longer locked.
                if !EventTap.shared.isRunning { return stop() }
                guard let since = escapeSince else { return }
                let held = Date().timeIntervalSince(since)
                model.progress = min(held / 2, 1)
                if held >= 2 { stop() }
            }
        }
    }

    static func stop() {
        EventTap.shared.remove("inputLock")
        exitTimer?.invalidate()
        exitTimer = nil
        escapeSince = nil
        if model.cleaning { NSCursor.unhide() }
        for window in windows { window.orderOut(nil) }
        windows = []
    }
}

private final class LockModel: ObservableObject {
    @Published var cleaning = true
    @Published var progress: Double = 0
}

private struct LockView: View {
    @ObservedObject var model: LockModel

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: model.cleaning ? "sparkles" : "pawprint.fill")
                .font(.system(size: 44))
            Text(model.cleaning ? S.cleaningMode : S.catMode)
                .font(.system(size: 22, weight: .semibold))
            Text(S.holdEscape)
                .font(.system(size: 14))
                .opacity(0.7)
            ProgressView(value: model.progress)
                .frame(width: 180)
                .opacity(model.progress > 0 ? 1 : 0)
        }
        .foregroundStyle(.white)
        .padding(30)
        .background(model.cleaning ? Color.clear : Color.black.opacity(0.55),
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: model.cleaning ? .center : .bottom)
        .padding(.bottom, model.cleaning ? 0 : 80)
    }
}
