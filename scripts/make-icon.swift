// Generates the ClipStack icon: Resources/AppIcon.icns and assets/logo.png
// Usage: swift scripts/make-icon.swift
import AppKit

let ink = NSColor(calibratedWhite: 0.11, alpha: 1)
let accent = NSColor(calibratedRed: 0.0, green: 0.48, blue: 1.0, alpha: 1)

/// Draws the icon on a 1024×1024 design grid, scaled to `pixels`.
func render(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let transform = NSAffineTransform()
    transform.scale(by: CGFloat(pixels) / 1024)
    transform.concat()

    // White rounded-square body following the macOS icon grid, with a soft shadow.
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
    shadow.shadowBlurRadius = 28
    shadow.shadowOffset = NSSize(width: 0, height: -10)
    shadow.set()
    NSColor.white.setFill()
    NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824), xRadius: 185, yRadius: 185).fill()
    NSGraphicsContext.restoreGraphicsState()

    for (path, color) in layers() {
        path.lineWidth = 34
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        color.setStroke()
        path.stroke()
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

/// Three stacked layers; the top one (the latest copy) uses the accent color.
func layers() -> [(NSBezierPath, NSColor)] {
    let top = NSBezierPath()
    top.move(to: NSPoint(x: 512, y: 760))
    top.line(to: NSPoint(x: 712, y: 650))
    top.line(to: NSPoint(x: 512, y: 540))
    top.line(to: NSPoint(x: 312, y: 650))
    top.close()

    func chevron(_ y: CGFloat) -> NSBezierPath {
        let p = NSBezierPath()
        p.move(to: NSPoint(x: 312, y: y))
        p.line(to: NSPoint(x: 512, y: y - 110))
        p.line(to: NSPoint(x: 712, y: y))
        return p
    }
    return [(top, accent), (chevron(540), ink), (chevron(430), ink)]
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconset = root.appendingPathComponent("build/AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

for points in [16, 32, 128, 256, 512] {
    try! render(pixels: points).write(to: iconset.appendingPathComponent("icon_\(points)x\(points).png"))
    try! render(pixels: points * 2).write(to: iconset.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
}

let assets = root.appendingPathComponent("assets")
try! FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
try! render(pixels: 512).write(to: assets.appendingPathComponent("logo.png"))

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", root.appendingPathComponent("Resources/AppIcon.icns").path]
try! iconutil.run()
iconutil.waitUntilExit()
print("Created Resources/AppIcon.icns and assets/logo.png")
