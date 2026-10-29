//
//  MaterialYou.swift
//  Lune
//
//  Authentic Material You (Material 3 Expressive) Design System:
//  - M3 Tonal Surface containers & elevations
//  - M3 Expressive shapes: Small (8dp), Medium (12dp), Large (16dp), Extra Large (28dp), Pill (Capsule)
//  - M3 Interactive buttons, cards, pills & bounce scale animations matching Jetpack Compose
//

import SwiftUI

// MARK: - M3 Expressive Shapes
public struct M3Shape {
    public static let cornerSmall: CGFloat = 8
    public static let cornerMedium: CGFloat = 12
    public static let cornerLarge: CGFloat = 16
    public static let cornerExtraLarge: CGFloat = 28
    public static let cornerPill: CGFloat = 35
}

// MARK: - Material 3 Surface & Card Modifiers
public struct M3CardModifier: ViewModifier {
    let colors: LuneColorScheme
    let cornerRadius: CGFloat
    let isSelected: Bool
    let elevation: CGFloat
    
    public init(
        colors: LuneColorScheme,
        cornerRadius: CGFloat = M3Shape.cornerLarge,
        isSelected: Bool = false,
        elevation: CGFloat = 0
    ) {
        self.colors = colors
        self.cornerRadius = cornerRadius
        self.isSelected = isSelected
        self.elevation = elevation
    }
    
    public func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(isSelected ? colors.primaryContainer : colors.surfaceContainer)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        isSelected ? colors.primary : colors.outlineVariant.opacity(0.35),
                        lineWidth: isSelected ? 1.5 : 0.8
                    )
            )
            .shadow(
                color: Color.black.opacity(elevation > 0 ? 0.15 : 0.0),
                radius: elevation * 2,
                x: 0,
                y: elevation
            )
    }
}

public struct M3PillModifier: ViewModifier {
    let colors: LuneColorScheme
    let isActive: Bool
    
    public func body(content: Content) -> some View {
        content
            .background(
                Capsule()
                    .fill(isActive ? colors.secondaryContainer : colors.surfaceContainerHigh)
            )
            .overlay(
                Capsule()
                    .stroke(
                        isActive ? colors.primary.opacity(0.50) : colors.outlineVariant.opacity(0.30),
                        lineWidth: 0.8
                    )
            )
    }
}

// MARK: - Adaptive Design System Modifier
public struct AdaptiveCardModifier: ViewModifier {
    let uiStyle: AppUIStyle
    let colors: LuneColorScheme
    let cornerRadius: CGFloat
    let isSelected: Bool
    
    public func body(content: Content) -> some View {
        if uiStyle == .materialYou {
            content
                .modifier(M3CardModifier(colors: colors, cornerRadius: cornerRadius, isSelected: isSelected))
        } else {
            content
                .liquidGlass(
                    isSelected ? .tinted(colors.primary, opacity: 0.18) : .regular,
                    in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
        }
    }
}

public extension View {
    func m3Card(
        colors: LuneColorScheme,
        cornerRadius: CGFloat = M3Shape.cornerLarge,
        isSelected: Bool = false,
        elevation: CGFloat = 0
    ) -> some View {
        self.modifier(M3CardModifier(colors: colors, cornerRadius: cornerRadius, isSelected: isSelected, elevation: elevation))
    }
    
    func m3Pill(colors: LuneColorScheme, isActive: Bool = false) -> some View {
        self.modifier(M3PillModifier(colors: colors, isActive: isActive))
    }
    
    func adaptiveCard(
        uiStyle: AppUIStyle,
        colors: LuneColorScheme,
        cornerRadius: CGFloat = M3Shape.cornerLarge,
        isSelected: Bool = false
    ) -> some View {
        self.modifier(AdaptiveCardModifier(uiStyle: uiStyle, colors: colors, cornerRadius: cornerRadius, isSelected: isSelected))
    }
    
    func m3BounceEffect(scale: CGFloat = 0.95) -> some View {
        self.buttonStyle(M3BounceButtonStyle(scale: scale))
    }
}

// MARK: - M3 Jetpack Compose Bounce Button Style
public struct M3BounceButtonStyle: ButtonStyle {
    let scale: CGFloat
    
    public init(scale: CGFloat = 0.95) {
        self.scale = scale
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.65), value: configuration.isPressed)
    }
}
