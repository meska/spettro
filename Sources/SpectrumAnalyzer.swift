// Analisi di spettro: FFT sui campioni del tap, livelli in dB per banda.
// Bande a spaziatura logaritmica tipo analizzatore anni '80 (63 Hz … 16 kHz).

import Accelerate
import Foundation

final class SpectrumAnalyzer {
    let bandCenters: [Double]
    private(set) var bandEdges: [Double] = []

    let fftSize: Int
    private let sampleRate: Double
    private let log2n: vDSP_Length
    private var setup: FFTSetup
    private var window: [Float]
    private var realp: [Float]
    private var imagp: [Float]
    private var magnitudes: [Float]
    private var samples = 0

    /// Quante volte dividere le magnitudini per far tornare i dBFS veri.
    /// Non è deducibile a tavolino: la finestra di Hann "normalizzata" di vDSP e la
    /// convenzione zrip danno un guadagno complessivo che ho **misurato** con toni campione
    /// a 60, 1000 e 8000 Hz (ampiezza 0.30 = −10,5 dBFS): la banda leggeva −6,8 dB, cioè
    /// 1,53 volte troppo. Dopo la correzione i tre toni leggono ≈ −10,5 dB.
    private static let measuredWindowGain: Float = 1.53
    private let calibration: Float

    init(bandCenters: [Double], sampleRate: Double, fftSize: Int = 2048) {
        self.bandCenters = bandCenters
        self.sampleRate = sampleRate
        self.fftSize = fftSize
        self.samples = fftSize
        let n = vDSP_Length(fftSize)
        self.log2n = vDSP_Length(log2(Double(fftSize)))
        self.setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))!
        self.window = [Float](repeating: 0, count: fftSize)
        self.realp = [Float](repeating: 0, count: fftSize / 2)
        self.imagp = [Float](repeating: 0, count: fftSize / 2)
        self.magnitudes = [Float](repeating: 0, count: fftSize / 2)
        // finestra di Hann normalizzata (guadagno coerente 1)
        vDSP_hann_window(&window, n, Int32(vDSP_HANN_NORM))
        // la fft zrip restituisce il doppio dell'ampiezza; il fattore di finestra è misurato
        self.calibration = 2.0 / (Float(fftSize) * Self.measuredWindowGain)

        // bordi di banda: medie geometriche fra i centri, primo e ultimo aperti
        var edges: [Double] = [bandCenters.first! / 2.0]
        for i in 0..<(bandCenters.count - 1) {
            edges.append((bandCenters[i] * bandCenters[i + 1]).squareRoot())
        }
        edges.append(min(bandCenters.last! * 1.6, sampleRate / 2.0 - 1))
        self.bandEdges = edges
        rebuildTiltOffsets()
    }

    deinit { vDSP_destroy_fftsetup(setup) }

    /// Pendenza del display in dB per ottava, centrata su 1 kHz (positivo = alti in su).
    /// È la "tilt" degli analizzatori professionali: la musica ha molta più energia in basso
    /// che in alto, e con le bande basse strette il fianco sinistro diventa un muro sempre pieno.
    /// A 0 il display è la verità misurata; a +4,5 dB/ottava rassomiglia a un RTA con pesatura rosa.
    var tiltPerOctave: Double = 0 {
        didSet { rebuildTiltOffsets() }
    }
    private var tiltOffsets: [Float] = []

    private func rebuildTiltOffsets() {
        tiltOffsets = bandCenters.map { center in
            tiltPerOctave == 0 ? 0 : Float(tiltPerOctave * log2(center / 1000.0))
        }
    }

    /// Livello in dBFS per banda (0 dBFS = fondo scala digitale), dall'ultimo blocco di `fftSize` campioni.
    func bands(from buffer: [Float]) -> [Float] {
        guard buffer.count >= fftSize else { return bandCenters.map { _ in -100 } }

        var windowed = [Float](repeating: 0, count: fftSize)
        let last = Array(buffer.suffix(fftSize))
        vDSP_vmul(last, 1, window, 1, &windowed, 1, vDSP_Length(fftSize))

        var result = [Float](repeating: -100, count: bandCenters.count)
        realp.withUnsafeMutableBufferPointer { rp in
            imagp.withUnsafeMutableBufferPointer { ip in
                var split = DSPSplitComplex(realp: rp.baseAddress!, imagp: ip.baseAddress!)
                windowed.withUnsafeBufferPointer { inp in
                    inp.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: fftSize / 2) { typed in
                        vDSP_ctoz(typed, 2, &split, 1, vDSP_Length(fftSize / 2))
                    }
                }
                vDSP_fft_zrip(setup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
                vDSP_zvabs(&split, 1, &magnitudes, 1, vDSP_Length(fftSize / 2))
            }
        }

        let binWidth = sampleRate / Double(fftSize)
        for b in 0..<bandCenters.count {
            let lo = max(bandEdges[b], 0) / binWidth
            let hi = min(bandEdges[b + 1], binWidth * Double(fftSize / 2 - 1)) / binWidth
            let firstBin = max(1, Int(lo.rounded(.down)))
            let lastBin = max(firstBin, Int(hi.rounded(.up)))
            // massimo della banda, non media: una banda larga (63 righe in quella dei 16 kHz)
            // altrimenti legge 15 dB sotto un tono che la attraversa, e le bande basse strette
            // (2-3 righe) riempiono tre barre a testa per la larghezza del lobo di Hann.
            var peak: Float = 0
            for bin in firstBin...min(lastBin, fftSize / 2 - 1) where magnitudes[bin] > peak {
                peak = magnitudes[bin]
            }
            let db = 20 * log10(max(peak * calibration, 1e-7))
            result[b] = db + tiltOffsets[b]
        }
        return result
    }
}
