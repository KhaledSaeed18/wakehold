import AppKit

// Renders the Wakehold app icon per the brand mark in CLAUDE.md: a lidless-eye mark (almond
// outline + Signal Cyan iris) on a dark rounded square. Pure geometry, no rendered eyeball.
let side = 1024
let cs = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8,
                          bytesPerRow: 0, space: cs,
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
    fatalError("no context")
}

func rgb(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> CGColor {
    CGColor(colorSpace: cs, components: [r, g, b, a])!
}
let obsidian = rgb(0.055, 0.067, 0.086)   // #0E1116
let slate    = rgb(0.086, 0.102, 0.133)   // #161A22
let offwhite = rgb(0.957, 0.965, 0.973)   // #F4F6F8
let cyan     = rgb(0.239, 0.827, 0.878)   // #3DD3E0

let s = CGFloat(side)
let margin: CGFloat = 100
let bgRect = CGRect(x: margin, y: margin, width: s - 2 * margin, height: s - 2 * margin)
let bgPath = CGPath(roundedRect: bgRect, cornerWidth: 186, cornerHeight: 186, transform: nil)

// Background: subtle vertical gradient (slate at top -> obsidian at bottom) for depth.
ctx.saveGState()
ctx.addPath(bgPath); ctx.clip()
if let grad = CGGradient(colorsSpace: cs, colors: [slate, obsidian] as CFArray, locations: [0, 1]) {
    ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: s), end: CGPoint(x: 0, y: 0), options: [])
}

let cx: CGFloat = 512, cy: CGFloat = 512
let ew: CGFloat = 580, eh: CGFloat = 300

// Soft cyan glow behind the iris (the "awake" state glows, per BRAND).
if let glow = CGGradient(colorsSpace: cs,
                         colors: [cyan.copy(alpha: 0.5)!, cyan.copy(alpha: 0.0)!] as CFArray,
                         locations: [0, 1]) {
    ctx.drawRadialGradient(glow, startCenter: CGPoint(x: cx, y: cy), startRadius: 0,
                           endCenter: CGPoint(x: cx, y: cy), endRadius: 250, options: [])
}

// Almond outline: two quad curves meeting at the left and right points.
let almond = CGMutablePath()
almond.move(to: CGPoint(x: cx - ew / 2, y: cy))
almond.addQuadCurve(to: CGPoint(x: cx + ew / 2, y: cy), control: CGPoint(x: cx, y: cy + eh))
almond.addQuadCurve(to: CGPoint(x: cx - ew / 2, y: cy), control: CGPoint(x: cx, y: cy - eh))
almond.closeSubpath()
ctx.addPath(almond)
ctx.setStrokeColor(offwhite)
ctx.setLineWidth(36)
ctx.setLineJoin(.round)
ctx.strokePath()

// Iris: a solid cyan circle, ~1/3 the eye width.
let irisR: CGFloat = 98
ctx.setFillColor(cyan)
ctx.fillEllipse(in: CGRect(x: cx - irisR, y: cy - irisR, width: irisR * 2, height: irisR * 2))
ctx.restoreGState()

guard let image = ctx.makeImage() else { fatalError("no image") }
let rep = NSBitmapImageRep(cgImage: image)
guard let png = rep.representation(using: .png, properties: [:]) else { fatalError("no png") }
try! png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
print("wrote \(CommandLine.arguments[1])")
