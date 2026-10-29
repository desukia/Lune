//
//  M3WavyProgressIndicator.swift
//  Lune
//
//  Authentic Material 3 Expressive LinearWavyProgressIndicator:
//  - Smooth mathematical sine wave progress indicator
//  - Animated phase shift when playing
//  - Drag and tap interactive scrubbing
//  - Amplitude morphing between active sine wave and resting flat bar
//

import SwiftUI

public struct M3WavyProgressIndicator: View {
    @Binding var progress: Double // 0.0 ... 1.0
    let isPlaying: Bool
    let isWavy: Bool
    let primaryColor: Color
    let trackColor: Color
    let onSeek: (Double) -> Void
    
    @State private var phase: Double = 0.0
    @State private var thumbRotation: Double = 0.0
    @State private var isDragging: Bool = false
    @State private var dragProgress: Double = 0.0
    
    private let waveAmplitude: CGFloat = 3.5
    private let waveLength: CGFloat = 28.0
    private let strokeWidth: CGFloat = 4.0
    
    public init(
        progress: Binding<Double>,
        isPlaying: Bool,
        isWavy: Bool = true,
        primaryColor: Color,
        trackColor: Color = Color.white.opacity(0.25),
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
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let current = isDragging ? dragProgress : progress
            let activeWidth = max(0, min(width, width * CGFloat(current)))
            let centerY = height / 2
            
            ZStack(alignment: .leading) {
                // Background Track (Visible across full width)
                Capsule()
                    .fill(trackColor)
                    .frame(height: strokeWidth)
                    .position(x: width / 2, y: centerY)
                
                // Played Wave / Bar
                if isWavy && isPlaying && !isDragging && activeWidth > 10 {
                    M3WavySineShape(
                        phase: phase,
                        amplitude: waveAmplitude,
                        wavelength: waveLength,
                        endX: activeWidth,
                        centerY: centerY
                    )
                    .stroke(
                        primaryColor,
                        style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)
                    )
                } else {
                    Capsule()
                        .fill(primaryColor)
                        .frame(width: max(activeWidth, strokeWidth), height: strokeWidth)
                        .position(x: max(activeWidth, strokeWidth) / 2, y: centerY)
                }
                
                // Scrubber Thumb (Android Lune 1:1 Parity: 14x14 squircle rotating 360 deg when playing)
                RoundedRectangle(cornerRadius: isDragging ? 7 : 5, style: .continuous)
                    .fill(primaryColor)
                    .frame(width: isDragging ? 18 : 14, height: isDragging ? 18 : 14)
                    .rotationEffect(.degrees(isPlaying ? thumbRotation : 0))
                    .shadow(color: Color.black.opacity(0.35), radius: isDragging ? 4 : 2, x: 0, y: 1)
                    .position(x: activeWidth, y: centerY)
                    .scaleEffect(isDragging ? 1.25 : 1.0)
                    .animation(.spring(response: 0.25, dampingFraction: 0.65), value: isDragging)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                        let newProgress = max(0.0, min(1.0, Double(value.location.x / width)))
                        dragProgress = newProgress
                    }
                    .onEnded { value in
                        let finalProgress = max(0.0, min(1.0, Double(value.location.x / width)))
                        isDragging = false
                        onSeek(finalProgress)
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
            )
        }
        .frame(height: 24)
        .onAppear {
            if isPlaying && isWavy {
                startWaveAnimation()
            }
        }
        .onChange(of: isPlaying) { _, playing in
            if playing && isWavy {
                startWaveAnimation()
            }
        }
    }
    
    private func startWaveAnimation() {
        withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
            phase = .pi * 2
        }
        withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
            thumbRotation = 360
        }
    }
}

// MARK: - Mathematical Sine Wave Shape
private struct M3WavySineShape: Shape {
    var phase: Double
    var amplitude: CGFloat
    var wavelength: CGFloat
    var endX: CGFloat
    var centerY: CGFloat
    
    var animatableData: Double {
        get { phase }
        set { phase = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard endX > 0 else { return path }
        
        path.move(to: CGPoint(x: 0, y: centerY))
        
        let step: CGFloat = 2.0
        var x: CGFloat = 0.0
        while x <= endX {
            let relativeX = x / wavelength
            // Smoothly taper amplitude to 0 over the last 14pt so wave enters thumb center seamlessly
            let endTaper = max(0.0, min(1.0, (endX - x) / 14.0))
            let currentAmp = amplitude * endTaper
            let y = centerY + sin(relativeX * 2 * .pi - phase) * currentAmp
            path.addLine(to: CGPoint(x: x, y: y))
            x += step
        }
        
        // Ensure path reaches exact endX directly at centerY
        path.addLine(to: CGPoint(x: endX, y: centerY))
        
        return path
    }
}
