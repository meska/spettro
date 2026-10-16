// Screenshot per l'App Store (2880x1800, Mac). Disegna lo spettro con gli stessi colori e la stessa
// geometria a segmenti dell'app, grande, su fondo scuro, più la barra dei menu con il meter a misura reale.
// Uso: swift mas/make-screenshot.swift mas/screenshots/spettro-2880x1800.png
import AppKit

let W = 2880, H = 1800
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "spettro-2880x1800.png"

let green = NSColor(srgbRed: 0.16, green: 0.62, blue: 0.30, alpha: 1)
let amber = NSColor(srgbRed: 0.85, green: 0.64, blue: 0.06, alpha: 1)
let red   = NSColor(srgbRed: 0.86, green: 0.20, blue: 0.16, alpha: 1)

func led(_ l: Int, _ total: Int) -> NSColor {
    let r = Double(l) / Double(max(total - 1, 1))
    if r < 0.6 { return green }
    if r < 0.85 { return amber }
    return red
}

// profilo "musica": fianco sinistro alto, coda che scende, un po' di irregolarità deterministica
let levels: [Int] = [9, 10, 9, 8, 9, 7, 8, 6, 7, 5, 6, 5, 4, 5, 3, 4, 3, 2, 2, 1]
let peaks:  [Int] = [10, 10, 10, 9, 10, 8, 9, 7, 8, 6, 7, 6, 5, 6, 4, 5, 4, 3, 3, 2]

guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: W, pixelsHigh: H,
                                 bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                 isPlanar: false, colorSpaceName: .deviceRGB,
                                 bytesPerRow: 0, bitsPerPixel: 0),
      let ctx = NSGraphicsContext(bitmapImageRep: rep) else { fatalError("niente bitmap") }
rep.size = NSSize(width: W, height: H)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = ctx

// fondo
NSGradient(colors: [NSColor(srgbRed: 0.05, green: 0.06, blue: 0.11, alpha: 1),
                    NSColor(srgbRed: 0.13, green: 0.07, blue: 0.20, alpha: 1)])!
    .draw(in: NSRect(x: 0, y: 0, width: W, height: H), angle: 60)
NSGradient(colors: [NSColor(srgbRed: 0.20, green: 0.62, blue: 0.40, alpha: 0.22), .clear])!
    .draw(fromCenter: NSPoint(x: 1440, y: 800), radius: 0, toCenter: NSPoint(x: 1440, y: 800), radius: 1300, options: [])

// meter grande
func drawMeter(origin: NSPoint, barW: CGFloat, gap: CGFloat, segH: CGFloat, segGap: CGFloat,
               corner: CGFloat, glow: Bool) {
    let n = levels.count, total = 10
    for b in 0..<n {
        let x = origin.x + CGFloat(b) * (barW + gap)
        for l in 0..<total {
            let y = origin.y + CGFloat(l) * (segH + segGap)
            let r = NSRect(x: x, y: y, width: barW, height: segH)
            let p = NSBezierPath(roundedRect: r, xRadius: corner, yRadius: corner)
            if l < levels[b] {
                let c = led(l, total)
                if glow {
                    NSGraphicsContext.saveGraphicsState()
                    let sh = NSShadow(); sh.shadowColor = c.withAlphaComponent(0.55)
                    sh.shadowBlurRadius = segH * 0.7; sh.shadowOffset = .zero; sh.set()
                    c.setFill(); p.fill()
                    NSGraphicsContext.restoreGraphicsState()
                } else { c.setFill(); p.fill() }
            } else if l == peaks[b] - 1 {
                NSColor(srgbRed: 0.95, green: 0.30, blue: 0.25, alpha: 0.95).setFill()
                NSBezierPath(roundedRect: r.insetBy(dx: barW * 0.18, dy: segH * 0.12),
                             xRadius: corner, yRadius: corner).fill()
            } else {
                NSColor.white.withAlphaComponent(0.07).setFill(); p.fill()
            }
        }
    }
}

let barW: CGFloat = 78, gap: CGFloat = 16, segH: CGFloat = 50, segGap: CGFloat = 12
let mw = 20 * barW + 19 * gap, mh = 10 * segH + 9 * segGap
let mx = (CGFloat(W) - mw) / 2, my: CGFloat = 330

// pannello vetro dietro il meter
let panel = NSRect(x: mx - 90, y: my - 90, width: mw + 180, height: mh + 180)
NSColor.white.withAlphaComponent(0.04).setFill()
NSBezierPath(roundedRect: panel, xRadius: 56, yRadius: 56).fill()
NSColor.white.withAlphaComponent(0.10).setStroke()
let border = NSBezierPath(roundedRect: panel, xRadius: 56, yRadius: 56); border.lineWidth = 2; border.stroke()
drawMeter(origin: NSPoint(x: mx, y: my), barW: barW, gap: gap, segH: segH, segGap: segGap, corner: 8, glow: true)

// testo
func text(_ s: String, size: CGFloat, weight: NSFont.Weight, color: NSColor, y: CGFloat, kern: CGFloat = 0) {
    let para = NSMutableParagraphStyle(); para.alignment = .center
    let a: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: size, weight: weight),
                                           .foregroundColor: color, .paragraphStyle: para, .kern: kern]
    (s as NSString).draw(in: NSRect(x: 0, y: y, width: CGFloat(W), height: size * 1.4), withAttributes: a)
}
text("Spettro", size: 210, weight: .bold, color: .white, y: 1180, kern: -3)
text("Lo spettro dell'audio, nella barra dei menu.", size: 78, weight: .regular,
     color: NSColor.white.withAlphaComponent(0.72), y: 1070)
text("Leggero · Gratuito · Nessun dato raccolto · 10 lingue", size: 54, weight: .medium,
     color: NSColor(srgbRed: 0.45, green: 0.85, blue: 0.58, alpha: 1), y: 110, kern: 1)

// barra dei menu in alto, con il meter a misura reale (2x)
let barH: CGFloat = 56
NSColor.black.withAlphaComponent(0.55).setFill()
NSRect(x: 0, y: CGFloat(H) - barH, width: CGFloat(W), height: barH).fill()
let mini: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 28, weight: .medium),
                                           .foregroundColor: NSColor.white.withAlphaComponent(0.9)]
("Ven 16 ott  17:11" as NSString).draw(at: NSPoint(x: CGFloat(W) - 330, y: CGFloat(H) - 44), withAttributes: mini)
let smallW: CGFloat = 10, smallGap: CGFloat = 2
let smw = 20 * smallW + 19 * smallGap
let sx = CGFloat(W) - 330 - 40 - smw
// la barra dei menu è alta 24 pt = 48 px a 2x: il meter ci sta con segmenti di 2.8 px
drawMeter(origin: NSPoint(x: sx, y: CGFloat(H) - barH + 9), barW: smallW, gap: smallGap,
          segH: 3.2, segGap: 1.4, corner: 0.6, glow: false)

NSGraphicsContext.restoreGraphicsState()
// l'App Store rifiuta i PNG con canale alpha: ricopio il bitmap in un contesto senza alpha e lo esporto da lì
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
guard let flat = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                           bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue),
      let src = rep.cgImage,
      let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: out) as CFURL, "public.png" as CFString, 1, nil)
else { fatalError("png") }
flat.draw(src, in: CGRect(x: 0, y: 0, width: W, height: H))
CGImageDestinationAddImage(dest, flat.makeImage()!, nil)
guard CGImageDestinationFinalize(dest) else { fatalError("scrittura png") }
print("scritto \(out) \(W)x\(H)")
