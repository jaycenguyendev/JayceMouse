import AppKit

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

func render(size: Int) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    let s = CGFloat(size)
    let rect = NSRect(x: s * 0.06, y: s * 0.06, width: s * 0.88, height: s * 0.88)
    let bg = NSBezierPath(roundedRect: rect, xRadius: s * 0.2, yRadius: s * 0.2)
    NSGradient(colors: [
        NSColor(red: 0.45, green: 0.36, blue: 0.98, alpha: 1),
        NSColor(red: 0.10, green: 0.74, blue: 0.92, alpha: 1),
    ])!.draw(in: bg, angle: -50)

    let mouseW = s * 0.34, mouseH = s * 0.52
    let mouseRect = NSRect(x: (s - mouseW) / 2, y: (s - mouseH) / 2, width: mouseW, height: mouseH)
    let mouse = NSBezierPath(roundedRect: mouseRect, xRadius: mouseW / 2, yRadius: mouseW / 2)
    NSColor.white.withAlphaComponent(0.95).setFill()
    mouse.fill()

    NSColor(red: 0.45, green: 0.36, blue: 0.98, alpha: 0.9).setStroke()
    let split = NSBezierPath()
    split.lineWidth = s * 0.012
    split.move(to: NSPoint(x: s / 2, y: mouseRect.maxY))
    split.line(to: NSPoint(x: s / 2, y: mouseRect.midY + mouseH * 0.08))
    split.stroke()
    let bar = NSBezierPath()
    bar.lineWidth = s * 0.012
    bar.move(to: NSPoint(x: mouseRect.minX + mouseW * 0.04, y: mouseRect.midY + mouseH * 0.08))
    bar.line(to: NSPoint(x: mouseRect.maxX - mouseW * 0.04, y: mouseRect.midY + mouseH * 0.08))
    bar.stroke()

    let wheel = NSBezierPath(roundedRect: NSRect(x: s / 2 - s * 0.018, y: mouseRect.midY + mouseH * 0.14, width: s * 0.036, height: mouseH * 0.18), xRadius: s * 0.018, yRadius: s * 0.018)
    NSColor(red: 0.98, green: 0.36, blue: 0.62, alpha: 1).setFill()
    wheel.fill()
    image.unlockFocus()
    return image
}

func write(_ image: NSImage, name: String) {
    guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else { return }
    try? png.write(to: URL(fileURLWithPath: "\(outDir)/\(name)"))
}

for base in [16, 32, 128, 256, 512] {
    write(render(size: base), name: "icon_\(base)x\(base).png")
    write(render(size: base * 2), name: "icon_\(base)x\(base)@2x.png")
}
