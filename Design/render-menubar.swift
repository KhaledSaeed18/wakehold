import AppKit

// Renders a monochrome (black on transparent) menu-bar template mark. macOS tints template
// images, so the shape is drawn in solid black and the alpha channel defines it.
//   render_menubar <size> <open|arctop|arcbottom> <output.png>
let size = Int(CommandLine.arguments[1])!
let state = CommandLine.arguments[2]
let out = CommandLine.arguments[3]

let cs = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                          bytesPerRow: 0, space: cs,
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { fatalError() }
let S = CGFloat(size)
let black = CGColor(colorSpace: cs, components: [0, 0, 0, 1])!

let cx = S / 2, cy = S / 2
let ew = S * 0.86            // eye width
let eh = S * 0.48            // almond height, peak to peak
let stroke = S * 0.095
ctx.setStrokeColor(black)
ctx.setFillColor(black)
ctx.setLineWidth(stroke)
ctx.setLineCap(.round)
ctx.setLineJoin(.round)

let L = CGPoint(x: cx - ew / 2, y: cy)
let R = CGPoint(x: cx + ew / 2, y: cy)

switch state {
case "open":
    let p = CGMutablePath()
    p.move(to: L)
    p.addQuadCurve(to: R, control: CGPoint(x: cx, y: cy + eh))
    p.addQuadCurve(to: L, control: CGPoint(x: cx, y: cy - eh))
    p.closeSubpath()
    ctx.addPath(p); ctx.strokePath()
    let r = ew / 6
    ctx.fillEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
case "slash":
    // The open eye with a diagonal slash cutting through it: the "off" state.
    let p = CGMutablePath()
    p.move(to: L)
    p.addQuadCurve(to: R, control: CGPoint(x: cx, y: cy + eh))
    p.addQuadCurve(to: L, control: CGPoint(x: cx, y: cy - eh))
    p.closeSubpath()
    ctx.addPath(p); ctx.strokePath()
    let r = ew / 6
    ctx.fillEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
    let a = CGPoint(x: S * 0.18, y: S * 0.30)
    let b = CGPoint(x: S * 0.82, y: S * 0.70)
    ctx.setLineCap(.round)
    ctx.setBlendMode(.clear)                 // carve a gap around the slash
    ctx.setLineWidth(stroke * 2.3)
    ctx.move(to: a); ctx.addLine(to: b); ctx.strokePath()
    ctx.setBlendMode(.normal)
    ctx.setStrokeColor(black)
    ctx.setLineWidth(stroke)
    ctx.move(to: a); ctx.addLine(to: b); ctx.strokePath()
case "lens":
    // A flattened almond, no iris: the same eye, closed.
    let lh = S * 0.17
    let p = CGMutablePath()
    p.move(to: L)
    p.addQuadCurve(to: R, control: CGPoint(x: cx, y: cy + lh))
    p.addQuadCurve(to: L, control: CGPoint(x: cx, y: cy - lh))
    p.closeSubpath()
    ctx.addPath(p); ctx.strokePath()
case "arctop":
    // Single upper arc (peak above), centered vertically.
    let p = CGMutablePath()
    p.move(to: CGPoint(x: L.x, y: cy - eh / 4))
    p.addQuadCurve(to: CGPoint(x: R.x, y: cy - eh / 4), control: CGPoint(x: cx, y: cy + eh * 0.75))
    ctx.addPath(p); ctx.strokePath()
default: // arcbottom
    // Single lower arc (dips below), centered vertically.
    let p = CGMutablePath()
    p.move(to: CGPoint(x: L.x, y: cy + eh / 4))
    p.addQuadCurve(to: CGPoint(x: R.x, y: cy + eh / 4), control: CGPoint(x: cx, y: cy - eh * 0.75))
    ctx.addPath(p); ctx.strokePath()
}

let img = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: img)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
