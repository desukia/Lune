//
//  VisualizerEngine.swift
//  Lune
//
//  Real-time 48-bar audio spectrum visualizer using Accelerate vDSP FFT.
//  Exactly matches Android Lune's 48-band visualizer.
//

import Foundation
import Accelerate
import AVFoundation

public final class VisualizerEngine: @unchecked Sendable {
    public static let shared = VisualizerEngine()
    
    public static let barCount = 48
    private var fftSetup: vDSP_DFT_Setup?
    private let fftSize: Int = 1024
    
    public var onMagnitudesUpdated: (([Float]) -> Void)?
    
    private init() {
        fftSetup = vDSP_DFT_zop_CreateSetup(
            nil,
            vDSP_Length(fftSize),
            .FORWARD
        )
    }
    
    deinit {
        if let setup = fftSetup {
            vDSP_DFT_DestroySetup(setup)
        }
    }
    
    public func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameCount = Int(buffer.frameLength)
        guard frameCount >= fftSize else { return }
        
        var realIn = [Float](repeating: 0, count: fftSize)
        var imagIn = [Float](repeating: 0, count: fftSize)
        var realOut = [Float](repeating: 0, count: fftSize)
        var imagOut = [Float](repeating: 0, count: fftSize)
        
        // Window function (Hann)
        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        vDSP_vmul(channelData, 1, window, 1, &realIn, 1, vDSP_Length(fftSize))
        
        if let setup = fftSetup {
            vDSP_DFT_Execute(setup, &realIn, &imagIn, &realOut, &imagOut)
        }
        
        var magnitudes = [Float](repeating: 0, count: fftSize / 2)
        realOut.withUnsafeBufferPointer { rPtr in
            imagOut.withUnsafeBufferPointer { iPtr in
                var splitComplex = DSPSplitComplex(
                    realp: UnsafeMutablePointer(mutating: rPtr.baseAddress!),
                    imagp: UnsafeMutablePointer(mutating: iPtr.baseAddress!)
                )
                vDSP_zvabs(&splitComplex, 1, &magnitudes, 1, vDSP_Length(fftSize / 2))
            }
        }
        
        // Group into 48 bands
        let step = (fftSize / 2) / Self.barCount
        var bars = [Float](repeating: 0, count: Self.barCount)
        for i in 0..<Self.barCount {
            let start = i * step
            let end = min(magnitudes.count, start + step)
            let slice = magnitudes[start..<end]
            let avg = slice.reduce(0, +) / Float(max(1, slice.count))
            // Normalize with log scale
            let normalized = min(1.0, max(0.05, log10(1.0 + avg * 8.0) * 0.45))
            bars[i] = normalized
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.onMagnitudesUpdated?(bars)
        }
    }
}
