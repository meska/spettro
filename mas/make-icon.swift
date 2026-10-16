// Genera l'icona dell'app (1024x1024 PNG) disegnandola con CoreGraphics:
// stesso linguaggio del menu bar — barre verticali a segmenti, verdi in basso, rosse in alto.
// Uso: swift mas/make-icon.swift mas/icon-1024.png

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size = 1024.0
let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon-1024.png"

guard let ctx = CGContext(data: nil,
                          width: Int(size), height: Int(size),
                          bitsPerComponent: 8, bytesPerRow: 0,
                          space: CGColorSpace(name: CGColorSpace.sRGB)!,
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
    fatalError("niente contesto grafico")
}

func rgb(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> CGColor {
    CGColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: a)
}

// fondo: squircle scuro con gradiente
let inset = 104.0
let panel = CGRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
let panelPath = CGPath(roundedRect: panel, cornerWidth: 208, cornerHeight: 208, transform: nil)

ctx.saveGState()
ctx.addPath(panelPath)
ctx.clip()
let bgGradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                           colors: [rgb(38, 44, 52), rgb(14, 17, 20)] as CFArray,
                           locations: [0, 1])!
ctx.drawLinearGradient(bgGradient,
                       start: CGPoint(x: 0, y: size),
                       end: CGPoint(x: 0, y: 0),
                       options: [])
ctx.restoreGState()

// bordo del pannello, come il vetro di un display
ctx.addPath(panelPath)
ctx.setStrokeColor(rgb(255, 255, 255, 0.10))
ctx.setLineWidth(4)
ctx.strokePath()

// barre: 7 colonne di segmenti, altezze diverse come uno spettro fermo
let bars: [Int] = [4, 6, 8, 9, 7, 5, 3]        // segmenti accesi per colonna
let levels = 9
let barWidth = 64.0
let barGap = 40.0
let segHeight = 48.0
let segGap = 14.0
let stackHeight = Double(levels) * segHeight + Double(levels - 1) * segGap
let totalWidth = Double(bars.count) * barWidth + Double(bars.count - 1) * barGap
let x0 = (size - totalWidth) / 2
let y0 = (size - stackHeight) / 2

func color(level: Int) -> CGColor {
    let ratio = Double(level) / Double(levels - 1)
    if ratio > 0.85 { return rgb(255, 59, 48) }
    if ratio > 0.66 { return rgb(255, 204, 0) }
    return rgb(52, 199, 89)
}

// tutto dentro il pannello: niente segmenti che sbordano
ctx.saveGState()
ctx.addPath(panelPath)
ctx.clip()

for (index, lit) in bars.enumerated() {
    let x = x0 + Double(index) * (barWidth + barGap)
    for level in 0..<levels {
        let y = y0 + Double(level) * (segHeight + segGap)
        let seg = CGRect(x: x, y: y, width: barWidth, height: segHeight)
        ctx.addPath(CGPath(roundedRect: seg, cornerWidth: 10, cornerHeight: 10, transform: nil))
        ctx.setFillColor(level < lit ? color(level: level) : rgb(255, 255, 255, 0.10))
        ctx.fillPath()
    }
    // tacca del picco, rossa, appoggiata sopra la colonna
    let peakY = y0 + Double(lit) * (segHeight + segGap)
    let cap = CGRect(x: x, y: peakY - segGap / 2 - 8, width: barWidth, height: 16)
    if cap.maxY < panel.maxY {
        ctx.addPath(CGPath(roundedRect: cap, cornerWidth: 8, cornerHeight: 8, transform: nil))
        ctx.setFillColor(rgb(255, 59, 48))
        ctx.fillPath()
    }
}

ctx.restoreGState()

guard let image = ctx.makeImage() else { fatalError("niente immagine") }
let url = URL(fileURLWithPath: outPath)
guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    fatalError("niente destinazione per \(outPath)")
}
CGImageDestinationAddImage(dest, image, nil)
guard CGImageDestinationFinalize(dest) else { fatalError("scrittura fallita") }
print("icona scritta: \(outPath)")
