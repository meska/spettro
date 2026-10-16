// Analizzatore di spettro verticale: barre a segmenti, verdi in basso, rosse in alto,
// più il picco che resta appeso come sui vecchi cassoni.

import AppKit

final class SpectrumView: NSView {
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
    private(set) var sizeScale: CGFloat = 1.0

    /// true = puntini (la riga non è continua, come sul display del Technics), false = barre piene.
    var dotMode = true {
        didSet { rebuildRects(); needsDisplay = true }
    }
    var peakHold = true {
        didSet { if !peakHold { resetPeaks() } }
    }

    private var lit: [Int]                 // segmenti accesi per banda
    private var peaks: [CGFloat]           // altezza del picco, 0...1, con decadimento
    private var peakLevels: [Int]          // livello disegnato della tacca, -1 = nessuna
    private var segRects: [[NSRect]] = []  // [banda][livello]
    private var builtFor: NSSize = .zero

    init(bandCount: Int) {
        self.bandCount = bandCount
        self.lit = Array(repeating: 0, count: bandCount)
        self.peaks = Array(repeating: 0, count: bandCount)
        self.peakLevels = Array(repeating: -1, count: bandCount)
        super.init(frame: .zero)
        rebuildRects()
    }

    required init?(coder: NSCoder) { fatalError("non usato") }

    override var intrinsicContentSize: NSSize {
        let w = CGFloat(bandCount) * barWidth + CGFloat(bandCount - 1) * barGap
        let h = CGFloat(levelCount) * segHeight + CGFloat(levelCount - 1) * segGap
        return NSSize(width: ceil(w), height: ceil(h))
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        if newSize != builtFor { rebuildRects() }
    }

    /// Cambia la dimensione del display (colonne e segmenti insieme).
    func setSizeScale(_ scale: CGFloat) {
        guard scale != sizeScale else { return }
        sizeScale = scale
        barWidth = baseBarWidth * scale
        barGap = baseBarGap * scale
        // l'altezza ha un tetto: la barra dei menu è alta ~24 pt e quel che sborda viene tagliato
        let baseHeight = CGFloat(levelCount) * baseSegHeight + CGFloat(levelCount - 1) * baseSegGap
        let heightScale = min(scale, 20.0 / baseHeight)
        segHeight = baseSegHeight * heightScale
        segGap = baseSegGap * heightScale
        rebuildRects()
        needsDisplay = true
    }

    /// I click devono arrivare al bottone della status bar, non a questa view.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    private var peakTick: [NSRect] = []      // tacchetta del picco, calcolata una volta

    private func rebuildRects() {
        builtFor = bounds.size
        let totalW = intrinsicContentSize.width
        let totalH = intrinsicContentSize.height
        let x0 = max(0, (bounds.width - totalW) / 2)
        let y0 = max(0, (bounds.height - totalH) / 2)
        segRects = []
        peakTick = []
        for b in 0..<bandCount {
            var column: [NSRect] = []
            for l in 0..<levelCount {           // 0 = in basso
                let x = x0 + CGFloat(b) * (barWidth + barGap)
                let y = y0 + CGFloat(l) * (segHeight + segGap)
                // a barre piene i segmenti si toccano (barra continua); a punti restano staccati
                let h = dotMode ? segHeight * 0.65 : segHeight + segGap
                column.append(NSRect(x: x, y: y, width: barWidth, height: h))
                // tacchetta del picco: piccola, centrata nel segmento, non un segmento intero
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

    /// Livelli normalizzati 0...1 per banda; `peakDecay` è quanto scende la tacca a ogni frame.
    /// Ritorna true se ha ridisegnato.
    @discardableResult
    func update(levels: [CGFloat], peakDecay: CGFloat) -> Bool {
        var redraw = false
        for b in 0..<bandCount {
            let value = b < levels.count ? min(max(levels[b], 0), 1) : 0
            let newLit = Int((value * CGFloat(levelCount)).rounded())
            if newLit != lit[b] {
                lit[b] = newLit
                redraw = true
            }
            guard peakHold else { continue }
            let target = CGFloat(newLit) / CGFloat(levelCount)
            if target > peaks[b] {
                peaks[b] = target
            } else if peaks[b] > 0 {
                peaks[b] = max(target, peaks[b] - peakDecay)
            }
            // il disegno della tacca è quantizzato: si ridisegna solo quando cambia *quel* livello,
            // non a ogni passo del decadimento (era il motivo di una CPU più alta del necessario)
            let drawn = peakLevel(for: peaks[b])
            if drawn != peakLevels[b] {
                peakLevels[b] = drawn
                redraw = true
            }
        }
        if redraw { needsDisplay = true }
        return redraw
    }

    func resetPeaks() {
        peaks = Array(repeating: 0, count: bandCount)
        peakLevels = Array(repeating: -1, count: bandCount)
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let dim = Palette.unlit
        for b in 0..<bandCount {
            let column = segRects[b]
            for l in 0..<levelCount {
                let on = l < lit[b]
                (on ? Palette.led(forLevel: l, of: levelCount) : dim).setFill()
                column[l].fill()
            }
            if peakHold, peakLevels[b] >= lit[b] && peakLevels[b] >= 0 {
                // tacchetta del picco: piccola e smorzata, solo sopra la barra
                Palette.peak.setFill()
                peakTick[b * levelCount + peakLevels[b]].fill()
            }
        }
    }
}
