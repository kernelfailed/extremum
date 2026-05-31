import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconset = root.appendingPathComponent("Resources/ApplicationIcon.iconset", isDirectory: true)
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

let sizes: [(String, CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    NSColor.clear.setFill()
    rect.fill()

    let radius = size * 0.22
    let outer = NSBezierPath(roundedRect: rect.insetBy(dx: size * 0.06, dy: size * 0.06), xRadius: radius, yRadius: radius)
    NSColor(calibratedRed: 0.06, green: 0.12, blue: 0.18, alpha: 1).setFill()
    outer.fill()

    let left = NSBezierPath(roundedRect: NSRect(x: size * 0.17, y: size * 0.22, width: size * 0.31, height: size * 0.56), xRadius: size * 0.055, yRadius: size * 0.055)
    NSColor(calibratedRed: 0.11, green: 0.48, blue: 0.90, alpha: 1).setFill()
    left.fill()

    let right = NSBezierPath(roundedRect: NSRect(x: size * 0.52, y: size * 0.22, width: size * 0.31, height: size * 0.56), xRadius: size * 0.055, yRadius: size * 0.055)
    NSColor(calibratedRed: 0.20, green: 0.72, blue: 0.49, alpha: 1).setFill()
    right.fill()

    NSColor.white.withAlphaComponent(0.92).setStroke()
    let stroke = NSBezierPath()
    stroke.lineWidth = max(size * 0.035, 1.2)
    stroke.move(to: NSPoint(x: size * 0.33, y: size * 0.68))
    stroke.line(to: NSPoint(x: size * 0.50, y: size * 0.50))
    stroke.line(to: NSPoint(x: size * 0.67, y: size * 0.68))
    stroke.move(to: NSPoint(x: size * 0.33, y: size * 0.32))
    stroke.line(to: NSPoint(x: size * 0.50, y: size * 0.50))
    stroke.line(to: NSPoint(x: size * 0.67, y: size * 0.32))
    stroke.stroke()

    image.unlockFocus()
    return image
}

for (name, size) in sizes {
    let image = drawIcon(size: size)
    guard
        let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let data = bitmap.representation(using: .png, properties: [:])
    else {
        fatalError("Unable to encode \(name)")
    }
    try data.write(to: iconset.appendingPathComponent(name))
}

print(iconset.path)
