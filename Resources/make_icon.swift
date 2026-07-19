// Generates AppIcon.icns by rendering a simple letter-tile icon at all sizes.
// Run: swift Resources/make_icon.swift <output.icns>
import AppKit

func render(size: Int) -> NSImage {
    let s = CGFloat(size)
    let img = NSImage(size: NSSize(width: s, height: s))
    img.lockFocus()
    // Rounded-rect background gradient (macOS-ish app tile).
    let inset = s * 0.08
    let rect = NSRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let radius = s * 0.22
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.36, green: 0.42, blue: 0.95, alpha: 1),
        NSColor(calibratedRed: 0.55, green: 0.27, blue: 0.86, alpha: 1),
    ])
    gradient?.draw(in: path, angle: -90)

    // Two letters suggesting an anagram swap: "Aa" / mirrored.
    let glyph = "A"
    let font = NSFont.systemFont(ofSize: s * 0.5, weight: .bold)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.white,
    ]
    let str = NSAttributedString(string: glyph, attributes: attrs)
    let textSize = str.size()
    let pt = NSPoint(x: (s - textSize.width) / 2, y: (s - textSize.height) / 2)
    str.draw(at: pt)
    img.unlockFocus()
    return img
}

func png(_ image: NSImage, _ size: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: size, height: size)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.icns"
let iconset = NSTemporaryDirectory() + "Anagrammer.iconset"
try? FileManager.default.removeItem(atPath: iconset)
try! FileManager.default.createDirectory(atPath: iconset, withIntermediateDirectories: true)

// Required iconset members: 16,32,128,256,512 at 1x and 2x.
let specs: [(Int, String)] = [
    (16, "icon_16x16.png"), (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"), (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"), (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"), (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"), (1024, "icon_512x512@2x.png"),
]
for (px, name) in specs {
    let data = png(render(size: px), px)
    try! data.write(to: URL(fileURLWithPath: iconset + "/" + name))
}

// Convert iconset -> icns via iconutil.
let proc = Process()
proc.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
proc.arguments = ["-c", "icns", iconset, "-o", out]
try! proc.run()
proc.waitUntilExit()
print("Wrote \(out)")
