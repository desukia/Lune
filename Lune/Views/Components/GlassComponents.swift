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
