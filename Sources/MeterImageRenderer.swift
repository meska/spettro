// Variante "a immagine": invece di tenere una view viva dentro la status item, il meter
// viene disegnato in un bitmap fuori schermo e consegnato al bottone come NSImage.
// Costa la CPU del disegno (poca) e un blit, senza far ridisegnare la view nella barra dei menu.

import AppKit

final class MeterImageRenderer {
    let bandCount: Int
    let levelCount = 10

    // geometria di base (scala 1.0): si moltiplica tutta per `sizeScale`
    private let baseBarWidth: CGFloat = 5.0
    private let baseBarGap: CGFloat = 1.0
    private let baseSegHeight: CGFloat = 1.4
    private let baseSegGap: CGFloat = 0.6

    private var barWidth: CGFloat = 5.0
    private var barGap: CGFloat = 1.0
    private var segHeight: CGFloat = 1.4
    private var segGap: CGFloat = 0.6

    var dotMode = true {
        didSet { dirty = true; buildRects() }   // senza questo, cambiare display non faceva nulla
    }
    var peakHold = true
    private(set) var sizeScale: CGFloat = 1.0
    /// Vero quando la geometria o i colori sono cambiati: il prossimo update deve ridisegnare
    /// anche se i livelli sono identici (altrimenti in silenzio la barra resta con l'immagine vecchia).
    private var dirty = false

    private var lit: [Int]
    private var peaks: [CGFloat]
    private var peakLevels: [Int]
    private var segRects: [[NSRect]] = []
    private var peakTick: [NSRect] = []

    private(set) var rep: NSBitmapImageRep
    private(set) var size: NSSize
    private let screenScale: CGFloat

    init(bandCount: Int, screenScale: CGFloat) {
        self.bandCount = bandCount
        self.screenScale = screenScale
        self.lit = Array(repeating: 0, count: bandCount)
        self.peaks = Array(repeating: 0, count: bandCount)
        self.peakLevels = Array(repeating: -1, count: bandCount)

        let w = CGFloat(bandCount) * baseBarWidth + CGFloat(bandCount - 1) * baseBarGap
        let h = CGFloat(levelCount) * baseSegHeight + CGFloat(levelCount - 1) * baseSegGap
        self.size = NSSize(width: ceil(w), height: ceil(h))
        self.rep = MeterImageRenderer.makeRep(size: size, screenScale: screenScale)
        buildRects()
    }

    private static func makeRep(size: NSSize, screenScale: CGFloat) -> NSBitmapImageRep {
        let pw = max(1, Int(size.width * screenScale)), ph = max(1, Int(size.height * screenScale))
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pw, pixelsHigh: ph,
                                        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                        isPlanar: false, colorSpaceName: .deviceRGB,
                                        bytesPerRow: 0, bitsPerPixel: 0) else {
            fatalError("niente bitmap")
        }
        rep.size = size
        return rep
    }

    /// Cambia la dimensione del display: la barra dei menu ospita quello che ci sta, quindi
    /// la scelta è dell'utente e va applicata a tutta la geometria insieme.
    func setSizeScale(_ scale: CGFloat) {
        guard scale != sizeScale else { return }
        sizeScale = scale
        dirty = true
        barWidth = baseBarWidth * scale
        barGap = baseBarGap * scale
        // l'altezza ha un tetto: la barra dei menu è alta ~24 pt e quel che sborda viene tagliato
        let baseHeight = CGFloat(levelCount) * baseSegHeight + CGFloat(levelCount - 1) * baseSegGap
        let heightScale = min(scale, 20.0 / baseHeight)
        segHeight = baseSegHeight * heightScale
        segGap = baseSegGap * heightScale
        let w = CGFloat(bandCount) * barWidth + CGFloat(bandCount - 1) * barGap
        let h = CGFloat(levelCount) * segHeight + CGFloat(levelCount - 1) * segGap
        size = NSSize(width: ceil(w), height: ceil(h))
        rep = MeterImageRenderer.makeRep(size: size, screenScale: screenScale)
        buildRects()
    }

    private func buildRects() {
        segRects = []
        peakTick = []
        for b in 0..<bandCount {
            var column: [NSRect] = []
            for l in 0..<levelCount {
                let x = CGFloat(b) * (barWidth + barGap)
                let y = CGFloat(l) * (segHeight + segGap)
                // a barre piene i segmenti si toccano (barra continua); a punti restano staccati
                let h = dotMode ? segHeight * 0.65 : segHeight + segGap
                column.append(NSRect(x: x, y: y, width: barWidth, height: h))
                let tickW = barWidth * 0.6
                let tickH = segHeight * 0.8
                peakTick.append(NSRect(x: x + (barWidth - tickW) / 2,
                                       y: y + (segHeight - tickH) / 2,
                                       width: tickW, height: tickH))
            }
            segRects.append(column)
        }
    }

    private func peakLevel(for value: CGFloat) -> Int {
        value > 0 ? min(levelCount - 1, max(0, Int((value * CGFloat(levelCount)).rounded()) - 1)) : -1
    }

    /// Aggiorna lo stato e, se qualcosa è cambiato, restituisce l'immagine da dare alla status item.
    func update(levels: [CGFloat], peakDecay: CGFloat) -> NSImage? {
        var changed = false
        for b in 0..<bandCount {
            let value = b < levels.count ? min(max(levels[b], 0), 1) : 0
            let newLit = Int((value * CGFloat(levelCount)).rounded())
            if newLit != lit[b] {
                lit[b] = newLit
                changed = true
            }
            if peakHold {
                let target = CGFloat(newLit) / CGFloat(levelCount)
                if target > peaks[b] {
                    peaks[b] = target
                } else if peaks[b] > 0 {
                    peaks[b] = max(target, peaks[b] - peakDecay)
                }
                let drawn = peakLevel(for: peaks[b])
                if drawn != peakLevels[b] {
                    peakLevels[b] = drawn
                    changed = true
                }
            }
        }
        guard changed || dirty else { return nil }
        dirty = false
        return render()
    }

    /// Chiamata dalle impostazioni quando cambiano colore o geometria: la prossima `update`
    /// ridisegna anche a livelli fermi.
    func markDirty() { dirty = true }

    func resetPeaks() {
        peaks = Array(repeating: 0, count: bandCount)
        peakLevels = Array(repeating: -1, count: bandCount)
    }

    private func render() -> NSImage {
        let ctx = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = ctx
        if let cg = ctx?.cgContext {
            cg.clear(CGRect(x: 0, y: 0, width: size.width, height: size.height))
        }
        let dim = Palette.unlit
        for b in 0..<bandCount {
            let column = segRects[b]
            for l in 0..<levelCount {
                let on = l < lit[b]
                (on ? Palette.led(forLevel: l, of: levelCount) : dim).setFill()
                column[l].fill()
            }
            if peakHold, peakLevels[b] >= lit[b] && peakLevels[b] >= 0 {
                Palette.peak.setFill()
                peakTick[b * levelCount + peakLevels[b]].fill()
            }
        }
        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: size)
        let copy = rep.copy() as! NSBitmapImageRep
        copy.size = size
        image.addRepresentation(copy)
        image.isTemplate = false
        return image
    }
}
