// Renders Design/*.svg into App/Assets.xcassets (app icon sizes, menu bar template) with AppKit.
// Usage (from Design/): swift render.swift
import AppKit

func png(_ svg: String, size: Int, to path: String) throws {
    guard let image = NSImage(contentsOfFile: svg) else { throw NSError(domain: "render", code: 1, userInfo: [NSLocalizedDescriptionKey: "can't read \(svg)"]) }
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4,
                                     hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return }
    rep.size = NSSize(width: size, height: size)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    image.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
    NSGraphicsContext.restoreGraphicsState()
    try rep.representation(using: .png, properties: [:])?.write(to: URL(filePath: path))
}

let assets = "../App/Assets.xcassets"
let iconSet = "\(assets)/AppIcon.appiconset"
let menuSet = "\(assets)/MenuBarIcon.imageset"
for folder in [iconSet, menuSet] { try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true) }

var images: [[String: String]] = []
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
        try png("icon.svg", size: points * scale, to: "\(iconSet)/\(name)")
        images.append(["idiom": "mac", "size": "\(points)x\(points)", "scale": "\(scale)x", "filename": name])
    }
}
let iconContents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
try JSONSerialization.data(withJSONObject: iconContents, options: [.prettyPrinted, .sortedKeys]).write(to: URL(filePath: "\(iconSet)/Contents.json"))

try png("menubar.svg", size: 18, to: "\(menuSet)/menubar.png")
try png("menubar.svg", size: 36, to: "\(menuSet)/menubar@2x.png")
let menuContents: [String: Any] = [
    "images": [["idiom": "universal", "filename": "menubar.png", "scale": "1x"], ["idiom": "universal", "filename": "menubar@2x.png", "scale": "2x"]],
    "info": ["author": "xcode", "version": 1], "properties": ["template-rendering-intent": "template"],
]
try JSONSerialization.data(withJSONObject: menuContents, options: [.prettyPrinted, .sortedKeys]).write(to: URL(filePath: "\(menuSet)/Contents.json"))
try JSONSerialization.data(withJSONObject: ["info": ["author": "xcode", "version": 1]], options: [.prettyPrinted]).write(to: URL(filePath: "\(assets)/Contents.json"))

// A preview sheet: the icon at Dock, Finder and list sizes on light and dark, for checking by eye.
try png("icon.svg", size: 1024, to: "preview-1024.png")
print("rendered \(images.count) icon images and the menu bar template")
