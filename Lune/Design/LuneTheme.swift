//
//  LuneTheme.swift
//  Lune
//
//  Exact color palette parity with Lune Android:
//  - Default Material 3 Lune Violet
//  - 5 soft custom palettes: Sunset Peach, Sage Green, Ocean Breeze, Lavender Mist, Warm Amber
//  - AMOLED Pitch Black mode
//

import SwiftUI

public enum AppThemeMode: String, CaseIterable, Identifiable, Codable {
    case system = "system"
    case light = "light"
    case dark = "dark"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .system: return "Auto (System)"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

public enum ColorPaletteOption: Int, CaseIterable, Identifiable, Codable {
    case defaultViolet = 0
    case sunsetPeach = 1
    case sageGreen = 2
    case oceanBreeze = 3
    case lavenderMist = 4
    case warmAmber = 5
    
    public var id: Int { rawValue }
    
    public var name: String {
        switch self {
        case .defaultViolet: return "Lune Violet"
        case .sunsetPeach: return "Sunset Peach"
        case .sageGreen: return "Sage Green"
        case .oceanBreeze: return "Ocean Breeze"
        case .lavenderMist: return "Lavender Mist"
        case .warmAmber: return "Warm Amber"
        }
    }
}

public struct LuneColorScheme {
    public let primary: Color
    public let secondary: Color
    public let tertiary: Color
    public let surface: Color
    public let background: Color
    public let surfaceVariant: Color
    public let onSurface: Color
}

public struct LuneTheme {
    // 0. Default Lune Violet (Matched directly to Lune Logo #554492)
    public static let violetLight = LuneColorScheme(
        primary: Color(hex: 0x554492),
        secondary: Color(hex: 0x6E5AA6),
        tertiary: Color(hex: 0x8C74D9),
        surface: Color(hex: 0xF5F0FF),
        background: Color(hex: 0xF8F6FF),
        surfaceVariant: Color(hex: 0xE8E0FA),
        onSurface: Color(hex: 0x1A1433)
    )
    
    public static let violetDark = LuneColorScheme(
        primary: Color(hex: 0xB59DFF),
        secondary: Color(hex: 0x8C74D9),
        tertiary: Color(hex: 0x554492),
        surface: Color(hex: 0x1A1433),
        background: Color(hex: 0x110D24),
        surfaceVariant: Color(hex: 0x2A204D),
        onSurface: Color(hex: 0xF6F2FF)
    )
    
    // 1. Sunset Peach
    public static let sunsetPeachLight = LuneColorScheme(
        primary: Color(hex: 0xB04B38),
        secondary: Color(hex: 0x775651),
        tertiary: Color(hex: 0x705C2E),
        surface: Color(hex: 0xFFFBFF),
        background: Color(hex: 0xFFFBFF),
        surfaceVariant: Color(hex: 0xF5DDD8),
        onSurface: Color(hex: 0x201A19)
    )
    public static let sunsetPeachDark = LuneColorScheme(
        primary: Color(hex: 0xFFB4AA),
        secondary: Color(hex: 0xE7BDB7),
        tertiary: Color(hex: 0xDEC48C),
        surface: Color(hex: 0x1A1110),
        background: Color(hex: 0x1A1110),
        surfaceVariant: Color(hex: 0x534341),
        onSurface: Color(hex: 0xEDE0DD)
    )
    
    // 2. Sage Green
    public static let sageGreenLight = LuneColorScheme(
        primary: Color(hex: 0x386B52),
        secondary: Color(hex: 0x4F6354),
        tertiary: Color(hex: 0x3C6472),
        surface: Color(hex: 0xFBFDF8),
        background: Color(hex: 0xFBFDF8),
        surfaceVariant: Color(hex: 0xDCE5DC),
        onSurface: Color(hex: 0x191C19)
    )
    public static let sageGreenDark = LuneColorScheme(
        primary: Color(hex: 0x9FD3B1),
        secondary: Color(hex: 0xB7CCBA),
        tertiary: Color(hex: 0xA3CDDC),
        surface: Color(hex: 0x111412),
        background: Color(hex: 0x111412),
        surfaceVariant: Color(hex: 0x414942),
        onSurface: Color(hex: 0xE1E3DF)
    )
    
    // 3. Ocean Breeze
    public static let oceanBreezeLight = LuneColorScheme(
        primary: Color(hex: 0x2E6580),
        secondary: Color(hex: 0x4F626E),
        tertiary: Color(hex: 0x64597C),
        surface: Color(hex: 0xFAFDFD),
        background: Color(hex: 0xFAFDFD),
        surfaceVariant: Color(hex: 0xDAE3E8),
        onSurface: Color(hex: 0x171C1E)
    )
    public static let oceanBreezeDark = LuneColorScheme(
        primary: Color(hex: 0x99CCEA),
        secondary: Color(hex: 0xB7CAD6),
        tertiary: Color(hex: 0xCEC2EC),
        surface: Color(hex: 0x0F1417),
        background: Color(hex: 0x0F1417),
        surfaceVariant: Color(hex: 0x40484D),
        onSurface: Color(hex: 0xDFE3E5)
    )
    
    // 4. Lavender Mist
    public static let lavenderMistLight = LuneColorScheme(
        primary: Color(hex: 0x6E568F),
        secondary: Color(hex: 0x625B71),
        tertiary: Color(hex: 0x7D5262),
        surface: Color(hex: 0xFFFBFF),
        background: Color(hex: 0xFFFBFF),
        surfaceVariant: Color(hex: 0xE7E0EB),
        onSurface: Color(hex: 0x1D1A20)
    )
    public static let lavenderMistDark = LuneColorScheme(
        primary: Color(hex: 0xD6BAFF),
        secondary: Color(hex: 0xCCC2DC),
        tertiary: Color(hex: 0xEFB8C9),
        surface: Color(hex: 0x151218),
        background: Color(hex: 0x151218),
        surfaceVariant: Color(hex: 0x4A4451),
        onSurface: Color(hex: 0xE7E0E8)
    )
    
    // 5. Warm Amber
    public static let warmAmberLight = LuneColorScheme(
        primary: Color(hex: 0x7F5700),
        secondary: Color(hex: 0x6C5D47),
        tertiary: Color(hex: 0x4F6548),
        surface: Color(hex: 0xFFFBFF),
        background: Color(hex: 0xFFFBFF),
        surfaceVariant: Color(hex: 0xEEE1CE),
        onSurface: Color(hex: 0x1F1B13)
    )
    public static let warmAmberDark = LuneColorScheme(
        primary: Color(hex: 0xFCBC43),
        secondary: Color(hex: 0xD7C4A7),
        tertiary: Color(hex: 0xB7CDA6),
        surface: Color(hex: 0x181206),
        background: Color(hex: 0x181206),
        surfaceVariant: Color(hex: 0x4F4535),
        onSurface: Color(hex: 0xEEE0CE)
    )
    
    public static func resolveColors(
        palette: ColorPaletteOption,
        isDark: Bool,
        amoled: Bool
    ) -> LuneColorScheme {
        let base: LuneColorScheme
        if isDark {
            switch palette {
            case .defaultViolet: base = violetDark
            case .sunsetPeach: base = sunsetPeachDark
            case .sageGreen: base = sageGreenDark
            case .oceanBreeze: base = oceanBreezeDark
            case .lavenderMist: base = lavenderMistDark
            case .warmAmber: base = warmAmberDark
            }
        } else {
            switch palette {
            case .defaultViolet: base = violetLight
            case .sunsetPeach: base = sunsetPeachLight
            case .sageGreen: base = sageGreenLight
            case .oceanBreeze: base = oceanBreezeLight
            case .lavenderMist: base = lavenderMistLight
            case .warmAmber: base = warmAmberLight
            }
        }
        
        if isDark && amoled {
            return LuneColorScheme(
                primary: base.primary,
                secondary: base.secondary,
                tertiary: base.tertiary,
                surface: Color.black,
                background: Color.black,
                surfaceVariant: Color(hex: 0x121212),
                onSurface: base.onSurface
            )
        }
        return base
    }
}

// MARK: - Color Hex Initializer
public extension Color {
    init(hex: UInt32, opacity: Double = 1.0) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}
