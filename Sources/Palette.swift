// Palette del display. I colori sono modificabili a runtime (finestra «Colori…») e
// si salvano fra un avvio e l'altro. Un unico posto dove leggerli.

import AppKit

enum Palette {
    static let defaultGreen = NSColor(srgbRed: 0.16, green: 0.62, blue: 0.30, alpha: 1)
    static let defaultAmber = NSColor(srgbRed: 0.85, green: 0.64, blue: 0.06, alpha: 1)
    static let defaultRed   = NSColor(srgbRed: 0.86, green: 0.20, blue: 0.16, alpha: 1)
    static let defaultPeak  = NSColor(srgbRed: 0.66, green: 0.13, blue: 0.11, alpha: 0.90)
    static let defaultUnlitAlpha: CGFloat = 0.16

    static var green = defaultGreen
    static var amber = defaultAmber
    static var red = defaultRed
    static var peak = defaultPeak
    static var unlitAlpha = defaultUnlitAlpha

    /// Colore del segmento acceso in base al livello (0 = in basso).
    static func led(forLevel level: Int, of total: Int) -> NSColor {
        let ratio = Double(level) / Double(max(total - 1, 1))
        if ratio > 0.85 { return red }
        if ratio > 0.66 { return amber }
        return green
    }

    /// I segmenti spenti seguono il colore del testo (chiaro o scuro secondo la barra dei menu).
    static var unlit: NSColor { NSColor.labelColor.withAlphaComponent(unlitAlpha) }

    static func reset() {
        green = defaultGreen
        amber = defaultAmber
        red = defaultRed
        peak = defaultPeak
        unlitAlpha = defaultUnlitAlpha
    }

    // MARK: - memoria

    private static func key(_ name: String) -> String { "color.\(name)" }

    private static func store(_ color: NSColor, _ name: String, in d: UserDefaults) {
        guard let c = color.usingColorSpace(.sRGB) else { return }
        d.set([c.redComponent, c.greenComponent, c.blueComponent, c.alphaComponent], forKey: key(name))
    }

    private static func read(_ name: String, from d: UserDefaults, fallback: NSColor) -> NSColor {
        guard let a = d.array(forKey: key(name)) as? [Double], a.count == 4 else { return fallback }
        return NSColor(srgbRed: CGFloat(a[0]), green: CGFloat(a[1]),
                       blue: CGFloat(a[2]), alpha: CGFloat(a[3]))
    }

    static func save(to d: UserDefaults = .standard) {
        store(green, "green", in: d)
        store(amber, "amber", in: d)
        store(red, "red", in: d)
        store(peak, "peak", in: d)
        d.set(Double(unlitAlpha), forKey: key("unlitAlpha"))
    }

    static func load(from d: UserDefaults = .standard) {
        green = read("green", from: d, fallback: defaultGreen)
        amber = read("amber", from: d, fallback: defaultAmber)
        red = read("red", from: d, fallback: defaultRed)
        peak = read("peak", from: d, fallback: defaultPeak)
        if d.object(forKey: key("unlitAlpha")) != nil {
            unlitAlpha = CGFloat(d.double(forKey: key("unlitAlpha")))
        }
    }
}
