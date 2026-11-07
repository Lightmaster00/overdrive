import AppKit

enum Brand {
    /// Menu bar icon (template image): a gauge with its needle pushed to the top of the scale.
    static func menuBarIcon() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.black.setStroke()
            NSColor.black.setFill()
            let center = NSPoint(x: 9, y: 7.2)

            // Dial: an open arc, like a speedometer.
            let arc = NSBezierPath()
            arc.appendArc(withCenter: center, radius: 7, startAngle: 205, endAngle: -25, clockwise: true)
            arc.lineWidth = 1.6
            arc.lineCapStyle = .round
            arc.stroke()

            // Ticks of the high zone, toward the end of the scale.
            for angle in stride(from: 40.0, through: 0.0, by: -20.0) {
                let a = angle * .pi / 180
                let tick = NSBezierPath()
                tick.move(to: NSPoint(x: center.x + 4.2 * cos(a), y: center.y + 4.2 * sin(a)))
                tick.line(to: NSPoint(x: center.x + 5.3 * cos(a), y: center.y + 5.3 * sin(a)))
                tick.lineWidth = 1.1
                tick.lineCapStyle = .round
                tick.stroke()
            }

            // Needle in the red zone.
            let needleAngle = 22.0 * .pi / 180
            let needle = NSBezierPath()
            needle.move(to: center)
            needle.line(to: NSPoint(x: center.x + 6.1 * cos(needleAngle), y: center.y + 6.1 * sin(needleAngle)))
            needle.lineWidth = 1.7
            needle.lineCapStyle = .round
            needle.stroke()
            NSBezierPath(ovalIn: NSRect(x: center.x - 1.7, y: center.y - 1.7, width: 3.4, height: 3.4)).fill()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Overdrive"
        return image
    }
}
