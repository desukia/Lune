//
//  GlassComponents.swift
//  Lune
//
//  Reusable Liquid Glass components: Cards, Pills, Icon Buttons, Badges.
//

import SwiftUI

public struct GlassCard<Content: View>: View {
    let cornerRadius: CGFloat
    let variant: LiquidGlassVariant
    let content: Content
    
    public init(
        cornerRadius: CGFloat = 20,
        variant: LiquidGlassVariant = .regular,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.variant = variant
        self.content = content()
    }
    
    public var body: some View {
        content
            .padding()
            .liquidGlass(
                variant,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
    }
}

public struct GlassPill<Content: View>: View {
    let variant: LiquidGlassVariant
    let content: Content
    
    public init(
        variant: LiquidGlassVariant = .regular,
        @ViewBuilder content: () -> Content
    ) {
        self.variant = variant
        self.content = content()
    }
    
    public var body: some View {
        content
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .liquidGlass(
                variant,
                in: Capsule(style: .continuous)
            )
    }
}

@MainActor
public struct GlassCircleButton: View {
    let systemName: String
    let size: CGFloat
    let iconSize: CGFloat
    let isProminent: Bool
    let tint: Color?
    let action: () -> Void
    
    public init(
        systemName: String,
        size: CGFloat = 48,
        iconSize: CGFloat = 20,
        isProminent: Bool = false,
        tint: Color? = nil,
        action: @escaping () -> Void
    ) {
        self.systemName = systemName
        self.size = size
        self.iconSize = iconSize
        self.isProminent = isProminent
        self.tint = tint
        self.action = action
    }
    
    public var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: iconSize, weight: .bold))
                .foregroundColor(tint ?? (isProminent ? .white : .primary))
                .frame(width: size, height: size)
                .liquidGlass(
                    isProminent ? (tint != nil ? .tinted(tint!, opacity: 0.8) : .prominent) : .regular,
                    in: Circle(),
                    interactive: true
                )
        }
        .buttonStyle(.plain)
    }
}

@MainActor
public struct ArtworkPlaceholderView: View {
    let size: CGFloat
    let cornerRadius: CGFloat
    
    public init(size: CGFloat = 50, cornerRadius: CGFloat = 12) {
        self.size = size
        self.cornerRadius = cornerRadius
    }
    
    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0x554492), Color(hex: 0x2A204D)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
            
            Image(systemName: "music.note")
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundColor(.white.opacity(0.85))
        }
    }
}

@MainActor
public struct HiFiBadge: View {
    let isHiRes: Bool
    
    public init(isHiRes: Bool = false) {
        self.isHiRes = isHiRes
    }
    
    public var body: some View {
        Text(isHiRes ? "HI-RES" : "HI-FI")
            .font(.custom("Quicksand-Bold", size: 9))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: isHiRes ? [Color(hex: 0xF59E0B), Color(hex: 0xEF4444)] : [Color(hex: 0x6366F1), Color(hex: 0x8B5CF6)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .overlay(
                Capsule().stroke(Color.white.opacity(0.4), lineWidth: 0.5)
            )
    }
}

// MARK: - M3 Expressive Flower Shape (Material 3 9-sided Cookie Shape)
public struct M3FlowerShape: Shape {
    public var petals: Int = 9
    public var depth: CGFloat = 0.12
    
    public init(petals: Int = 9, depth: CGFloat = 0.12) {
        self.petals = petals
        self.depth = depth
    }
    
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let maxRadius = min(rect.width, rect.height) / 2.0
        let baseRadius = maxRadius * (1.0 - depth)
        let amp = maxRadius * depth
        let stepCount = petals * 16
        
        for i in 0..<stepCount {
            let theta = (CGFloat(i) / CGFloat(stepCount)) * 2 * .pi - (.pi / 2)
            let r = baseRadius + amp * cos(CGFloat(petals) * theta)
            let x = center.x + r * cos(theta)
            let y = center.y + r * sin(theta)
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - Scallop Play/Pause Button with Circular Progress Ring (1:1 Android Lune Parity)
public struct ScallopPlayPauseButtonWithProgress: View {
    public let isPlaying: Bool
    public let progress: Float
    public let primaryColor: Color
    public let size: CGFloat
    public let onClick: () -> Void
    
    public init(
        isPlaying: Bool,
        progress: Float,
        primaryColor: Color = Color(hex: 0xD0BCFF),
        size: CGFloat = 48,
        onClick: @escaping () -> Void
    ) {
        self.isPlaying = isPlaying
        self.progress = progress
        self.primaryColor = primaryColor
        self.size = size
        self.onClick = onClick
    }
    
    public var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onClick()
        } label: {
            ZStack {
                // Background track ring
                Circle()
                    .stroke(primaryColor.opacity(0.24), lineWidth: 3.5)
                
                // Active progress arc
                Circle()
                    .trim(from: 0, to: CGFloat(max(0, min(1, progress))))
                    .stroke(primaryColor, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.25), value: progress)
                
                // Transparent center with icons (no solid background)
                if isPlaying {
                    HStack(spacing: 4) {
                        Capsule()
                            .fill(primaryColor)
                            .frame(width: 4, height: 16)
                        Capsule()
                            .fill(primaryColor)
                            .frame(width: 4, height: 16)
                    }
                } else {
                    Image(systemName: "play.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(primaryColor)
                        .offset(x: 1.5)
                }
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
    }
}



// MARK: - Lune Animated Logo (1:1 Android AnimatedLogo Parity)
public struct LuneAnimatedLogo: View {
    public let isPlaying: Bool
    public let tintColor: Color
    public var size: CGFloat
    
    public init(isPlaying: Bool, tintColor: Color = .white, size: CGFloat = 42) {
        self.isPlaying = isPlaying
        self.tintColor = tintColor
        self.size = size
    }
    
    public var body: some View {
        TimelineView(.animation(paused: !isPlaying)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let rotation = isPlaying ? (time.truncatingRemainder(dividingBy: 2.0) / 2.0) * 360.0 : 0.0
            
            ZStack {
                LuneLogoDiamondsShape()
                    .fill(tintColor.opacity(0.35))
                    .rotationEffect(.degrees(rotation))
                
                LuneLogoNoteShape()
                    .fill(tintColor)
            }
            .frame(width: size, height: size)
        }
    }
}



public struct LuneLogoDiamondsShape: Shape {
    public init() {}
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let designDiameter: CGFloat = 69.0
        let scale = min(rect.width, rect.height) / designDiameter
        let cx = rect.midX
        let cy = rect.midY
        func pt(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: cx + CGFloat(x - 54.0) * scale, y: cy + CGFloat(y - 54.0) * scale)
        }
        var curX: Double = 0
        var curY: Double = 0
        curX = 55.99; curY = 20.3
        path.move(to: pt(curX, curY))
        path.addCurve(to: pt(curX + 2.56, curY + 1.18), control1: pt(curX + 0.84, curY + 0.21), control2: pt(curX + 1.88, curY + 0.69))
        curX += 2.56; curY += 1.18
        path.addCurve(to: pt(curX + 2.6, curY + 2.45), control1: pt(curX + 0.23, curY + 0.17), control2: pt(curX + 1.41, curY + 1.27))
        curX += 2.6; curY += 2.45
        path.addCurve(to: pt(curX + 5.11, curY + 3.62), control1: pt(curX + 2.66, curY + 2.63), control2: pt(curX + 3.39, curY + 3.14))
        curX += 5.11; curY += 3.62
        path.addCurve(to: pt(curX + 4.27, curY + 0.23), control1: pt(curX + 0.63, curY + 0.17), control2: pt(curX + 0.91, curY + 0.18))
        curX += 4.27; curY += 0.23
        path.addCurve(to: pt(curX + 4.34, curY + 0.28), control1: pt(curX + 3.6, curY + 0.05), control2: pt(curX + 3.6, curY + 0.05))
        curX += 4.34; curY += 0.28
        path.addCurve(to: pt(curX + 5.28, curY + 5.23), control1: pt(curX + 2.63, curY + 0.8), control2: pt(curX + 4.46, curY + 2.62))
        curX += 5.28; curY += 5.23
        path.addCurve(to: pt(curX + 0.36, curY + 4.29), control1: pt(curX + 0.32, curY + 1.02), control2: pt(curX + 0.41, curY + 2.12))
        curX += 0.36; curY += 4.29
        path.addCurve(to: pt(curX + 0.74, curY + 5.43), control1: pt(curX + -0.06, curY + 2.84), control2: pt(curX + 0.11, curY + 4.1))
        curX += 0.74; curY += 5.43
        path.addCurve(to: pt(curX + 2.98, curY + 3.66), control1: pt(curX + 0.51, curY + 1.08), control2: pt(curX + 0.88, curY + 1.53))
        curX += 2.98; curY += 3.66
        path.addCurve(to: pt(curX + 2.53, curY + 2.83), control1: pt(curX + 1.65, curY + 1.67), control2: pt(curX + 2.17, curY + 2.24))
        curX += 2.53; curY += 2.83
        path.addCurve(to: pt(curX + 0.08, curY + 8.65), control1: pt(curX + 1.61, curY + 2.56), control2: pt(curX + 1.64, curY + 5.96))
        curX += 0.08; curY += 8.65
        path.addCurve(to: pt(curX + -2.24, curY + 2.5), control1: pt(curX + -0.31, curY + 0.54), control2: pt(curX + -0.7, curY + 0.99))
        curX += -2.24; curY += 2.5
        path.addCurve(to: pt(curX + -3.22, curY + 3.76), control1: pt(curX + -2.24, curY + 2.24), control2: pt(curX + -2.79, curY + 2.87))
        curX += -3.22; curY += 3.76
        path.addCurve(to: pt(curX + -0.85, curY + 5.5), control1: pt(curX + -0.77, curY + 1.58), control2: pt(curX + -0.85, curY + 2.11))
        curX += -0.85; curY += 5.5
        path.addCurve(to: pt(curX + -0.39, curY + 4.72), control1: pt(curX + 0.0, curY + 2.93), control2: pt(curX + -0.06, curY + 3.65))
        curX += -0.39; curY += 4.72
        path.addCurve(to: pt(curX + -5.79, curY + 5.43), control1: pt(curX + -0.85, curY + 2.7), control2: pt(curX + -2.89, curY + 4.61))
        curX += -5.79; curY += 5.43
        path.addCurve(to: pt(curX + -3.83, curY + 0.18), control1: pt(curX + -0.61, curY + 0.17), control2: pt(curX + -0.83, curY + 0.18))
        curX += -3.83; curY += 0.18
        path.addCurve(to: pt(curX + -3.52, curY + 0.08), control1: pt(curX + -1.75, curY + -0.0), control2: pt(curX + -3.33, curY + 0.03))
        curX += -3.52; curY += 0.08
        path.addCurve(to: pt(curX + -3.13, curY + 1.28), control1: pt(curX + -1.2, curY + 0.24), control2: pt(curX + -2.3, curY + 0.7))
        curX += -3.13; curY += 1.28
        path.addCurve(to: pt(curX + -2.6, curY + 2.41), control1: pt(curX + -0.3, curY + 0.22), control2: pt(curX + -1.47, curY + 1.3))
        curX += -2.6; curY += 2.41
        path.addCurve(to: pt(curX + -2.6, curY + 2.4), control1: pt(curX + -1.13, curY + 1.11), control2: pt(curX + -2.29, curY + 2.19))
        curX += -2.6; curY += 2.4
        path.addCurve(to: pt(curX + -4.77, curY + 1.52), control1: pt(curX + -1.57, curY + 1.11), control2: pt(curX + -2.9, curY + 1.52))
        curX += -4.77; curY += 1.52
        path.addCurve(to: pt(curX + -4.52, curY + -1.47), control1: pt(curX + -1.69, curY + -0.01), control2: pt(curX + -2.96, curY + -0.42))
        curX += -4.52; curY += -1.47
        path.addCurve(to: pt(curX + -2.81, curY + -2.56), control1: pt(curX + -0.39, curY + -0.27), control2: pt(curX + -1.45, curY + -1.23))
        curX += -2.81; curY += -2.56
        path.addCurve(to: pt(curX + -4.25, curY + -3.2), control1: pt(curX + -2.4, curY + -2.35), control2: pt(curX + -2.9, curY + -2.73))
        curX += -4.25; curY += -3.2
        path.addCurve(to: pt(curX + -4.79, curY + -0.45), control1: pt(curX + -1.24, curY + -0.43), control2: pt(curX + -1.4, curY + -0.44))
        curX += -4.79; curY += -0.45
        path.addCurve(to: pt(curX + -3.99, curY + -0.23), control1: pt(curX + -3.17, curY + -0.01), control2: pt(curX + -3.18, curY + -0.01))
        curX += -3.99; curY += -0.23
        path.addCurve(to: pt(curX + -5.84, curY + -5.85), control1: pt(curX + -2.99, curY + -0.81), control2: pt(curX + -5.02, curY + -2.86))
        curX += -5.84; curY += -5.85
        path.addCurve(to: pt(curX + -0.23, curY + -3.89), control1: pt(curX + -0.22, curY + -0.78), control2: pt(curX + -0.22, curY + -0.85))
        curX += -0.23; curY += -3.89
        path.addCurve(to: pt(curX + -0.39, curY + -4.69), control1: pt(curX + -0.02, curY + -3.17), control2: pt(curX + -0.04, curY + -3.51))
        curX += -0.39; curY += -4.69
        path.addCurve(to: pt(curX + -3.25, curY + -4.44), control1: pt(curX + -0.42, curY + -1.43), control2: pt(curX + -0.94, curY + -2.14))
        curX += -3.25; curY += -4.44
        path.addCurve(to: pt(curX + -2.3, curY + -2.43), control1: pt(curX + -1.06, curY + -1.06), control2: pt(curX + -2.1, curY + -2.15))
        curX += -2.3; curY += -2.43
        path.addCurve(to: pt(curX + -1.04, curY + -7.77), control1: pt(curX + -1.58, curY + -2.22), control2: pt(curX + -1.99, curY + -5.26))
        curX += -1.04; curY += -7.77
        path.addCurve(to: pt(curX + 3.22, curY + -4.25), control1: pt(curX + 0.54, curY + -1.42), control2: pt(curX + 0.93, curY + -1.93))
        curX += 3.22; curY += -4.25
        path.addCurve(to: pt(curX + 2.36, curY + -2.51), control1: pt(curX + 1.16, curY + -1.17), control2: pt(curX + 2.22, curY + -2.3))
        curX += 2.36; curY += -2.51
        path.addCurve(to: pt(curX + 1.01, curY + -2.09), control1: pt(curX + 0.36, curY + -0.54), control2: pt(curX + 0.81, curY + -1.46))
        curX += 1.01; curY += -2.09
        path.addCurve(to: pt(curX + 0.39, curY + -4.61), control1: pt(curX + 0.34, curY + -1.06), control2: pt(curX + 0.38, curY + -1.52))
        curX += 0.39; curY += -4.61
        path.addCurve(to: pt(curX + 0.23, curY + -3.78), control1: pt(curX + 0.01, curY + -2.92), control2: pt(curX + 0.01, curY + -2.99))
        curX += 0.23; curY += -3.78
        path.addCurve(to: pt(curX + 4.77, curY + -5.43), control1: pt(curX + 0.71, curY + -2.62), control2: pt(curX + 2.41, curY + -4.56))
        curX += 4.77; curY += -5.43
        path.addCurve(to: pt(curX + 5.01, curY + -0.5), control1: pt(curX + 1.19, curY + -0.44), control2: pt(curX + 1.24, curY + -0.44))
        curX += 5.01; curY += -0.5
        path.addCurve(to: pt(curX + 5.5, curY + -0.7), control1: pt(curX + 3.96, curY + -0.06), control2: pt(curX + 4.2, curY + -0.09))
        curX += 5.5; curY += -0.7
        path.addCurve(to: pt(curX + 3.88, curY + -3.19), control1: pt(curX + 1.07, curY + -0.51), control2: pt(curX + 1.62, curY + -0.96))
        curX += 3.88; curY += -3.19
        path.addCurve(to: pt(curX + 2.7, curY + -2.5), control1: pt(curX + 1.22, curY + -1.2), control2: pt(curX + 2.44, curY + -2.33))
        curX += 2.7; curY += -2.5
        path.addCurve(to: pt(curX + 6.41, curY + -1.09), control1: pt(curX + 1.94, curY + -1.26), control2: pt(curX + 4.18, curY + -1.65))
        curX += 6.41; curY += -1.09
        path.closeSubpath()
        path.closeSubpath()
        return path
    }
}

public struct LuneLogoNoteShape: Shape {
    public init() {}
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let designDiameter: CGFloat = 69.0
        let scale = min(rect.width, rect.height) / designDiameter
        let cx = rect.midX
        let cy = rect.midY
        func pt(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: cx + CGFloat(x - 54.0) * scale, y: cy + CGFloat(y - 54.0) * scale)
        }
        var curX: Double = 0
        var curY: Double = 0
        curX = 50.96; curY = 35.88
        path.move(to: pt(curX, curY))
        path.addCurve(to: pt(curX + -10.04, curY + 5.9), control1: pt(curX + -3.94, curY + 0.81), control2: pt(curX + -7.48, curY + 2.89))
        curX += -10.04; curY += 5.9
        path.addCurve(to: pt(curX + -4.35, curY + 10.09), control1: pt(curX + -2.48, curY + 2.9), control2: pt(curX + -3.94, curY + 6.28))
        curX += -4.35; curY += 10.09
        path.addCurve(to: pt(curX + 0.13, curY + 4.56), control1: pt(curX + -0.12, curY + 1.12), control2: pt(curX + -0.05, curY + 3.45))
        curX += 0.13; curY += 4.56
        path.addCurve(to: pt(curX + 13.21, curY + 14.66), control1: pt(curX + 1.17, curY + 7.08), control2: pt(curX + 6.41, curY + 12.9))
        curX += 13.21; curY += 14.66
        path.addCurve(to: pt(curX + 4.66, curY + 0.54), control1: pt(curX + 1.87, curY + 0.49), control2: pt(curX + 2.35, curY + 0.54))
        curX += 4.66; curY += 0.54
        path.addCurve(to: pt(curX + 3.1, curY + -0.19), control1: pt(curX + 1.9, curY + -0.0), control2: pt(curX + 2.24, curY + -0.03))
        curX += 3.1; curY += -0.19
        path.addCurve(to: pt(curX + 9.29, curY + -4.75), control1: pt(curX + 3.62, curY + -0.73), control2: pt(curX + 6.68, curY + -2.29))
        curX += 9.29; curY += -4.75
        path.addCurve(to: pt(curX + 2.1, curY + -2.41), control1: pt(curX + 0.66, curY + -0.63), control2: pt(curX + 1.59, curY + -1.69))
        curX += 2.1; curY += -2.41
        curX += 0.35; curY += -0.49
        path.addLine(to: pt(curX, curY))
        curX += -0.87; curY += 0.44
        path.addLine(to: pt(curX, curY))
        path.addCurve(to: pt(curX + -10.53, curY + 0.99), control1: pt(curX + -3.34, curY + 1.68), control2: pt(curX + -6.98, curY + 2.03))
        curX += -10.53; curY += 0.99
        path.addCurve(to: pt(curX + -3.38, curY + -1.42), control1: pt(curX + -1.11, curY + -0.32), control2: pt(curX + -2.45, curY + -0.88))
        curX += -3.38; curY += -1.42
        path.addCurve(to: pt(curX + -0.76, curY + -0.39), control1: pt(curX + -0.41, curY + -0.23), control2: pt(curX + -0.75, curY + -0.41))
        curX += -0.76; curY += -0.39
        path.addCurve(to: pt(curX + -0.3, curY + 0.57), control1: pt(curX + -0.01, curY + 0.02), control2: pt(curX + -0.14, curY + 0.27))
        curX += -0.3; curY += 0.57
        path.addCurve(to: pt(curX + -1.04, curY + 1.31), control1: pt(curX + -0.18, curY + 0.36), control2: pt(curX + -0.53, curY + 0.8))
        curX += -1.04; curY += 1.31
        path.addCurve(to: pt(curX + -1.56, curY + 1.16), control1: pt(curX + -0.64, curY + 0.64), control2: pt(curX + -0.88, curY + 0.81))
        curX += -1.56; curY += 1.16
        path.addCurve(to: pt(curX + -3.93, curY + 0.6), control1: pt(curX + -1.31, curY + 0.64), control2: pt(curX + -2.6, curY + 0.85))
        curX += -3.93; curY += 0.6
        path.addCurve(to: pt(curX + -4.57, curY + -3.39), control1: pt(curX + -2.03, curY + -0.37), control2: pt(curX + -3.68, curY + -1.59))
        curX += -4.57; curY += -3.39
        path.addCurve(to: pt(curX + -0.57, curY + -2.56), control1: pt(curX + -0.42, curY + -0.86), control2: pt(curX + -0.57, curY + -1.52))
        curX += -0.57; curY += -2.56
        path.addCurve(to: pt(curX + 0.61, curY + -2.68), control1: pt(curX + 0.0, curY + -1.1), control2: pt(curX + 0.14, curY + -1.73))
        curX += 0.61; curY += -2.68
        path.addCurve(to: pt(curX + 3.61, curY + -3.1), control1: pt(curX + 0.7, curY + -1.42), control2: pt(curX + 2.12, curY + -2.64))
        curX += 3.61; curY += -3.1
        path.addCurve(to: pt(curX + 0.56, curY + -0.17), control1: pt(curX + 0.25, curY + -0.08), control2: pt(curX + 0.5, curY + -0.15))
        curX += 0.56; curY += -0.17
        path.addCurve(to: pt(curX + -0.14, curY + -0.67), control1: pt(curX + 0.07, curY + -0.03), control2: pt(curX + 0.03, curY + -0.23))
        curX += -0.14; curY += -0.67
        path.addCurve(to: pt(curX + -0.81, curY + -3.24), control1: pt(curX + -0.3, curY + -0.8), control2: pt(curX + -0.64, curY + -2.14))
        curX += -0.81; curY += -3.24
        path.addCurve(to: pt(curX + 0.01, curY + -4.88), control1: pt(curX + -0.19, curY + -1.2), control2: pt(curX + -0.19, curY + -3.75))
        curX += 0.01; curY += -4.88
        path.addCurve(to: pt(curX + 3.0, curY + -7.29), control1: pt(curX + 0.49, curY + -2.87), control2: pt(curX + 1.44, curY + -5.18))
        curX += 3.0; curY += -7.29
        path.addCurve(to: pt(curX + 3.17, curY + -3.22), control1: pt(curX + 0.95, curY + -1.28), control2: pt(curX + 1.62, curY + -1.97))
        curX += 3.17; curY += -3.22
        path.addCurve(to: pt(curX + -0.95, curY + 0.04), control1: pt(curX + 0.26, curY + -0.21), control2: pt(curX + 0.26, curY + -0.21))
        curX += -0.95; curY += 0.04
        path.closeSubpath()
        path.closeSubpath()
        curX = 65.64; curY = 41.19
        path.move(to: pt(curX, curY))
        path.addCurve(to: pt(curX + -6.74, curY + 1.42), control1: pt(curX + -0.16, curY + 0.05), control2: pt(curX + -3.19, curY + 0.69))
        curX += -6.74; curY += 1.42
        path.addCurve(to: pt(curX + -7.84, curY + 1.82), control1: pt(curX + -7.77, curY + 1.62), control2: pt(curX + -7.53, curY + 1.56))
        curX += -7.84; curY += 1.82
        path.addCurve(to: pt(curX + -0.49, curY + 6.77), control1: pt(curX + -0.52, curY + 0.44), control2: pt(curX + -0.49, curY + 0.12))
        curX += -0.49; curY += 6.77
        path.addCurve(to: pt(curX + -0.1, curY + 6.04), control1: pt(curX + 0.0, curY + 4.83), control2: pt(curX + -0.03, curY + 6.07))
        curX += -0.1; curY += 6.04
        path.addCurve(to: pt(curX + -2.14, curY + -0.54), control1: pt(curX + -1.06, curY + -0.47), control2: pt(curX + -1.21, curY + -0.5))
        curX += -2.14; curY += -0.54
        path.addCurve(to: pt(curX + -1.67, curY + 0.19), control1: pt(curX + -0.87, curY + -0.03), control2: pt(curX + -1.0, curY + -0.02))
        curX += -1.67; curY += 0.19
        path.addCurve(to: pt(curX + -3.12, curY + 4.15), control1: pt(curX + -1.94, curY + 0.64), control2: pt(curX + -3.12, curY + 2.19))
        curX += -3.12; curY += 4.15
        path.addCurve(to: pt(curX + 1.3, curY + 3.07), control1: pt(curX + 0.0, curY + 1.26), control2: pt(curX + 0.39, curY + 2.17))
        curX += 1.3; curY += 3.07
        path.addCurve(to: pt(curX + 3.56, curY + 1.35), control1: pt(curX + 1.0, curY + 0.98), control2: pt(curX + 2.19, curY + 1.43))
        curX += 3.56; curY += 1.35
        path.addCurve(to: pt(curX + 3.55, curY + -1.98), control1: pt(curX + 1.5, curY + -0.1), control2: pt(curX + 2.79, curY + -0.82))
        curX += 3.55; curY += -1.98
        path.addCurve(to: pt(curX + 0.8, curY + -7.65), control1: pt(curX + 0.79, curY + -1.2), control2: pt(curX + 0.8, curY + -1.35))
        curX += 0.8; curY += -7.65
        path.addCurve(to: pt(curX + 0.53, curY + -5.58), control1: pt(curX + 0.0, curY + -5.65), control2: pt(curX + -0.03, curY + -5.4))
        curX += 0.53; curY += -5.58
        path.addCurve(to: pt(curX + 11.31, curY + -2.38), control1: pt(curX + 0.23, curY + -0.08), control2: pt(curX + 9.77, curY + -2.08))
        curX += 11.31; curY += -2.38
        path.addCurve(to: pt(curX + 0.64, curY + 0.1), control1: pt(curX + 0.47, curY + -0.08), control2: pt(curX + 0.49, curY + -0.08))
        curX += 0.64; curY += 0.1
        path.addCurve(to: pt(curX + 0.16, curY + 1.8), control1: pt(curX + 0.14, curY + 0.18), control2: pt(curX + 0.16, curY + 0.36))
        curX += 0.16; curY += 1.8
        path.addCurve(to: pt(curX + 0.06, curY + 2.96), control1: pt(curX + 0.0, curY + 0.88), control2: pt(curX + 0.03, curY + 2.21))
        curX += 0.06; curY += 2.96
        path.addCurve(to: pt(curX + 0.0, curY + 1.37), control1: pt(curX + 0.03, curY + 0.75), control2: pt(curX + 0.03, curY + 1.37))
        curX += 0.0; curY += 1.37
        path.addCurve(to: pt(curX + -0.46, curY + -0.21), control1: pt(curX + -0.03, curY + -0.0), control2: pt(curX + -0.23, curY + -0.09))
        curX += -0.46; curY += -0.21
        path.addCurve(to: pt(curX + -3.07, curY + -0.33), control1: pt(curX + -0.88, curY + -0.44), control2: pt(curX + -1.98, curY + -0.56))
        curX += -3.07; curY += -0.33
        path.addCurve(to: pt(curX + -2.23, curY + 1.17), control1: pt(curX + -0.9, curY + 0.19), control2: pt(curX + -1.57, curY + 0.55))
        curX += -2.23; curY += 1.17
        path.addCurve(to: pt(curX + -1.34, curY + 3.1), control1: pt(curX + -0.91, curY + 0.89), control2: pt(curX + -1.34, curY + 1.88))
        curX += -1.34; curY += 3.1
        path.addCurve(to: pt(curX + 4.65, curY + 4.4), control1: pt(curX + 0.0, curY + 2.48), control2: pt(curX + 2.02, curY + 4.4))
        curX += 4.65; curY += 4.4
        path.addCurve(to: pt(curX + 4.44, curY + -3.4), control1: pt(curX + 2.14, curY + -0.0), control2: pt(curX + 3.92, curY + -1.37))
        curX += 4.44; curY += -3.4
        path.addCurve(to: pt(curX + 0.11, curY + -8.68), control1: pt(curX + 0.11, curY + -0.44), control2: pt(curX + 0.13, curY + -1.55))
        curX += 0.11; curY += -8.68
        path.addCurve(to: pt(curX + -0.2, curY + -8.4), control1: pt(curX + -0.03, curY + -8.11), control2: pt(curX + -0.03, curY + -8.17))
        curX += -0.2; curY += -8.4
        path.addCurve(to: pt(curX + -0.38, curY + -0.39), control1: pt(curX + -0.09, curY + -0.13), control2: pt(curX + -0.26, curY + -0.3))
        curX += -0.38; curY += -0.39
        path.addCurve(to: pt(curX + -1.33, curY + -0.15), control1: pt(curX + -0.24, curY + -0.18), control2: pt(curX + -0.92, curY + -0.26))
        curX += -1.33; curY += -0.15
        path.closeSubpath()
        path.closeSubpath()
        return path
    }
}
