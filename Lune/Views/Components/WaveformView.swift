//
//  WaveformView.swift
//  Lune
//
//  Real-time 48-bar visualizer and interactive Wavy progress bar matching Android Lune.
//

import SwiftUI

@MainActor
public struct VisualizerBarView: View {
    let bars: [Float]
    let color: Color
    
    public init(bars: [Float], color: Color = Color(hex: 0xD0BCFF)) {
        self.bars = bars
        self.color = color
    }
    
    public var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<min(48, bars.count), id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.9), color.opacity(0.4)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: max(4, CGFloat(bars[i]) * 45))
                    .animation(.easeOut(duration: 0.12), value: bars[i])
            }
        }
        .frame(height: 50)
    }
}

@MainActor
public struct WaveProgressBar: View {
    @Binding var progress: Float
    let isWavy: Bool
    let activeColor: Color
    let onSeek: (Float) -> Void
    
    @State private var isDragging: Bool = false
    @State private var dragProgress: Float = 0
    
    public init(
        progress: Binding<Float>,
        isWavy: Bool = true,
        activeColor: Color = Color(hex: 0xD0BCFF),
        onSeek: @escaping (Float) -> Void
    ) {
        self._progress = progress
        self.isWavy = isWavy
        self.activeColor = activeColor
        self.onSeek = onSeek
    }
    
    public var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let current = isDragging ? dragProgress : progress
            let activeWidth = width * CGFloat(max(0, min(1, current)))
            
            ZStack(alignment: .leading) {
                // Background Track
                Capsule()
                    .fill(Color.white.opacity(0.18))
                    .frame(height: 5)
                
                // Active Fill Track
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [activeColor.opacity(0.85), activeColor],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(5, activeWidth), height: 5)
                
                // Scrub Thumb Knob
                Circle()
                    .fill(Color.white)
                    .frame(width: isDragging ? 16 : 12, height: isDragging ? 16 : 12)
                    .shadow(color: Color.black.opacity(0.35), radius: 3, x: 0, y: 1)
                    .offset(x: max(0, min(width - (isDragging ? 16 : 12), activeWidth - (isDragging ? 8 : 6))))
                    .animation(.spring(response: 0.25, dampingFraction: 0.70), value: isDragging)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        let pct = Float(max(0, min(1, value.location.x / width)))
                        dragProgress = pct
                    }
                    .onEnded { value in
                        let pct = Float(max(0, min(1, value.location.x / width)))
                        dragProgress = pct
                        isDragging = false
                        onSeek(pct)
                    }
            )
        }
        .frame(height: 24)
    }
}

// Sine wave stroke shape for progress
struct WavyShape: Shape {
    var progress: CGFloat
    
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard rect.width > 0 else { return path }
        
        let midY = rect.midY
        let wavelength: CGFloat = 16.0
        let amplitude: CGFloat = 3.5
        
        path.move(to: CGPoint(x: 0, y: midY))
        for x in stride(from: 0, through: rect.width, by: 2) {
            let relativeX = x / wavelength
            let y = midY + sin(relativeX * 2 * .pi) * amplitude
            path.addLine(to: CGPoint(x: x, y: y))
        }
        return path
    }
}
