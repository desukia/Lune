//
//  M3WavyProgressIndicator.swift
//  Lune
//
//  Authentic Material 3 Expressive WavySlider matching Android Lune 1:1:
//  - waveLength = 36.dp
//  - waveHeight = 6.dp (amplitude = 3.dp, peak-to-peak 6.dp)
//  - waveVelocity = 38.dp to TAIL (cycle duration = 36.0 / 38.0 ≈ 0.947s, phase shift towards x = 0)
//  - waveThickness = 4.dp
//  - trackThickness = 4.dp
//  - incremental = false (uniform wave across active track)
//  - Continuous frame-driven TimelineView animation (never freezes, always in sync)
//  - Rotating 14x14 squircle thumb (360 deg in 2.0s when playing, cornerRadius 5.dp) locked to track end
//

import SwiftUI

public struct M3WavyProgressIndicator: View {
    @Binding var progress: Double // 0.0 ... 1.0
    let isPlaying: Bool
    let isWavy: Bool
    let primaryColor: Color
    let trackColor: Color
    let onSeek: (Double) -> Void
    
    @State private var isDragging: Bool = false
    @State private var dragProgress: Double = 0.0
    
    // Exact specs requested from Android Lune WavySlider:
    private let waveLength: CGFloat = 36.0
    private let waveHeight: CGFloat = 6.0
    private var waveAmplitude: CGFloat { waveHeight / 2.0 } // 3.0dp
    private let waveThickness: CGFloat = 4.0
    private let trackThickness: CGFloat = 4.0
    private let waveVelocity: CGFloat = 38.0 // 38.dp/s
    private var cycleDuration: Double { Double(waveLength / waveVelocity) } // ~0.947s
    
    public init(
        progress: Binding<Double>,
        isPlaying: Bool,
        isWavy: Bool = true,
        primaryColor: Color = .white,
        trackColor: Color = Color.white.opacity(0.24),
        onSeek: @escaping (Double) -> Void
    ) {
        self._progress = progress
        self.isPlaying = isPlaying
        self.isWavy = isWavy
        self.primaryColor = primaryColor
        self.trackColor = trackColor
        self.onSeek = onSeek
    }
    
    public var body: some View {
        TimelineView(.animation(paused: !isPlaying || !isWavy || isDragging)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let phase = isPlaying ? (time.truncatingRemainder(dividingBy: cycleDuration) / cycleDuration) * 2 * .pi : 0.0
            let thumbRotation = isPlaying ? (time.truncatingRemainder(dividingBy: 2.0) / 2.0) * 360.0 : 0.0
            
            GeometryReader { geometry in
                let width = geometry.size.width
                let height = geometry.size.height
                let centerY = height / 2.0
                let current = isDragging ? dragProgress : progress
                let activeWidth = max(0.0, min(width, width * CGFloat(current)))
                let effectiveAmplitude: CGFloat = (isPlaying && isWavy && !isDragging) ? waveAmplitude : 0.0
                
                ZStack(alignment: .leading) {
                    // 1. Inactive Background Track (Full Width, height = 4.dp)
                    Capsule()
                        .fill(trackColor)
                        .frame(width: width, height: trackThickness)
                    
                    // 2. Active Wave / Track (height = 4.dp, incremental = false)
                    if activeWidth > 0 {
                        if effectiveAmplitude > 0.05 && activeWidth > 12 {
                            M3WavySineShape(
                                phase: phase,
                                amplitude: effectiveAmplitude,
                                wavelength: waveLength,
                                endX: activeWidth,
                                centerY: centerY
                            )
                            .stroke(
                                primaryColor,
                                style: StrokeStyle(lineWidth: waveThickness, lineCap: .round, lineJoin: .round)
                            )
                        } else {
                            Capsule()
                                .fill(primaryColor)
                                .frame(width: max(activeWidth, waveThickness), height: waveThickness)
                        }
                    }
                    
                    // 3. Scrubber Thumb (14x14 squircle, 1:1 Android Lune Parity)
                    // Locked permanently to activeWidth center
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(primaryColor)
                        .frame(width: 14, height: 14)
                        .rotationEffect(.degrees(isPlaying ? thumbRotation : 0))
                        .shadow(color: Color.black.opacity(0.35), radius: 1.5, x: 0, y: 1)
                        .offset(x: activeWidth - 7)
                }
                .frame(width: width, height: height, alignment: .leading)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !isDragging {
                                isDragging = true
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }
                            guard width > 0 else { return }
                            let clampedX = max(0.0, min(Double(width), Double(value.location.x)))
                            let newProgress = clampedX / Double(width)
                            dragProgress = newProgress
                            progress = newProgress
                        }
                        .onEnded { value in
                            guard width > 0 else { return }
                            let clampedX = max(0.0, min(Double(width), Double(value.location.x)))
                            let finalProgress = clampedX / Double(width)
                            isDragging = false
                            dragProgress = finalProgress
                            progress = finalProgress
                            onSeek(finalProgress)
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        }
                )
            }
        }
        .frame(height: 32)
    }
}

// MARK: - Mathematical Sine Wave Shape (Propagates towards TAIL)
private struct M3WavySineShape: Shape {
    var phase: Double
    var amplitude: CGFloat
    var wavelength: CGFloat
    var endX: CGFloat
    var centerY: CGFloat
    
    var animatableData: AnimatablePair<Double, CGFloat> {
        get { AnimatablePair(phase, amplitude) }
        set {
            phase = newValue.first
            amplitude = newValue.second
        }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard endX > 0 else { return path }
        
        path.move(to: CGPoint(x: 0, y: centerY))
        
        let step: CGFloat = 2.0
        var x: CGFloat = 0.0
        while x <= endX {
            let relativeX = x / wavelength
            // incremental = false: uniform amplitude across active width, smoothly tapering at start and end
            let startTaper = max(0.0, min(1.0, x / 10.0))
            let endTaper = max(0.0, min(1.0, (endX - x) / 14.0))
            let currentAmp = amplitude * startTaper * endTaper
            // + phase: wave crest travels towards TAIL (x = 0) with velocity 38dp/s
            let y = centerY + sin(relativeX * 2 * .pi + phase) * currentAmp
            path.addLine(to: CGPoint(x: x, y: y))
            x += step
        }
        
        // Ensure path lands directly at (endX, centerY) at the thumb center
        path.addLine(to: CGPoint(x: endX, y: centerY))
        
        return path
    }
}
