//
//  VisualizerEngine.swift
//  Lune
//
//  Real-time 48-bar audio spectrum visualizer using Accelerate vDSP FFT.
//  Exactly matches Android Lune's 48-band visualizer with pre-allocated zero-allocation buffers.
//

import Foundation
import Accelerate
import AVFoundation

public final class VisualizerEngine: @unchecked Sendable {
    public static let shared = VisualizerEngine()
    
    public static let barCount = 48
    private var fftSetup: vDSP_DFT_Setup?
    private let fftSize: Int = 1024
    
    // Pre-allocated buffers to prevent ~43 heap allocations per second
    private var realIn: [Float]
    private var imagIn: [Float]
    private var realOut: [Float]
    private var imagOut: [Float]
    private var window: [Float]
    private var magnitudes: [Float]
    private var bars: [Float]
    
    private var lastUpdateTime: Double = 0
    private let minUpdateInterval: Double = 1.0 / 25.0 // Cap at 25 fps to save battery and main thread cycles
    private let lock = NSLock()
    
    public var onMagnitudesUpdated: (([Float]) -> Void)?
    
    private init() {
        fftSetup = vDSP_DFT_zop_CreateSetup(
            nil,
            vDSP_Length(fftSize),
            .FORWARD
        )
        
        realIn = [Float](repeating: 0, count: fftSize)
        imagIn = [Float](repeating: 0, count: fftSize)
        realOut = [Float](repeating: 0, count: fftSize)
        imagOut = [Float](repeating: 0, count: fftSize)
        window = [Float](repeating: 0, count: fftSize)
        magnitudes = [Float](repeating: 0, count: fftSize / 2)
        bars = [Float](repeating: 0.1, count: Self.barCount)
        
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
    }
    
    deinit {
        if let setup = fftSetup {
            vDSP_DFT_DestroySetup(setup)
        }
    }
    
    public func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        // Only run FFT if someone is actively listening to the callback
        guard onMagnitudesUpdated != nil else { return }
        
        let now = CACurrentMediaTime()
        guard (now - lastUpdateTime) >= minUpdateInterval else { return }
        lastUpdateTime = now
        
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameCount = Int(buffer.frameLength)
        guard frameCount >= fftSize else { return }
        
        lock.lock()
        defer { lock.unlock() }
        
        // Window function (Hann) using pre-calculated window
        vDSP_vmul(channelData, 1, window, 1, &realIn, 1, vDSP_Length(fftSize))
        imagIn.withUnsafeMutableBufferPointer { $0.initialize(repeating: 0) }
        
        if let setup = fftSetup {
            vDSP_DFT_Execute(setup, &realIn, &imagIn, &realOut, &imagOut)
        }
        
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
        for i in 0..<Self.barCount {
            let start = i * step
            let end = min(magnitudes.count, start + step)
            let count = max(1, end - start)
            var sum: Float = 0
            for j in start..<end {
                sum += magnitudes[j]
            }
            let avg = sum / Float(count)
            // Normalize with log scale
            let normalized = min(1.0, max(0.05, log10(1.0 + avg * 8.0) * 0.45))
            bars[i] = normalized
        }
        
        let currentBars = bars
        DispatchQueue.main.async { [weak self] in
            self?.onMagnitudesUpdated?(currentBars)
        }
    }
}
