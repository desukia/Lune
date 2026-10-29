//
//  LiquidGlass.swift
//  Lune
//
//  Standard Apple Liquid Glass design system.
//  Pure native translucency using system ultraThinMaterial, clean light-edge borders,
//  and soft ambient diffusion shadows.
//

import SwiftUI

// MARK: - Liquid Glass Styles
public enum LiquidGlassVariant {
    case regular
    case clear
    case prominent
    case tinted(Color, opacity: Double = 0.25)
    case amoled
}

// MARK: - View Modifiers
public struct LiquidGlassModifier<S: Shape>: ViewModifier {
    let variant: LiquidGlassVariant
    let shape: S
    let interactive: Bool
    let hasBorder: Bool
    let shadowRadius: CGFloat
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var isPressed: Bool = false
    
    public init(
        variant: LiquidGlassVariant = .regular,
        shape: S,
        interactive: Bool = false,
        hasBorder: Bool = true,
        shadowRadius: CGFloat = 8
    ) {
        self.variant = variant
        self.shape = shape
        self.interactive = interactive
        self.hasBorder = hasBorder
        self.shadowRadius = shadowRadius
    }
    
    public func body(content: Content) -> some View {
        content
            .background(glassBackground)
            .clipShape(shape)
            .overlay(
                Group {
                    if hasBorder {
                        cleanGlassBorder
                    }
                }
            )
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.07),
                radius: shadowRadius,
                x: 0,
                y: shadowRadius / 2.5
            )
            .contentShape(shape)
    }
    
    // MARK: - Clean Glass Border
    // Subtle, elegant light-edge rim conforming to Apple Human Interface Guidelines
    private var cleanGlassBorder: some View {
        shape
            .stroke(
                LinearGradient(
                    colors: [
                        Color.white.opacity(colorScheme == .dark ? 0.25 : 0.45),
                        Color.white.opacity(colorScheme == .dark ? 0.08 : 0.15)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 0.6
            )
    }
    
    // MARK: - Native Material Glass Background
    @ViewBuilder
    private var glassBackground: some View {
        ZStack {
            switch variant {
            case .regular:
                Rectangle()
                    .fill(.ultraThinMaterial)
                Color.white.opacity(colorScheme == .dark ? 0.06 : 0.18)
                
            case .clear:
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(0.85)
                
            case .prominent:
                Rectangle()
                    .fill(.thinMaterial)
                Color.white.opacity(colorScheme == .dark ? 0.12 : 0.28)
                
            case .tinted(let tintColor, let opacity):
                Rectangle()
                    .fill(.ultraThinMaterial)
                tintColor.opacity(opacity)
                
            case .amoled:
                Color.black.opacity(0.92)
                    .background(.ultraThinMaterial)
            }
        }
    }
}

// MARK: - View Extension
public extension View {
    func liquidGlass<S: Shape>(
        _ variant: LiquidGlassVariant = .regular,
        in shape: S,
        interactive: Bool = false,
        hasBorder: Bool = true,
        shadowRadius: CGFloat = 8
    ) -> some View {
        self.modifier(
            LiquidGlassModifier(
                variant: variant,
                shape: shape,
                interactive: interactive,
                hasBorder: hasBorder,
                shadowRadius: shadowRadius
            )
        )
    }
    
    func liquidGlassCard(
        cornerRadius: CGFloat = 20,
        variant: LiquidGlassVariant = .regular,
        interactive: Bool = false
    ) -> some View {
        self.padding()
            .liquidGlass(
                variant,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
                interactive: interactive
            )
    }
}

// MARK: - Reusable Liquid Glass Button Style
public struct LiquidGlassButtonStyle: ButtonStyle {
    let variant: LiquidGlassVariant
    let cornerRadius: CGFloat
    let isProminent: Bool
    
    public init(
        variant: LiquidGlassVariant = .regular,
        cornerRadius: CGFloat = 16,
        isProminent: Bool = false
    ) {
        self.variant = variant
        self.cornerRadius = cornerRadius
        self.isProminent = isProminent
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.custom("Quicksand-Bold", size: 15))
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .liquidGlass(
                isProminent ? .prominent : variant,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
                interactive: true
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.70), value: configuration.isPressed)
    }
}

public extension ButtonStyle where Self == LiquidGlassButtonStyle {
    static var liquidGlass: LiquidGlassButtonStyle {
        LiquidGlassButtonStyle(variant: .regular)
    }
    static var liquidGlassProminent: LiquidGlassButtonStyle {
        LiquidGlassButtonStyle(variant: .prominent, isProminent: true)
    }
    static func liquidGlass(tint: Color) -> LiquidGlassButtonStyle {
        LiquidGlassButtonStyle(variant: .tinted(tint, opacity: 0.35))
    }
}

// MARK: - Reusable Circular Liquid Glass Button Style
public struct LiquidGlassCircleButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .liquidGlass(.regular, in: Circle(), interactive: true)
            .scaleEffect(configuration.isPressed ? 0.90 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

public extension ButtonStyle where Self == LiquidGlassCircleButtonStyle {
    static var liquidGlassCircle: LiquidGlassCircleButtonStyle {
        LiquidGlassCircleButtonStyle()
    }
}
