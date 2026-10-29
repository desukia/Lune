//
//  SettingsManager.swift
//  Lune
//
//  User preferences and customization manager:
//  - Complete parity with Lune Android SettingsManager.kt (Themes, Palettes, AMOLED, Fonts, Player UI)
//

import SwiftUI
import Combine

public enum PlayerCoverShape: Int, CaseIterable, Identifiable, Codable {
    case rounded = 0
    case square = 1
    case circle = 2
    
    public var id: Int { rawValue }
    public var name: String {
        switch self {
        case .rounded: return "Rounded"
        case .square: return "Square"
        case .circle: return "Vinyl Circle"
        }
    }
}

public enum PlayerBlurMode: Int, CaseIterable, Identifiable, Codable {
    case dark = 0
    case light = 1
    case cinematic = 2
    
    public var id: Int { rawValue }
    public var name: String {
        switch self {
        case .dark: return "Dark Defocus"
        case .light: return "Light Frosted"
        case .cinematic: return "Cinematic Vibrant"
        }
    }
}

@MainActor
public final class SettingsManager: ObservableObject {
    public static let shared = SettingsManager()
    
    @AppStorage("theme_mode") public var themeMode: AppThemeMode = .system
    @AppStorage("custom_palette") public var customPalette: ColorPaletteOption = .defaultViolet
    @AppStorage("amoled_mode") public var amoledPitchBlack: Bool = false
    
    @AppStorage("font_family") public var fontFamily: AppFontFamily = .quicksand
    @AppStorage("font_scale") public var fontScale: Double = 1.0
    
    @AppStorage("cover_shape") public var coverShape: PlayerCoverShape = .rounded
    @AppStorage("vinyl_spin") public var vinylSpin: Bool = true
    @AppStorage("progress_bar_wave") public var progressBarWave: Bool = true
    @AppStorage("player_blur_mode") public var playerBlurMode: PlayerBlurMode = .cinematic
    
    @AppStorage("hifi_badge_enabled") public var hifiBadgeEnabled: Bool = true
    @AppStorage("crossfade_seconds") public var crossfadeSeconds: Double = 2.0
    
    // Tab visibility
    @AppStorage("visible_tabs_csv") private var visibleTabsCsv: String = "resume,mixes,songs,favorites,albums,artists,genres,folders,playlists"
    
    public var visibleTabs: Set<String> {
        get { Set(visibleTabsCsv.components(separatedBy: ",")) }
        set { visibleTabsCsv = newValue.joined(separator: ",") }
    }
    
    private init() {}
    
    public func resolveColors(for colorScheme: ColorScheme) -> LuneColorScheme {
        let isDark: Bool
        switch themeMode {
        case .system: isDark = (colorScheme == .dark)
        case .light: isDark = false
        case .dark: isDark = true
        }
        return LuneTheme.resolveColors(palette: customPalette, isDark: isDark, amoled: amoledPitchBlack)
    }
}
