// Contact sheet: the icon at 16, 32, 64, 128 and 256 pt on light and dark backgrounds.
import AppKit
let icon = NSImage(contentsOfFile: "icon.svg")!
let menu = NSImage(contentsOfFile: "menubar.svg")!
let sizes: [CGFloat] = [16, 32, 64, 128, 256]
let width = Int(sizes.reduce(0, +) + 40 * CGFloat(sizes.count) + 120), height = 2 * 300
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4,
                           hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
for (row, color) in [NSColor(white: 0.96, alpha: 1), NSColor(white: 0.13, alpha: 1)].enumerated() {
    color.setFill()
    NSRect(x: 0, y: CGFloat(row) * 300, width: CGFloat(width), height: 300).fill()
    var x: CGFloat = 20
    for size in sizes {
        icon.draw(in: NSRect(x: x, y: CGFloat(row) * 300 + (300 - size) / 2, width: size, height: size))
        x += size + 40
    }
    // Menu bar template, tinted like the system would.
    let tinted = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
        menu.draw(in: rect); (row == 0 ? NSColor.black : NSColor.white).set(); rect.fill(using: .sourceAtop); return true
    }
    tinted.draw(in: NSRect(x: x + 20, y: CGFloat(row) * 300 + 141, width: 18, height: 18))
}
try! rep.representation(using: .png, properties: [:])!.write(to: URL(filePath: "preview-sheet.png"))
