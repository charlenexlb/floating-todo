// Draws the app icon (a cream checklist with brown checkboxes) as PNGs into an .iconset folder.
// Usage: make_icon <path/to/AppIcon.iconset>
import AppKit

let outDir = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)

let cream = NSColor(red: 0.961, green: 0.922, blue: 0.863, alpha: 1) // #F5EBDC
let paper = NSColor(red: 0.984, green: 0.965, blue: 0.933, alpha: 1) // #FBF6EE
let border = NSColor(red: 0.890, green: 0.827, blue: 0.745, alpha: 1) // #E3D3BE
let brown = NSColor(red: 0.643, green: 0.459, blue: 0.318, alpha: 1) // #A47551
let muted = NSColor(red: 0.804, green: 0.722, blue: 0.635, alpha: 1) // #CDB8A2

func render(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let s = CGFloat(pixels)
    // Apple's icon grid leaves ~10% transparent margin around the rounded square.
    let inset = s * 100 / 1024
    let body = NSRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let w = body.width

    let tile = NSBezierPath(roundedRect: body, xRadius: w * 0.225, yRadius: w * 0.225)
    cream.setFill()
    tile.fill()
    border.setStroke()
    tile.lineWidth = max(1, s * 0.008)
    tile.stroke()

    for row in 0..<3 {
        let midY = body.minY + w * (0.68 - CGFloat(row) * 0.18)
        let d = w * 0.12
        let box = NSRect(x: body.minX + w * 0.2, y: midY - d / 2, width: d, height: d)
        let circle = NSBezierPath(ovalIn: box)

        if row == 0 {
            brown.setFill()
            circle.fill()
            let check = NSBezierPath()
            check.move(to: NSPoint(x: box.minX + d * 0.28, y: box.minY + d * 0.52))
            check.line(to: NSPoint(x: box.minX + d * 0.44, y: box.minY + d * 0.34))
            check.line(to: NSPoint(x: box.minX + d * 0.73, y: box.minY + d * 0.68))
            check.lineWidth = d * 0.13
            check.lineCapStyle = .round
            check.lineJoinStyle = .round
            paper.setStroke()
            check.stroke()
        } else {
            let ring = NSBezierPath(ovalIn: box.insetBy(dx: w * 0.01, dy: w * 0.01))
            ring.lineWidth = w * 0.02
            brown.setStroke()
            ring.stroke()
        }

        let barHeight = w * 0.05
        let bar = NSRect(x: box.maxX + w * 0.07, y: midY - barHeight / 2, width: w * 0.42, height: barHeight)
        (row == 0 ? border : muted).setFill()
        NSBezierPath(roundedRect: bar, xRadius: barHeight / 2, yRadius: barHeight / 2).fill()
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    try render(pixels: size).write(to: outDir.appending(path: "icon_\(size)x\(size).png"))
    try render(pixels: size * 2).write(to: outDir.appending(path: "icon_\(size)x\(size)@2x.png"))
}
