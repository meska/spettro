// La finestrella dei colori: quattro campioni (verde, ambra, rosso, tacca del picco),
// un cursore per quanto si vedono i segmenti spenti, e un ritorno ai valori di partenza.
// Ogni modifica si applica subito al display e si salva da sola.

import AppKit

final class ColorsPanel: NSObject {
    static let shared = ColorsPanel()

    /// Chiamata a ogni modifica: chi la imposta ridisegna la barra dei menu.
    var onChange: (() -> Void)?

    private var window: NSWindow?
    private var wells: [(name: String, well: NSColorWell)] = []
    private var unlitSlider: NSSlider?
    /// Larghezza delle etichette: non è fissa, si misura sul testo più lungo della lingua attiva.
    /// A 150 punti fissi il russo («Жёлтый (высокие уровни)») usciva tagliato a metà parola.
    private var labelWidth: CGFloat = 150
    private let wellWidth: CGFloat = 60
    private let gutter: CGFloat = 10

    /// Larghezza che serve a un testo con il font di sistema indicato.
    private func width(of text: String, size: CGFloat) -> CGFloat {
        ceil((text as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: size)]).width)
    }

    func show() {
        if window == nil { window = makeWindow() }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        // le quattro etichette dei colori e quella del cursore: la più larga decide la colonna
        let colorKeys = ["colors.green", "colors.amber", "colors.red", "colors.peak"]
        let texts = colorKeys.map { L($0) } + [L("colors.unlit")]
        labelWidth = max(150, texts.map { width(of: $0, size: 12) }.max() ?? 0) + 4

        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 340, height: 300),
                         styleMask: [.titled, .closable],
                         backing: .buffered, defer: false)
        w.title = L("colors.title")
        w.isReleasedWhenClosed = false
        w.center()

        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 10
        root.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)

        let intro = NSTextField(labelWithString: L("colors.intro"))
        intro.font = .systemFont(ofSize: 11)
        intro.textColor = .secondaryLabelColor
        root.addArrangedSubview(intro)

        for (key, name, color) in [("colors.green", "green", Palette.green),
                                   ("colors.amber", "amber", Palette.amber),
                                   ("colors.red", "red", Palette.red),
                                   ("colors.peak", "peak", Palette.peak)] {
            root.addArrangedSubview(row(label: L(key), name: name, color: color))
        }

        // i segmenti spenti: non un colore, un'opacità (seguono il colore del testo di sistema)
        let sliderRow = NSStackView()
        sliderRow.orientation = .horizontal
        sliderRow.spacing = 10
        let sliderLabel = NSTextField(labelWithString: L("colors.unlit"))
        sliderLabel.widthAnchor.constraint(equalToConstant: labelWidth).isActive = true
        sliderLabel.font = .systemFont(ofSize: 12)
        let slider = NSSlider(value: Double(Palette.unlitAlpha), minValue: 0, maxValue: 0.6,
                              target: self, action: #selector(unlitChanged(_:)))
        slider.isContinuous = true
        slider.widthAnchor.constraint(equalToConstant: 130).isActive = true
        sliderRow.addArrangedSubview(sliderLabel)
        sliderRow.addArrangedSubview(slider)
        root.addArrangedSubview(sliderRow)
        unlitSlider = slider

        let buttons = NSStackView()
        buttons.orientation = .horizontal
        buttons.spacing = 10
        let reset = NSButton(title: L("colors.reset"), target: self, action: #selector(resetColors))
        let close = NSButton(title: L("colors.close"), target: self, action: #selector(closeWindow))
        buttons.addArrangedSubview(reset)
        buttons.addArrangedSubview(close)
        root.addArrangedSubview(buttons)

        let note = NSTextField(labelWithString: L("colors.note"))
        note.font = .systemFont(ofSize: 11)
        note.textColor = .secondaryLabelColor
        note.lineBreakMode = .byWordWrapping
        note.maximumNumberOfLines = 2
        // la nota si allarga quanto la colonna (etichetta + cursore)
        note.preferredMaxLayoutWidth = labelWidth + gutter + wellWidth
        root.addArrangedSubview(note)

        w.contentView = root
        // la finestra si adatta al contenuto: in tedesco o in russo le etichette sono più lunghe
        // dell'italiano e a misura fissa uscivano dal bordo
        root.layoutSubtreeIfNeeded()
        let fit = root.fittingSize
        w.setContentSize(NSSize(width: max(fit.width, 340), height: fit.height))
        w.center()
        return w
    }

    private func row(label: String, name: String, color: NSColor) -> NSView {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = gutter

        let text = NSTextField(labelWithString: label)
        text.widthAnchor.constraint(equalToConstant: labelWidth).isActive = true
        text.font = .systemFont(ofSize: 12)

        let well = NSColorWell()
        well.color = color
        well.target = self
        well.action = #selector(colorChanged(_:))
        well.isContinuous = true
        well.widthAnchor.constraint(equalToConstant: wellWidth).isActive = true
        well.heightAnchor.constraint(equalToConstant: 24).isActive = true

        stack.addArrangedSubview(text)
        stack.addArrangedSubview(well)
        wells.append((name, well))
        return stack
    }

    @objc private func colorChanged(_ sender: NSColorWell) {
        guard let entry = wells.first(where: { $0.well === sender }) else { return }
        switch entry.name {
        case "green": Palette.green = sender.color
        case "amber": Palette.amber = sender.color
        case "red":   Palette.red = sender.color
        case "peak":  Palette.peak = sender.color
        default: return
        }
        Palette.save()
        onChange?()
    }

    @objc private func unlitChanged(_ sender: NSSlider) {
        Palette.unlitAlpha = CGFloat(sender.doubleValue)
        Palette.save()
        onChange?()
    }

    @objc private func resetColors() {
        Palette.reset()
        Palette.save()
        for entry in wells {
            switch entry.name {
            case "green": entry.well.color = Palette.green
            case "amber": entry.well.color = Palette.amber
            case "red":   entry.well.color = Palette.red
            case "peak":  entry.well.color = Palette.peak
            default: break
            }
        }
        unlitSlider?.doubleValue = Double(Palette.unlitAlpha)
        onChange?()
    }

    @objc private func closeWindow() {
        window?.orderOut(nil)
    }
}
