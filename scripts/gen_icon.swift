import AppKit

let outRoot = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Resources"
let iconsetDir = (outRoot as NSString).appendingPathComponent("AppIcon.iconset")
try? FileManager.default.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

func drawIcon(size: CGFloat) -> Data? {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
    guard let rep else { return nil }
    rep.size = NSSize(width: size, height: size)
    NSGraphicsContext.saveGraphicsState()
    guard let ctx = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
    NSGraphicsContext.current = ctx
    let s = size

    let margin = s * 0.085
    let tile = NSRect(x: margin, y: margin, width: s - margin * 2, height: s - margin * 2)
    let radius = tile.width * 0.225
    let tilePath = NSBezierPath(roundedRect: tile, xRadius: radius, yRadius: radius)
    NSGradient(starting: NSColor(srgbRed: 0.16, green: 0.16, blue: 0.18, alpha: 1),
               ending: NSColor(srgbRed: 0.07, green: 0.07, blue: 0.08, alpha: 1))?.draw(in: tilePath, angle: -90)
    NSGradient(starting: NSColor.white.withAlphaComponent(0.07),
               ending: NSColor.white.withAlphaComponent(0))?.draw(in: tilePath, angle: -90)

    // contextual menu symbol
    let conf = NSImage.SymbolConfiguration(pointSize: tile.width * 0.52, weight: .regular)
        .applying(NSImage.SymbolConfiguration(paletteColors: [NSColor.white]))
    if let symbol = NSImage(systemSymbolName: "contextualmenu.and.cursorarrow",
                            accessibilityDescription: nil)?.withSymbolConfiguration(conf) {
        let target = tile.width * 0.62
        let w = symbol.size.width, h = symbol.size.height
        let scale = min(target / w, target / h)
        let dw = w * scale, dh = h * scale
        symbol.draw(in: NSRect(x: tile.midX - dw / 2, y: tile.midY - dh / 2,
                               width: dw, height: dh))
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
}

let variants: [(String, CGFloat)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024)
]
for (name, px) in variants {
    guard let data = drawIcon(size: px) else { print("failed \(name)"); exit(1) }
    try data.write(to: URL(fileURLWithPath: (iconsetDir as NSString).appendingPathComponent(name)))
}
print("iconset written to \(iconsetDir)")
