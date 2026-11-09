import AppKit

enum Brand {
    /// Menu bar icon (template image): the lightning bolt of the app icon, drawn as an outline.
    /// Same grammar as the other Lightmaster apps: 1.6 pt round strokes in a 14 pt box, no fills.
    static func menuBarIcon() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { _ in
            let bolt = NSBezierPath()
            bolt.move(to: NSPoint(x: 10.6, y: 1.9))
            bolt.line(to: NSPoint(x: 4.4, y: 10.0))
            bolt.line(to: NSPoint(x: 8.7, y: 10.0))
            bolt.line(to: NSPoint(x: 7.4, y: 16.1))
            bolt.line(to: NSPoint(x: 13.6, y: 8.0))
            bolt.line(to: NSPoint(x: 9.3, y: 8.0))
            bolt.close()
            bolt.lineWidth = 1.6
            bolt.lineCapStyle = .round
            bolt.lineJoinStyle = .round
            NSColor.black.setStroke()
            bolt.stroke()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Overdrive"
        return image
    }
}
