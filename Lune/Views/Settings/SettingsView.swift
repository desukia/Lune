//
//  SettingsView.swift
//  Lune
//
//  Complete settings and customizations view matching Android Lune.
//

import SwiftUI

@MainActor
public struct SettingsView: View {
    @ObservedObject var settings: SettingsManager
    @ObservedObject var library: MusicLibraryManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var showResetAlert: Bool = false
    
    public init(settings: SettingsManager, library: MusicLibraryManager) {
        self.settings = settings
        self.library = library
    }
    
    public init() {
        self.settings = .shared
        self.library = .shared
    }
    
    public var body: some View {
        NavigationStack {
            Form {

                // MARK: - Theme Mode
                Section(header: Text("Theme").font(.custom("Quicksand-Bold", size: 12))) {
                    Picker("Theme Mode", selection: $settings.themeMode) {
                        ForEach(AppThemeMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                }
                
                // MARK: - Player Customization
                Section(header: Text("Now Playing Player").font(.custom("Quicksand-Bold", size: 12))) {
                    Picker("Cover Art Shape", selection: $settings.coverShape) {
                        ForEach(PlayerCoverShape.allCases) { shape in
                            Text(shape.name).tag(shape)
                        }
                    }
                    
                    if settings.coverShape == .circle {
                        Toggle("Vinyl Spin Animation", isOn: $settings.vinylSpin)
                    }
                    
                    Toggle("Wavy Progress Bar", isOn: $settings.progressBarWave)
                    
                    Picker("Background Blur", selection: $settings.playerBlurMode) {
                        ForEach(PlayerBlurMode.allCases) { mode in
                            Text(mode.name).tag(mode)
                        }
                    }
                }
                
                // MARK: - Audio Features
                Section(header: Text("Audio & Library").font(.custom("Quicksand-Bold", size: 12))) {
                    Toggle("Hi-Fi / Hi-Res Badges", isOn: $settings.hifiBadgeEnabled)
                    
                    Button {
                        Task { await library.scanLibrary() }
                    } label: {
                        HStack {
                            Text("Rescan Music Library")
                            Spacer()
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
                
                // MARK: - Privacy & AI
                Section(header: Text("Privacy & On-Device AI").font(.custom("Quicksand-Bold", size: 12))) {
                    Button(role: .destructive) {
                        showResetAlert = true
                    } label: {
                        Text("Reset AI Learning & Habit Telemetry")
                    }
                }
                
                // MARK: - About
                Section {
                    NavigationLink(destination: AboutView()) {
                        HStack {
                            Text("About Lune")
                            Spacer()
                            Text("v0.0.1")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.custom("Quicksand-Bold", size: 15))
                }
            }
            .alert("Reset AI Telemetry?", isPresented: $showResetAlert) {
                Button("Reset", role: .destructive) {
                    AiTelemetryStorage.shared.clearAll()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will clear all learned listening habits and Markov transitions.")
            }
        }
    }
}
