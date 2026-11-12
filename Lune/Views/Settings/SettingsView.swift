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
    @State private var showFileImporter: Bool = false
    
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
                Section(header: Text("Theme".localized).font(.custom("Quicksand-Bold", size: 12))) {
                    Picker("Theme Mode".localized, selection: $settings.themeMode) {
                        ForEach(AppThemeMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                }
                
                // MARK: - Player Customization
                Section(header: Text("Now Playing Player".localized).font(.custom("Quicksand-Bold", size: 12))) {
                    Toggle("Full Screen Album Art".localized, isOn: $settings.fullScreenCover)
                    
                    Picker("Cover Art Shape".localized, selection: $settings.coverShape) {
                        ForEach(PlayerCoverShape.allCases) { shape in
                            Text(shape.name).tag(shape)
                        }
                    }
                    
                    if settings.coverShape == .circle {
                        Toggle("Vinyl Spin Animation".localized, isOn: $settings.vinylSpin)
                    }
                    
                    Toggle("Wavy Progress Bar".localized, isOn: $settings.progressBarWave)
                    
                    Picker("Background Blur".localized, selection: $settings.playerBlurMode) {
                        ForEach(PlayerBlurMode.allCases) { mode in
                            Text(mode.name).tag(mode)
                        }
                    }
                }
                
                // MARK: - Audio Features
                Section(header: Text("Audio & Library".localized).font(.custom("Quicksand-Bold", size: 12))) {
                    Toggle("Hi-Fi / Hi-Res Badges".localized, isOn: $settings.hifiBadgeEnabled)
                    
                    Button {
                        showFileImporter = true
                    } label: {
                        HStack {
                            Text("Import Audio Files / Folders".localized)
                            Spacer()
                            Image(systemName: "plus.circle")
                        }
                    }
                    
                    Button {
                        Task { await library.scanLibrary() }
                    } label: {
                        HStack {
                            Text("Rescan Music Library".localized)
                            Spacer()
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
                
                // MARK: - Privacy & AI
                Section(header: Text("Privacy & On-Device AI".localized).font(.custom("Quicksand-Bold", size: 12))) {
                    Button(role: .destructive) {
                        showResetAlert = true
                    } label: {
                        Text("Reset AI Learning & Habit Telemetry".localized)
                    }
                }
                
                // MARK: - About
                Section {
                    NavigationLink(destination: AboutView()) {
                        HStack {
                            Text("About Lune".localized)
                            Spacer()
                            Text("v0.0.1")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Settings".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done".localized) { dismiss() }
                        .font(.custom("Quicksand-Bold", size: 15))
                }
            }
            .alert("Reset AI Telemetry?".localized, isPresented: $showResetAlert) {
                Button("Reset".localized, role: .destructive) {
                    AiTelemetryStorage.shared.clearAll()
                }
                Button("Cancel".localized, role: .cancel) {}
            } message: {
                Text("This will clear all learned listening habits and Markov transitions.".localized)
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.audio, .folder],
                allowsMultipleSelection: true
            ) { result in
                if case .success(let urls) = result {
                    Task {
                        await library.importAudioFiles(from: urls)
                    }
                }
            }
        }
        .appBlurBackground()
    }
}
