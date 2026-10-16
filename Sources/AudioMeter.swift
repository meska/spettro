// AudioTap — un tap CoreAudio su tutto l'audio in uscita, per l'analizzatore di spettro.
// Legge soltanto: non registra, non salva, non tocca l'audio.

import Accelerate
import CoreAudio
import Foundation

enum MeterError: Error, CustomStringConvertible {
    case status(OSStatus, String)
    case noOutputDevice

    var description: String {
        switch self {
        case .status(let s, let what): return "\(what) → OSStatus \(s)"
        case .noOutputDevice: return L("error.noOutputDevice")
        }
    }
}

final class AudioMeter {
    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateID = AudioObjectID(kAudioObjectUnknown)
    private var ioProcID: AudioDeviceIOProcID?
    private let ioQueue = DispatchQueue(label: "net.meskatech.vumeter.audio", qos: .userInitiated)

    private let ringCapacity = 8192
    private var ring = [Float](repeating: 0, count: 8192)
    private var ringWrite = 0
    private let ringLock = NSLock()

    /// Frequenza di campionamento del device aggregato (impostata da start()).
    private(set) var sampleRate: Double = 48000

    /// Solo diagnostica: quante volte è stato chiamato l'IOProc (letto dal main thread, non atomico).
    private(set) var callbackCount = 0

    var isRunning: Bool { ioProcID != nil }

    /// Chiamata dal thread audio solo quando arriva segnale (picco sopra la soglia):
    /// serve a far ripartire il timer di disegno senza toccare il main thread nel silenzio.
    var onSignal: ((Float) -> Void)?

    func start() throws {
        let desc = CATapDescription(stereoGlobalTapButExcludeProcesses: [])
        desc.name = "Spectrum"
        desc.uuid = UUID()
        desc.muteBehavior = .unmuted   // ascoltiamo e basta: l'audio continua a sentirsi
        try check(AudioHardwareCreateProcessTap(desc, &tapID), "AudioHardwareCreateProcessTap")

        guard let outUID = Self.defaultOutputDeviceUID() else { throw MeterError.noOutputDevice }

        let aggregate: [String: Any] = [
            kAudioAggregateDeviceUIDKey: UUID().uuidString,
            kAudioAggregateDeviceNameKey: "Spectrum Tap",
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: outUID]],
            kAudioAggregateDeviceTapListKey: [[
                kAudioSubTapUIDKey: desc.uuid.uuidString,
                kAudioSubTapDriftCompensationKey: true,
                kAudioSubTapDriftCompensationQualityKey: kAudioAggregateDriftCompensationMediumQuality,
            ]],
            kAudioAggregateDeviceTapAutoStartKey: true,
        ]
        try check(
            AudioHardwareCreateAggregateDevice(aggregate as CFDictionary, &aggregateID),
            "AudioHardwareCreateAggregateDevice")

        sampleRate = Self.nominalSampleRate(of: aggregateID) ?? 48000

        var proc: AudioDeviceIOProcID?
        try check(
            AudioDeviceCreateIOProcIDWithBlock(&proc, aggregateID, ioQueue) { [weak self] _, inData, _, _, _ in
                self?.capture(inData)
            }, "AudioDeviceCreateIOProcIDWithBlock")
        ioProcID = proc

        try check(AudioDeviceStart(aggregateID, proc), "AudioDeviceStart")
    }

    func stop() {
        if let proc = ioProcID {
            AudioDeviceStop(aggregateID, proc)
            AudioDeviceDestroyIOProcID(aggregateID, proc)
            ioProcID = nil
        }
        if aggregateID != AudioObjectID(kAudioObjectUnknown) {
            AudioHardwareDestroyAggregateDevice(aggregateID)
            aggregateID = AudioObjectID(kAudioObjectUnknown)
        }
        if tapID != AudioObjectID(kAudioObjectUnknown) {
            AudioHardwareDestroyProcessTap(tapID)
            tapID = AudioObjectID(kAudioObjectUnknown)
        }
    }

    /// Gli ultimi `count` campioni (mix a una traccia), in ordine temporale.
    func latestSamples(count: Int) -> [Float] {
        ringLock.lock()
        defer { ringLock.unlock() }
        let n = min(count, ringCapacity)
        var out = [Float](repeating: 0, count: n)
        var index = (ringWrite - n + ringCapacity) % ringCapacity
        for i in 0..<n {
            out[i] = ring[index]
            index = (index + 1) % ringCapacity
        }
        return out
    }

    // MARK: - scrittura dal thread audio

    private func capture(_ list: UnsafePointer<AudioBufferList>) {
        callbackCount += 1
        let abl = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: list))
        var bufferPeak: Float = 0
        ringLock.lock()
        for buf in abl {
            guard let raw = buf.mData else { continue }
            let frames = Int(buf.mDataByteSize) / MemoryLayout<Float>.size
            let channels = max(1, Int(buf.mNumberChannels))
            let samples = raw.assumingMemoryBound(to: Float.self)
            var localPeak: Float = 0
            vDSP_maxmgv(samples, 1, &localPeak, vDSP_Length(frames))
            if localPeak > bufferPeak { bufferPeak = localPeak }
            // mix a una traccia: la media dei canali è più stabile del solo primo canale
            let perChannel = frames / channels
            for i in 0..<perChannel {
                var sum: Float = 0
                for c in 0..<channels { sum += samples[i * channels + c] }
                ring[ringWrite] = sum / Float(channels)
                ringWrite = (ringWrite + 1) % ringCapacity
            }
        }
        ringLock.unlock()
        if bufferPeak > 0.002 { onSignal?(bufferPeak) }
    }

    // MARK: - utilità CoreAudio

    private static func nominalSampleRate(of device: AudioObjectID) -> Double? {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyNominalSampleRate,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var rate: Float64 = 0
        var size = UInt32(MemoryLayout<Float64>.size)
        guard AudioObjectGetPropertyData(device, &addr, 0, nil, &size, &rate) == noErr, rate > 0 else { return nil }
        return rate
    }

    private static func defaultOutputDeviceUID() -> String? {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var dev = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &dev) == noErr,
            dev != AudioObjectID(kAudioObjectUnknown)
        else { return nil }

        var uidAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var uid: Unmanaged<CFString>?
        var uidSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(dev, &uidAddr, 0, nil, &uidSize, &uid) == noErr,
              let cf = uid
        else { return nil }
        return cf.takeRetainedValue() as String
    }

    private func check(_ status: OSStatus, _ what: String) throws {
        guard status == noErr else { throw MeterError.status(status, what) }
    }
}
