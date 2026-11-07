import AppKit
@preconcurrency import ScreenCaptureKit
import Vision

@MainActor
enum ScreenTools {
    // MARK: Text from the screen (OCR)

    static func captureText() {
        guard ensureScreenRecording() else { return }
        RegionSelector.select { selection in
            guard let selection else { return }
            Task {
                guard let image = await capture(selection.rect, on: selection.displayID) else {
                    return feedback("exclamationmark.triangle", S.captureFailed)
                }
                let text = await recognizeText(in: image)
                if text.isEmpty {
                    feedback("text.viewfinder", S.noTextFound)
                } else {
                    FinderTools.copyToPasteboard(text)
                    feedback("text.viewfinder", S.textCopied)
                }
            }
        }
    }

    nonisolated static func recognizeText(in image: CGImage) async -> String {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true
                request.automaticallyDetectsLanguage = true
                try? VNImageRequestHandler(cgImage: image).perform([request])
                let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: lines.joined(separator: "\n"))
            }
        }
    }

    // MARK: QR codes and barcodes

    static func scanCodes() {
        guard ensureScreenRecording() else { return }
        RegionSelector.select { selection in
            guard let selection else { return }
            Task {
                guard let image = await capture(selection.rect, on: selection.displayID) else {
                    return feedback("exclamationmark.triangle", S.captureFailed)
                }
                let codes = await detectCodes(in: image)
                if codes.isEmpty {
                    feedback("qrcode.viewfinder", S.noCodeFound)
                } else {
                    FinderTools.copyToPasteboard(codes.joined(separator: "\n"))
                    feedback("qrcode.viewfinder", S.codeCopied)
                }
            }
        }
    }

    nonisolated static func detectCodes(in image: CGImage) async -> [String] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNDetectBarcodesRequest()
                try? VNImageRequestHandler(cgImage: image).perform([request])
                var seen = Set<String>()
                let payloads = (request.results ?? []).compactMap(\.payloadStringValue).filter { seen.insert($0).inserted }
                continuation.resume(returning: payloads)
            }
        }
    }

    // MARK: Color picker

    static func pickColor() {
        NSColorSampler().show { color in
            MainActor.assumeIsolated {
                guard let color = color?.usingColorSpace(.sRGB) else { return }
                let text = ColorFormat.format(color, as: Prefs.string("colorFormat") ?? "hex")
                FinderTools.copyToPasteboard(text)
                feedback("eyedropper", "\(S.colorCopied)\n\(text)")
            }
        }
    }

    // MARK: Capture

    private static func ensureScreenRecording() -> Bool {
        if CGPreflightScreenCaptureAccess() { return true }
        Permission.screenRecording.request()
        return false
    }

    /// Captures a rectangle (points, top-left origin of that display) of a display.
    static func capture(_ rect: CGRect, on displayID: CGDirectDisplayID) async -> CGImage? {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let display = content.displays.first(where: { $0.displayID == displayID }) else { return nil }
            let filter = SCContentFilter(display: display, excludingWindows: [])
            let config = SCStreamConfiguration()
            let scale = NSScreen.screens.first { $0.displayID == displayID }?.backingScaleFactor ?? 2
            config.sourceRect = rect
            config.width = max(Int(rect.width * scale), 1)
            config.height = max(Int(rect.height * scale), 1)
            config.showsCursor = false
            return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        } catch {
            NSLog("Overdrive: capture failed: \(error.localizedDescription)")
            return nil
        }
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? CGMainDisplayID()
    }
}

/// Color formats for the color picker.
enum ColorFormat {
    static let all: [(id: String, title: String)] = [("hex", "Hex"), ("rgb", "RGB"), ("hsl", "HSL"), ("oklch", "OKLCH")]

    static func format(_ color: NSColor, as format: String) -> String {
        let r = Double(color.redComponent), g = Double(color.greenComponent), b = Double(color.blueComponent)
        switch format {
        case "rgb":
            return "rgb(\(Int((r * 255).rounded())) \(Int((g * 255).rounded())) \(Int((b * 255).rounded())))"
        case "hsl":
            let (h, s, l) = hsl(r, g, b)
            return "hsl(\(Int(h.rounded())) \(Int((s * 100).rounded()))% \(Int((l * 100).rounded()))%)"
        case "oklch":
            let (l, c, h) = oklch(r, g, b)
            return String(format: "oklch(%.1f%% %.3f %.1f)", l * 100, c, h)
        default:
            return String(format: "#%02X%02X%02X", Int((r * 255).rounded()), Int((g * 255).rounded()), Int((b * 255).rounded()))
        }
    }

    static func hsl(_ r: Double, _ g: Double, _ b: Double) -> (Double, Double, Double) {
        let maxV = max(r, g, b), minV = min(r, g, b)
        let l = (maxV + minV) / 2
        guard maxV != minV else { return (0, 0, l) }
        let d = maxV - minV
        let s = l > 0.5 ? d / (2 - maxV - minV) : d / (maxV + minV)
        var h: Double
        switch maxV {
        case r: h = (g - b) / d + (g < b ? 6 : 0)
        case g: h = (b - r) / d + 2
        default: h = (r - g) / d + 4
        }
        h *= 60
        return (h, s, l)
    }

    /// sRGB → OKLab → OKLCH (Björn Ottosson's matrices).
    static func oklch(_ r: Double, _ g: Double, _ b: Double) -> (Double, Double, Double) {
        func linear(_ c: Double) -> Double { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        let lr = linear(r), lg = linear(g), lb = linear(b)
        let l = cbrt(0.4122214708 * lr + 0.5363325363 * lg + 0.0514459929 * lb)
        let m = cbrt(0.2119034982 * lr + 0.6806995451 * lg + 0.1073969566 * lb)
        let s = cbrt(0.0883024619 * lr + 0.2817188376 * lg + 0.6299787005 * lb)
        let L = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s
        let A = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s
        let B = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
        let c = sqrt(A * A + B * B)
        var h = atan2(B, A) * 180 / .pi
        if h < 0 { h += 360 }
        return (L, c, c < 0.0001 ? 0 : h)
    }
}

/// Full-screen overlay to drag a rectangle (Escape cancels).
@MainActor
final class RegionSelector {
    struct Selection {
        /// In points, origin at the top left of the display.
        let rect: CGRect
        let displayID: CGDirectDisplayID
    }

    private static var current: RegionSelector?
    private var windows: [NSWindow] = []
    private let completion: (Selection?) -> Void
    private var keyMonitor: Any?

    static func select(_ completion: @escaping (Selection?) -> Void) {
        current?.finish(nil)
        let selector = RegionSelector(completion: completion)
        current = selector
        selector.show()
    }

    private init(completion: @escaping (Selection?) -> Void) {
        self.completion = completion
    }

    private func show() {
        for screen in NSScreen.screens {
            let window = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
            window.level = .screenSaver
            window.isOpaque = false
            window.backgroundColor = .clear
            window.ignoresMouseEvents = false
            window.acceptsMouseMovedEvents = true
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            let view = SelectionView(frame: CGRect(origin: .zero, size: screen.frame.size))
            view.onFinish = { [weak self] rect in
                guard let self else { return }
                guard let rect, rect.width >= 4, rect.height >= 4 else { return self.finish(nil) }
                // View coordinates (bottom-left) → display coordinates (top-left).
                let topLeft = CGRect(x: rect.minX, y: screen.frame.height - rect.maxY, width: rect.width, height: rect.height)
                self.finish(Selection(rect: topLeft, displayID: screen.displayID))
            }
            window.contentView = view
            window.setFrame(screen.frame, display: true)
            window.makeKeyAndOrderFront(nil)
            windows.append(window)
        }
        NSApp.activate(ignoringOtherApps: true)
        NSCursor.crosshair.push()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Escape
                MainActor.assumeIsolated { self?.finish(nil) }
                return nil
            }
            return event
        }
    }

    private func finish(_ selection: Selection?) {
        guard RegionSelector.current === self else { return }
        RegionSelector.current = nil
        NSCursor.pop()
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        for window in windows { window.orderOut(nil) }
        windows = []
        // Let the overlay disappear before the screen is captured.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [completion] in
            MainActor.assumeIsolated { completion(selection) }
        }
    }
}

private final class SelectionView: NSView {
    var onFinish: ((CGRect?) -> Void)?
    private var start: CGPoint?
    private var rect: CGRect?

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.25).setFill()
        bounds.fill()
        guard let rect else { return }
        NSColor.clear.setFill()
        rect.fill(using: .copy)
        NSColor.white.setStroke()
        let path = NSBezierPath(rect: rect.insetBy(dx: 0.5, dy: 0.5))
        path.lineWidth = 1
        path.stroke()
    }

    override func mouseDown(with event: NSEvent) {
        start = convert(event.locationInWindow, from: nil)
        rect = nil
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start else { return }
        let p = convert(event.locationInWindow, from: nil)
        rect = CGRect(x: min(start.x, p.x), y: min(start.y, p.y), width: abs(p.x - start.x), height: abs(p.y - start.y))
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        onFinish?(rect)
    }

    override func rightMouseDown(with event: NSEvent) {
        onFinish?(nil)
    }
}
