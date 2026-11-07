import AppKit

enum Brand {
    /// Menu bar icon (template image): a lightning bolt over a grid of four tool tiles.
    static func menuBarIcon() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { _ in
            guard let context = NSGraphicsContext.current else { return false }
            let bolt = NSBezierPath()
            bolt.move(to: NSPoint(x: 10.2, y: 1.6))
            bolt.line(to: NSPoint(x: 5.2, y: 9.6))
            bolt.line(to: NSPoint(x: 8.6, y: 9.6))
            bolt.line(to: NSPoint(x: 7.8, y: 16.4))
            bolt.line(to: NSPoint(x: 13, y: 8.2))
            bolt.line(to: NSPoint(x: 9.6, y: 8.2))
            bolt.close()
            bolt.lineJoinStyle = .round

            NSColor.black.setStroke()
            for (x, y) in [(1.6, 1.6), (10.0, 1.6), (1.6, 10.0), (10.0, 10.0)] {
                let tile = NSBezierPath(roundedRect: NSRect(x: x, y: y, width: 6.4, height: 6.4), xRadius: 1.8, yRadius: 1.8)
                tile.lineWidth = 1.3
                tile.stroke()
            }
            // A gap around the bolt, so it stands out from the tiles.
            context.saveGraphicsState()
            context.compositingOperation = .clear
            bolt.lineWidth = 3
            bolt.stroke()
            bolt.fill()
            context.restoreGraphicsState()

            NSColor.black.setFill()
            bolt.lineWidth = 0.8
            bolt.fill()
            bolt.stroke()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Overdrive"
        return image
    }
}
