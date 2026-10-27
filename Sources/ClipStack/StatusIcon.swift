import AppKit

/// Menu bar version of the app icon: the three stacked layers as a template image,
/// so macOS tints it for light and dark menu bars.
enum StatusIcon {
    static func make() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
            // Same coordinates as scripts/make-icon.swift, mapped from the 1024 grid.
            let scale = rect.height * 0.8 / 440
            let transform = AffineTransform(translationByX: rect.midX - 512 * scale, byY: rect.midY - 540 * scale)
                .scaled(by: scale)

            let top = NSBezierPath()
            top.move(to: NSPoint(x: 512, y: 760))
            top.line(to: NSPoint(x: 712, y: 650))
            top.line(to: NSPoint(x: 512, y: 540))
            top.line(to: NSPoint(x: 312, y: 650))
            top.close()

            var paths = [top]
            for y: CGFloat in [540, 430] {
                let chevron = NSBezierPath()
                chevron.move(to: NSPoint(x: 312, y: y))
                chevron.line(to: NSPoint(x: 512, y: y - 110))
                chevron.line(to: NSPoint(x: 712, y: y))
                paths.append(chevron)
            }

            NSColor.black.setStroke()
            for path in paths {
                path.transform(using: transform)
                path.lineWidth = 1.6
                path.lineCapStyle = .round
                path.lineJoinStyle = .round
                path.stroke()
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}

private extension AffineTransform {
    func scaled(by factor: CGFloat) -> AffineTransform {
        var copy = AffineTransform(scale: factor)
        copy.append(self)
        return copy
    }
}
