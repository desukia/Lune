//
//  LuneTypography.swift
//  Lune
//
//  Typography system supporting Quicksand (Regular & Bold), System, Serif, Monospaced
//  with user-adjustable scaling factor (0.7x – 1.5x) matching Lune Android Type.kt.
//

import SwiftUI

public enum AppFontFamily: String, CaseIterable, Identifiable, Codable {
    case quicksand = "quicksand"
    case system = "system"
    case serif = "serif"
    case monospaced = "monospaced"
    case rounded = "rounded"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .quicksand: return "Quicksand (Default)"
        case .system: return "System"
        case .serif: return "Serif (New York)"
        case .monospaced: return "Monospaced"
        case .rounded: return "System Rounded"
        }
    }
}

public struct LuneFont {
    public static func font(
        family: AppFontFamily = .quicksand,
        size: CGFloat,
        weight: Font.Weight = .regular,
        scale: Double = 1.0
    ) -> Font {
        let scaledSize = size * CGFloat(max(0.7, min(1.5, scale)))
        
        switch family {
        case .quicksand:
            if weight == .bold || weight == .heavy || weight == .black || weight == .semibold {
                return Font.custom("Quicksand-Bold", size: scaledSize)
            } else {
                return Font.custom("Quicksand-Regular", size: scaledSize)
            }
        case .system:
            return Font.system(size: scaledSize, weight: weight, design: .default)
        case .serif:
            return Font.system(size: scaledSize, weight: weight, design: .serif)
        case .monospaced:
            return Font.system(size: scaledSize, weight: weight, design: .monospaced)
        case .rounded:
            return Font.system(size: scaledSize, weight: weight, design: .rounded)
        }
    }
}

// Convenient typography styles matching Android
public extension View {
    func luneDisplayLarge(scale: Double = 1.0, family: AppFontFamily = .quicksand) -> some View {
        self.font(LuneFont.font(family: family, size: 34, weight: .bold, scale: scale))
    }
    func luneHeadline(scale: Double = 1.0, family: AppFontFamily = .quicksand) -> some View {
        self.font(LuneFont.font(family: family, size: 20, weight: .bold, scale: scale))
    }
    func luneTitle(scale: Double = 1.0, family: AppFontFamily = .quicksand) -> some View {
        self.font(LuneFont.font(family: family, size: 16, weight: .semibold, scale: scale))
    }
    func luneBody(scale: Double = 1.0, family: AppFontFamily = .quicksand) -> some View {
        self.font(LuneFont.font(family: family, size: 14, weight: .regular, scale: scale))
    }
    func luneCaption(scale: Double = 1.0, family: AppFontFamily = .quicksand) -> some View {
        self.font(LuneFont.font(family: family, size: 12, weight: .medium, scale: scale))
    }
}
