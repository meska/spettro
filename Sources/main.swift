// Spectrum — analizzatore di spettro da barra dei menu.
// Quando c'è silenzio il timer di disegno si spegne: a riposo non costa nulla.

import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// 20 bande a spaziatura logaritmica da 40 Hz a 16 kHz.
    private let bandCenters: [Double] = {
        let count = 20, low = 40.0, high = 16000.0
        let ratio = pow(high / low, 1.0 / Double(count - 1))
        return (0..<count).map { low * pow(ratio, Double($0)) }
    }()

    private lazy var view = SpectrumView(bandCount: bandCenters.count)
    private lazy var renderer = MeterImageRenderer(bandCount: bandCenters.count,
                                                   screenScale: NSScreen.main?.backingScaleFactor ?? 2)
    private lazy var statusItem = NSStatusBar.system.statusItem(
        withLength: (useImage ? renderer.size.width : view.intrinsicContentSize.width) + 8)
    private let meter = AudioMeter()
    private var analyzer: SpectrumAnalyzer?

    private var timer: Timer?
    private var shown: [CGFloat] = []       // livello disegnato per banda, con ballistica
    private var lastLoudTS: Double = 0
    private var silentLogged = false
    private let logLevels: Bool
    private let noFeed: Bool          // diagnostica: --nofeed stacca il disegno
    private let useImage: Bool        // predefinito: immagine già pronta; --view torna alla view viva
    /// Diagnostica: disegna a ogni frame ma consegna alla barra solo 1 volta su N (--commit N).
    private let commitEvery: Int
    private var commitCounter = 0
    private var logTick = 0

    private var floorDB: Float = -66        // sensibilità (fondo scala del display)
    /// Pendenza del display in dB per ottava, centrata su 1 kHz. +4,5 è la scelta dell'utente:
    /// con "Piatta" il fianco sinistro resta un muro perché la musica ha molta più energia in basso.
    private var tiltDB: Double = 4.5
    private var sizeScale: CGFloat = 1.0    // dimensione del display in barra
    private var refreshRate: TimeInterval = 1.0 / 24.0

    // chiavi di memoria: le scelte dell'utente sopravvivono al riavvio
    private enum Pref {
        static let sizeScale = "sizeScale"
        static let floorDB = "floorDB"
        static let fps = "fps"
        static let dotMode = "dotMode"
        static let peakHold = "peakHold"
        static let tilt = "tiltPerOctave"
    }

    // diagnostica (solo con --log): conteggi al secondo
    private var renderCount = 0
    private var redrawCount = 0
    private var lastCallbackCount = 0
    private var diagWindowStart = Date.timeIntervalSinceReferenceDate

    /// Dimensione della FFT: 2048 di serie, 4096 per separare meglio le bande basse.
    private var fftSize = 2048

    init(logLevels: Bool) {
        self.logLevels = logLevels
        self.noFeed = CommandLine.arguments.contains("--nofeed")
        self.useImage = !CommandLine.arguments.contains("--view")
        if let i = CommandLine.arguments.firstIndex(of: "--commit"),
           i + 1 < CommandLine.arguments.count,
           let n = Int(CommandLine.arguments[i + 1]), n > 0 {
            self.commitEvery = n
        } else {
            self.commitEvery = 1
        }
        // diagnostica: dimensione della FFT (2048 predefinita, 4096 separa meglio i bassi)
        if let i = CommandLine.arguments.firstIndex(of: "--fft"),
           i + 1 < CommandLine.arguments.count,
           let n = Int(CommandLine.arguments[i + 1]), n >= 256, n.nonzeroBitCount == 1 {
            self.fftSize = n
        }
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        loadPrefs()
        view.setSizeScale(sizeScale)
        renderer.setSizeScale(sizeScale)
        view.dotMode = renderer.dotMode
        view.peakHold = renderer.peakHold
        resizeStatusItem()

        if let button = statusItem.button {
            if useImage {
                button.imagePosition = .imageOnly
            } else {
                let size = view.intrinsicContentSize
                view.frame = NSRect(x: 4, y: (button.bounds.height - size.height) / 2,
                                    width: size.width, height: size.height)
                view.autoresizingMask = [.minXMargin, .maxXMargin, .minYMargin, .maxYMargin]
                button.addSubview(view)
            }
        }
        statusItem.menu = buildMenu()

        // diagnostica: il menu localizzato su stdout, poi si esce (niente tap audio, niente permesso)
        if CommandLine.arguments.contains("--dump-menu"), let menu = statusItem.menu {
            dumpMenu(menu)
            exit(0)
        }

        meter.onSignal = { [weak self] _ in
            guard let self else { return }
            self.lastLoudTS = Date.timeIntervalSinceReferenceDate
            DispatchQueue.main.async { self.startTimerIfNeeded() }
        }

        do {
            try meter.start()
            let a = SpectrumAnalyzer(bandCenters: bandCenters, sampleRate: meter.sampleRate, fftSize: fftSize)
            a.tiltPerOctave = tiltDB
            analyzer = a
            shown = Array(repeating: 0, count: bandCenters.count)
            log("tap attivo: \(Int(meter.sampleRate)) Hz, \(bandCenters.count) bande "
                + bandCenters.map { "\(Int($0))" }.joined(separator: "/") + " Hz, FFT \(fftSize), fondo scala \(Int(floorDB)) dB"
                + (tiltDB == 0 ? "" : ", pendenza \(tiltDB) dB/ottava"))
        } catch {
            log("avvio fallito: \(error)")
            showStartupError(String(describing: error))
        }

        // diagnostica: apre la finestra dei colori all'avvio, per poterla fotografare senza click
        if CommandLine.arguments.contains("--colors") {
            showColors()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
        meter.stop()
    }

    // MARK: - menu

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        let info = NSMenuItem(title: L("menu.about"), action: nil, keyEquivalent: "")
        info.isEnabled = false
        menu.addItem(info)
        menu.addItem(.separator())

        let sens = NSMenuItem(title: L("menu.sensitivity"), action: nil, keyEquivalent: "")
        let sensSub = NSMenu()
        // etichette per effetto: fondo scala più basso = la barra si alza con suoni più deboli
        for (key, db) in [("menu.sens.verySensitive", Float(-78)),
                          ("menu.sens.sensitive", Float(-66)),
                          ("menu.sens.normal", Float(-48)),
                          ("menu.sens.concert", Float(-30))] {
            let item = NSMenuItem(title: L(key), action: #selector(setFloor(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = db
            item.state = (db == floorDB) ? .on : .off
            sensSub.addItem(item)
        }
        sens.submenu = sensSub
        menu.addItem(sens)

        let display = NSMenuItem(title: L("menu.display"), action: nil, keyEquivalent: "")
        let displaySub = NSMenu()
        for (key, dots) in [("menu.display.dots", true), ("menu.display.bars", false)] {
            let item = NSMenuItem(title: L(key), action: #selector(setDisplayMode(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = dots
            item.state = (dots == view.dotMode) ? .on : .off
            displaySub.addItem(item)
        }
        display.submenu = displaySub
        menu.addItem(display)

        let size = NSMenuItem(title: L("menu.size"), action: nil, keyEquivalent: "")
        let sizeSub = NSMenu()
        // nel menu perché la barra dei menu è di tutti: la misura giusta dipende dallo schermo
        for (key, scale) in [("menu.size.compact", 0.6), ("menu.size.normal", 0.8),
                             ("menu.size.wide", 1.0), ("menu.size.max", 1.3)] {
            let item = NSMenuItem(title: L(key), action: #selector(setSize(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = scale
            item.state = (abs(CGFloat(scale) - sizeScale) < 0.01) ? .on : .off
            sizeSub.addItem(item)
        }
        size.submenu = sizeSub
        menu.addItem(size)

        let tilt = NSMenuItem(title: L("menu.tilt"), action: nil, keyEquivalent: "")
        let tiltSub = NSMenu()
        // la pendenza non cambia quello che l'analizzatore misura, cambia come si legge:
        // la musica ha molta più energia in basso, e senza pendenza il fianco sinistro sta sempre su
        for (key, db) in [("menu.tilt.flat", 0.0),
                          ("menu.tilt.p3", 3.0),
                          ("menu.tilt.p45", 4.5)] {
            let item = NSMenuItem(title: L(key), action: #selector(setTilt(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = db
            item.state = (abs(db - tiltDB) < 0.01) ? .on : .off
            tiltSub.addItem(item)
        }
        tilt.submenu = tiltSub
        menu.addItem(tilt)

        let peak = NSMenuItem(title: L("menu.peakHold"), action: #selector(togglePeakHold(_:)), keyEquivalent: "")
        peak.target = self
        peak.state = view.peakHold ? .on : .off
        menu.addItem(peak)

        let fps = NSMenuItem(title: L("menu.rate"), action: nil, keyEquivalent: "")
        let fpsSub = NSMenu()
        // l'unica leva vera sulla CPU: quante volte al secondo si tocca la barra dei menu
        for (key, rate) in [("menu.rate.30", 30.0),
                            ("menu.rate.24", 24.0),
                            ("menu.rate.16", 16.0),
                            ("menu.rate.8", 8.0)] {
            let item = NSMenuItem(title: L(key), action: #selector(setRefreshRate(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = rate
            item.state = (abs(rate - 1.0 / refreshRate) < 0.5) ? .on : .off
            fpsSub.addItem(item)
        }
        fps.submenu = fpsSub
        menu.addItem(fps)

        let retry = NSMenuItem(title: L("menu.restart"), action: #selector(restartCapture), keyEquivalent: "")
        retry.target = self
        menu.addItem(retry)

        let colors = NSMenuItem(title: L("menu.colors"), action: #selector(showColors), keyEquivalent: "")
        colors.target = self
        menu.addItem(colors)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: L("menu.quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
        return menu
    }

    /// Diagnostica: stampa il menu così come lo vede l'utente, poi esce. È il modo per verificare
    /// una traduzione senza aprire il menu a mano:
    ///   Spettro --dump-menu -AppleLanguages '(de)'
    private func dumpMenu(_ menu: NSMenu) {
        func walk(_ m: NSMenu, _ depth: Int) {
            for item in m.items {
                let pad = String(repeating: "  ", count: depth)
                if item.isSeparatorItem {
                    print("\(pad)---")
                } else {
                    let mark = item.submenu != nil ? "" : (item.state == .on ? "[x] " : "[ ] ")
                    print("\(pad)\(mark)\(item.title)")
                }
                if let sub = item.submenu { walk(sub, depth + 1) }
            }
        }
        walk(menu, 0)

        // Le due chiavi dell'Info.plist che l'utente legge: il nome dell'app e il testo del
        // dialogo di permesso audio. macOS le prende da InfoPlist.strings della lingua attiva.
        print("# InfoPlist")
        for key in ["CFBundleDisplayName", "NSAudioCaptureUsageDescription"] {
            let value = (Bundle.main.localizedInfoDictionary?[key] as? String)
                ?? (Bundle.main.infoDictionary?[key] as? String)
                ?? "(manca)"
            print("\(key)|\(value)")
        }
    }

    @objc private func showColors() {
        ColorsPanel.shared.onChange = { [weak self] in
            self?.renderer.markDirty()
            self?.forceRedraw()
        }
        ColorsPanel.shared.show()
    }

    @objc private func setFloor(_ sender: NSMenuItem) {
        guard let db = sender.representedObject as? Float else { return }
        floorDB = db
        UserDefaults.standard.set(Double(db), forKey: Pref.floorDB)
        sender.menu?.items.forEach { $0.state = ($0.representedObject as? Float == db) ? .on : .off }
    }

    @objc private func setSize(_ sender: NSMenuItem) {
        guard let scale = sender.representedObject as? Double else { return }
        sizeScale = CGFloat(scale)
        view.setSizeScale(sizeScale)
        renderer.setSizeScale(sizeScale)
        resizeStatusItem()
        UserDefaults.standard.set(scale, forKey: Pref.sizeScale)
        sender.menu?.items.forEach {
            $0.state = (abs(CGFloat(($0.representedObject as? Double) ?? -1) - sizeScale) < 0.01) ? .on : .off
        }
        forceRedraw()
    }

    private func resizeStatusItem() {
        let w = (useImage ? renderer.size.width : view.intrinsicContentSize.width) + 8
        statusItem.length = w
        if !useImage, let button = statusItem.button {
            let s = view.intrinsicContentSize
            view.frame = NSRect(x: 4, y: (button.bounds.height - s.height) / 2, width: s.width, height: s.height)
        }
    }

    /// Ridisegna subito, senza aspettare il prossimo frame (dopo un cambio di dimensione o colore).
    private func forceRedraw() {
        if useImage {
            if let image = renderer.update(levels: shown.isEmpty
                                           ? Array(repeating: 0, count: bandCenters.count) : shown,
                                           peakDecay: 1) {
                statusItem.button?.image = image
            }
        } else {
            view.needsDisplay = true
        }
    }

    @objc private func setTilt(_ sender: NSMenuItem) {
        guard let db = sender.representedObject as? Double else { return }
        tiltDB = db
        analyzer?.tiltPerOctave = db
        UserDefaults.standard.set(db, forKey: Pref.tilt)
        sender.menu?.items.forEach { $0.state = (($0.representedObject as? Double) == db) ? .on : .off }
        forceRedraw()
    }

    @objc private func setDisplayMode(_ sender: NSMenuItem) {
        guard let dots = sender.representedObject as? Bool else { return }
        view.dotMode = dots
        renderer.dotMode = dots
        UserDefaults.standard.set(dots, forKey: Pref.dotMode)
        sender.menu?.items.forEach { $0.state = (($0.representedObject as? Bool) == dots) ? .on : .off }
        forceRedraw()
    }
    @objc private func togglePeakHold(_ sender: NSMenuItem) {
        view.peakHold.toggle()
        renderer.peakHold = view.peakHold
        UserDefaults.standard.set(view.peakHold, forKey: Pref.peakHold)
        sender.state = view.peakHold ? .on : .off
    }

    @objc private func setRefreshRate(_ sender: NSMenuItem) {
        guard let rate = sender.representedObject as? Double, rate > 0 else { return }
        refreshRate = 1.0 / rate
        UserDefaults.standard.set(rate, forKey: Pref.fps)
        sender.menu?.items.forEach { $0.state = (($0.representedObject as? Double) == rate) ? .on : .off }
        // il timer va rifatto: se era attivo lo riavvio, altrimenti ripartirà al prossimo segnale
        let wasRunning = timer != nil
        timer?.invalidate()
        timer = nil
        if wasRunning { startTimerIfNeeded() }
    }

    // MARK: - preferenze

    private func loadPrefs() {
        let d = UserDefaults.standard
        if d.object(forKey: Pref.sizeScale) != nil {
            sizeScale = CGFloat(d.double(forKey: Pref.sizeScale))
        }
        if d.object(forKey: Pref.floorDB) != nil {
            floorDB = Float(d.double(forKey: Pref.floorDB))
        }
        if d.object(forKey: Pref.fps) != nil {
            let fps = d.double(forKey: Pref.fps)
            if fps > 0 { refreshRate = 1.0 / fps }
        }
        renderer.dotMode = d.object(forKey: Pref.dotMode) as? Bool ?? true
        renderer.peakHold = d.object(forKey: Pref.peakHold) as? Bool ?? true
        if d.object(forKey: Pref.tilt) != nil {
            tiltDB = d.double(forKey: Pref.tilt)
        }
        Palette.load()
    }

    @objc private func restartCapture() {
        meter.stop()
        do {
            try meter.start()
            let a = SpectrumAnalyzer(bandCenters: bandCenters, sampleRate: meter.sampleRate, fftSize: fftSize)
            a.tiltPerOctave = tiltDB
            analyzer = a
            log("cattura riavviata: \(Int(meter.sampleRate)) Hz")
        } catch {
            log("riavvio fallito: \(error)")
            showStartupError(String(describing: error))
        }
    }

    // MARK: - analisi e disegno, solo quando serve

    private func startTimerIfNeeded() {
        guard timer == nil else { return }
        let t = Timer(timeInterval: refreshRate, repeats: true) { [weak self] _ in self?.render() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func render() {
        guard let analyzer, shown.count == bandCenters.count else { return }
        let samples = meter.latestSamples(count: analyzer.fftSize)
        let dbs = analyzer.bands(from: samples)

        var loudest: Float = -200
        // ballistiche legate al tempo, non ai frame: cambiando frequenza non cambiano
        let release = CGFloat(pow(0.80, refreshRate * 16.0))
        // la tacca cade più in fretta (mezzo fondo scala al secondo) e si mostra solo
        // quando sta *sopra* la barra: se la barra l'ha raggiunta non aggiunge niente
        let peakDecay = 0.025 * CGFloat(refreshRate * 16.0)
        for i in 0..<shown.count {
            loudest = max(loudest, dbs[i])
            let norm = CGFloat(max(0, min(1, (dbs[i] - floorDB) / -floorDB)))
            shown[i] = max(norm, shown[i] * release)   // attacco immediato, rilascio lento
        }
        renderCount += 1
        if !noFeed {
            if useImage {
                if let image = renderer.update(levels: shown, peakDecay: peakDecay) {
                    commitCounter += 1
                    if commitCounter >= commitEvery {
                        commitCounter = 0
                        statusItem.button?.image = image
                        redrawCount += 1
                    }
                }
            } else {
                if view.update(levels: shown, peakDecay: peakDecay) { redrawCount += 1 }
            }
        }

        if logLevels {
            let now = Date.timeIntervalSinceReferenceDate
            if now - diagWindowStart >= 1.0 {
                let dt = now - diagWindowStart
                let cbs = Double(meter.callbackCount - lastCallbackCount) / dt
                log(String(format: "diag: audio %.0f/s, render %.0f/s, ridisegni %.0f/s, cpu %.1f%%",
                           cbs, Double(renderCount) / dt, Double(redrawCount) / dt, Self.cpuPercent()))
                lastCallbackCount = meter.callbackCount
                renderCount = 0
                redrawCount = 0
                diagWindowStart = now
            }
            logTick += 1
            if logTick % 32 == 0 {
                let cols = zip(bandCenters, dbs)
                    .map { String(format: "%5dHz=%6.1f", Int($0.0), $0.1) }
                    .joined(separator: " ")
                log(cols)
            }
        }

        if loudest < floorDB + 3, Date.timeIntervalSinceReferenceDate - lastLoudTS > 1.2 {
            shown = Array(repeating: 0, count: bandCenters.count)
            if useImage {
                if let image = renderer.update(levels: shown, peakDecay: 1) { statusItem.button?.image = image }
            } else {
                view.update(levels: shown, peakDecay: 1)
            }
            timer?.invalidate()
            timer = nil
            if !silentLogged {
                log("silenzio: timer di disegno spento (a riposo)")
                silentLogged = true
            }
        } else {
            silentLogged = false
        }
    }

    // MARK: - aiuto

    private static func cpuPercent() -> Double {
        var usage = rusage()
        guard getrusage(RUSAGE_SELF, &usage) == 0 else { return 0 }
        let user = Double(usage.ru_utime.tv_sec) + Double(usage.ru_utime.tv_usec) / 1e6
        let sys = Double(usage.ru_stime.tv_sec) + Double(usage.ru_stime.tv_usec) / 1e6
        return (user + sys) / ProcessInfo.processInfo.systemUptime * 100
    }

    private func showStartupError(_ detail: String) {
        let alert = NSAlert()
        alert.messageText = L("alert.error.title")
        alert.informativeText = String(format: L("alert.error.body"), detail)
        alert.addButton(withTitle: L("alert.ok"))
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private func log(_ message: String) {
        FileHandle.standardError.write(Data("[spettro] \(message)\n".utf8))
    }
}

// MARK: - avvio

let logLevels = CommandLine.arguments.contains("--log")
setvbuf(stdout, nil, _IOLBF, 0)

let app = NSApplication.shared
let delegate = AppDelegate(logLevels: logLevels)
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
