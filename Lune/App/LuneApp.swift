//
//  LuneApp.swift
//  Lune
//
//  Main application entry point for Lune iOS.
//

import SwiftUI

@main
struct LuneApp: App {
    @StateObject private var settings = SettingsManager.shared
    @StateObject private var player = AudioPlayerManager.shared
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .preferredColorScheme(resolvedColorScheme)
                .tint(settings.resolveColors(for: .dark).primary)
        }
    }
    
    private var resolvedColorScheme: ColorScheme? {
        switch settings.themeMode {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
