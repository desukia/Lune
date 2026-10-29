//
//  EqualizerEngine.swift
//  Lune
//
//  10-band Equalizer, Reverb, Pitch, Speed, and Bass Boost using AVAudioEngine.
//

import AVFoundation
import SwiftUI

public enum ReverbPresetType: String, CaseIterable, Identifiable, Codable {
    case off = "Off"
    case smallRoom = "Small Room"
    case mediumRoom = "Medium Room"
    case largeRoom = "Large Room"
    case mediumHall = "Medium Hall"
    case largeHall = "Large Hall"
    case plate = "Plate"
    
    public var id: String { rawValue }
    
    public var avPreset: AVAudioUnitReverbPreset? {
        switch self {
        case .off: return nil
        case .smallRoom: return .smallRoom
        case .mediumRoom: return .mediumRoom
        case .largeRoom: return .largeRoom
        case .mediumHall: return .mediumHall
        case .largeHall: return .largeHall
        case .plate: return .plate
        }
    }
}

public struct EqPreset: Identifiable, Hashable {
    public let id: String
    public let name: String
    public let gains: [Float] // 10 bands (-12 to +12 dB)
    
    public init(name: String, gains: [Float]) {
        self.id = name
        self.name = name
        self.gains = gains
    }
    
    public static let presets: [EqPreset] = [
        EqPreset(name: "Flat", gains: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
        EqPreset(name: "Bass Boost", gains: [6, 5, 4, 2, 0, 0, 0, 0, 0, 0]),
        EqPreset(name: "Rock", gains: [4, 3, -1, -2, 0, 2, 4, 5, 5, 4]),
        EqPreset(name: "Pop", gains: [-1, 1, 3, 4, 3, 0, -1, 1, 3, 3]),
        EqPreset(name: "Jazz", gains: [3, 2, 1, 2, -1, -1, 0, 1, 2, 3]),
        EqPreset(name: "Electronic", gains: [5, 4, 1, 0, -2, 2, 1, 2, 4, 4]),
        EqPreset(name: "Vocal", gains: [-2, -1, -1, 2, 4, 4, 3, 1, 0, -1]),
        EqPreset(name: "Acoustic", gains: [3, 2, 1, 1, 1, 2, 3, 3, 3, 2]),
        EqPreset(name: "Classical", gains: [4, 3, 2, 1, -1, -1, 0, 2, 3, 3]),
        EqPreset(name: "Deep", gains: [5, 4, 2, 1, 0, -1, -2, -1, 1, 2])
    ]
}

public final class EqualizerEngine: @unchecked Sendable {
    public static let shared = EqualizerEngine()
    
    public let frequencies: [Float] = [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
    public let eqUnit = AVAudioUnitEQ(numberOfBands: 10)
    public let reverbUnit = AVAudioUnitReverb()
    public let timePitchUnit = AVAudioUnitTimePitch()
    
    private init() {
        setupBands()
    }
    
    private func setupBands() {
        for (i, freq) in frequencies.enumerated() {
            let band = eqUnit.bands[i]
            band.frequency = freq
            band.bandwidth = 1.0
            band.bypass = false
            band.filterType = .parametric
            band.gain = 0.0
        }
        eqUnit.bypass = false
        reverbUnit.bypass = true
        timePitchUnit.bypass = false
    }
    
    public func setBandGain(index: Int, gain: Float) {
        guard index >= 0 && index < eqUnit.bands.count else { return }
        eqUnit.bands[index].gain = max(-12.0, min(12.0, gain))
    }
    
    public func applyPreset(_ preset: EqPreset) {
        for (i, gain) in preset.gains.enumerated() {
            setBandGain(index: i, gain: gain)
        }
    }
    
    public func setReverbPreset(_ preset: ReverbPresetType, blend: Float = 40.0) {
        if let av = preset.avPreset {
            reverbUnit.loadFactoryPreset(av)
            reverbUnit.wetDryMix = blend
            reverbUnit.bypass = false
        } else {
            reverbUnit.bypass = true
        }
    }
    
    public func setPitch(_ pitch: Float) { // -2400 to +2400 cents
        timePitchUnit.pitch = max(-2400, min(2400, pitch))
    }
    
    public func setSpeed(_ speed: Float) { // 0.5 to 2.0x
        timePitchUnit.rate = max(0.5, min(2.0, speed))
    }
    
    public func setBassBoost(_ boostDb: Float) {
        let gain = max(0, min(12.0, boostDb))
        eqUnit.bands[0].gain = gain
        eqUnit.bands[1].gain = gain * 0.75
    }
}
