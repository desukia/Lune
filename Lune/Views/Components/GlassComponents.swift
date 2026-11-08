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
                    .stroke(Color.white.opacity(0.24), lineWidth: 3.5)
                
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

