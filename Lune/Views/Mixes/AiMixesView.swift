//
//  AiMixesView.swift
//  Lune
//
//  Lune AI Core Hub: On-device intelligence, Smart Shuffle, Discovery Mode,
//  and personalized algorithmic mixes matching Android AiMixesScreen.kt.
//

import SwiftUI

@MainActor
public struct AiMixesView: View {
    @ObservedObject var aiEngine: LuneAiEngine
    @ObservedObject var library: MusicLibraryManager
    @ObservedObject var player: AudioPlayerManager
    @ObservedObject var settings: SettingsManager
    
    @State private var selectedMix: AiMix? = nil
    
    @MainActor
    public init(
        aiEngine: LuneAiEngine = .shared,
        library: MusicLibraryManager = .shared,
        player: AudioPlayerManager = .shared,
        settings: SettingsManager = .shared
    ) {
        self.aiEngine = aiEngine
        self.library = library
        self.player = player
        self.settings = settings
    }
    
    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                // Header Banner: Lune AI Core
                aiCoreBanner
                
                // Quick AI Action Buttons (Smart Shuffle & Discovery Mode)
                aiActionButtons
                
                // 8 Personalized Mix Cards
                VStack(alignment: .leading, spacing: 14) {
                    Text("Your Personalized Mixes")
                        .font(.custom("Quicksand-Bold", size: 20))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 16)
                    
                    if aiEngine.aiMixes.isEmpty {
                        emptyMixesHint
                    } else {
                        LazyVStack(spacing: 14) {
                            ForEach(aiEngine.aiMixes) { mix in
                                mixCard(mix)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 160)
        }
        .sheet(item: $selectedMix) { mix in
            AiMixDetailView(mix: mix, player: player, primaryColor: settings.resolveColors(for: .dark).primary)
        }
    }
    
    // MARK: - Banner
    
    private var aiCoreBanner: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: 0x6366F1), Color(hex: 0xEC4899)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                
                Image(systemName: "sparkles")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text("Lune AI Engine")
                    .font(.custom("Quicksand-Bold", size: 18))
                    .foregroundColor(.primary)
                Text("100% on-device & private learning. Adapts to your listening hours and harmonic taste.")
                    .font(.custom("Quicksand-Regular", size: 12))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .liquidGlass(.regular, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(.horizontal, 16)
    }
    
    // MARK: - AI Action Buttons
    
    private var aiActionButtons: some View {
        HStack(spacing: 12) {
            // Smart Shuffle Button
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                let shuffled = aiEngine.generateSmartShuffle(library.allSongs)
                player.playQueue(shuffled)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 16, weight: .bold))
                    Text("Smart Shuffle")
                        .font(.custom("Quicksand-Bold", size: 14))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .liquidGlass(
                    .tinted(Color(hex: 0x6366F1), opacity: 0.85),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous),
                    interactive: true
                )
            }
            .buttonStyle(.plain)
            
            // Discovery Queue Button
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                let discovery = aiEngine.generateDiscoveryQueue(library.allSongs)
                player.playQueue(discovery)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "safari.fill")
                        .font(.system(size: 16, weight: .bold))
                    Text("Discovery")
                        .font(.custom("Quicksand-Bold", size: 14))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .liquidGlass(
                    .tinted(Color(hex: 0x059669), opacity: 0.85),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous),
                    interactive: true
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Mix Card
    
    private func mixCard(_ mix: AiMix) -> some View {
        Button {
            selectedMix = mix
        } label: {
            ZStack {
                // Vibrant Gradient Mesh
                LinearGradient(
                    colors: mix.gradientColors.map { $0.opacity(0.85) },
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                // Liquid Glass Sheen Overlay
                LinearGradient(
                    colors: [Color.white.opacity(0.25), Color.clear],
                    startPoint: .top,
                    endPoint: .center
                )
                
                HStack(spacing: 16) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.20))
                            .frame(width: 52, height: 52)
                        
                        Image(systemName: mix.iconName)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text(mix.title)
                            .font(.custom("Quicksand-Bold", size: 18))
                            .foregroundColor(.white)
                        
                        Text(mix.subtitle)
                            .font(.custom("Quicksand-Regular", size: 13))
                            .foregroundColor(.white.opacity(0.85))
                            .lineLimit(1)
                        
                        Text("\(mix.songs.count) songs")
                            .font(.custom("Quicksand-Bold", size: 11))
                            .foregroundColor(.white.opacity(0.75))
                            .padding(.top, 2)
                    }
                    
                    Spacer()
                    
                    // Direct Play Button
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        player.playQueue(mix.songs)
                    } label: {
                        Image(systemName: "play.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.white.opacity(0.25)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(18)
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.35), lineWidth: 1)
            )
            .shadow(color: mix.gradientColors.first?.opacity(0.3) ?? .clear, radius: 10, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }
    
    private var emptyMixesHint: some View {
        VStack(spacing: 8) {
            Image(systemName: "music.note")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            Text("Analyzing your library...")
                .font(.custom("Quicksand-Bold", size: 15))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
