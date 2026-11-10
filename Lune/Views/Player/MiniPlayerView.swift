//
//  MiniPlayerView.swift
//  Lune
//
//  Floating interactive mini player capsule.
//  Supports authentic 1:1 Material You (Material 3 Expressive) and Liquid Glass:
//  - Material 3: M3 surfaceContainer card, 24dp corner radius, primaryContainer play button
//  - Liquid Glass: Apple frosted glass with specular reflection
//  - Sits directly above the UnifiedHeaderPill dock
//

import SwiftUI

@MainActor
public struct MiniPlayerView: View {
    @ObservedObject var player: AudioPlayerManager
    let primaryColor: Color
    let onExpand: () -> Void
    
    @ObservedObject private var settings: SettingsManager
    @Environment(\.colorScheme) private var colorScheme
    
    @MainActor
    public init(
        player: AudioPlayerManager,
        primaryColor: Color = Color(hex: 0xD0BCFF),
        onExpand: @escaping () -> Void
    ) {
        self.player = player
        self.primaryColor = primaryColor
        self.onExpand = onExpand
        self.settings = .shared
    }
    
    @MainActor
    public init(
        primaryColor: Color = Color(hex: 0xD0BCFF),
        onExpand: @escaping () -> Void
    ) {
        self.player = .shared
        self.primaryColor = primaryColor
        self.onExpand = onExpand
        self.settings = .shared
    }
    
    public var body: some View {
        let colors = settings.resolveColors(for: colorScheme)
        
        if let song = player.currentSong {
            if settings.uiStyle == .materialYou {
                m3MiniPlayer(song: song, colors: colors)
            } else {
                liquidGlassMiniPlayer(song: song, colors: colors)
            }
        }
    }
    
    // MARK: - Material You 1:1 Mini Player (Android Lune Parity)
    @ViewBuilder
    private func m3MiniPlayer(song: Song, colors: LuneColorScheme) -> some View {
        HStack(spacing: 8) {
            // 1. Left Pill Capsule (Track Info + Play Button with circular progress)
            Button(action: onExpand) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(song.title)
                            .font(.custom("Quicksand-Bold", size: 15))
                            .foregroundColor(colors.onSurface)
                            .lineLimit(1)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "music.note")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(colors.onSurface.opacity(0.85))
                            
                            Text(song.artist)
                                .font(.custom("Quicksand-Regular", size: 12))
                                .foregroundColor(colors.onSurface.opacity(0.80))
                                .lineLimit(1)
                        }
                    }
                    
                    Spacer(minLength: 4)
                    
                    // Circular Play/Pause Button with outer progress ring (ScallopPlayPauseButtonWithProgress 48x48)
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        player.togglePlayPause()
                    } label: {
                        ZStack {
                            // Circular track ring
                            Circle()
                                .stroke(Color.white.opacity(0.24), lineWidth: 3.5)
                            
                            // Active progress arc (Android Lune: clean white on blur)
                            Circle()
                                .trim(from: 0, to: CGFloat(player.playbackProgress))
                                .stroke(Color.white, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                                .animation(.linear(duration: 0.25), value: player.playbackProgress)
                            
                            // Center Icons (Authentic Android Lune: clean white, NO solid circle background)
                            if player.isPlaying {
                                HStack(spacing: 4) {
                                    Capsule()
                                        .fill(Color.white)
                                        .frame(width: 4, height: 16)
                                    Capsule()
                                        .fill(Color.white)
                                        .frame(width: 4, height: 16)
                                }
                            } else {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(Color.white)
                                    .offset(x: 1.5)
                            }
                        }
                        .frame(width: 48, height: 48)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.leading, 20)
                .padding(.trailing, 10)
                .frame(maxHeight: .infinity)
                .background {
                    ZStack {
                        // Base solid opaque background (prevents ANY bleed-through from underlying views)
                        colors.surface
                        
                        // Blurred album cover overlay (1:1 Android MiniPlayerBlurCrossfade)
                        if let data = song.artworkData, let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .blur(radius: 25)
                                .opacity(colorScheme == .dark ? 0.22 : 0.35)
                        }
                        
                        // Subtle surface container tint
                        colors.primary.opacity(colorScheme == .dark ? 0.14 : 0.08)
                    }
                }
                .clipShape(Capsule())
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.10), radius: 8, x: 0, y: 3)
            }
            .buttonStyle(.plain)
            
            // 2. Standalone Circular Cover Art (70x70dp CircleShape)
            Button(action: onExpand) {
                ZStack {
                    Circle()
                        .fill(colors.secondaryContainer)
                        .frame(width: 70, height: 70)
                    
                    if let data = song.artworkData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 70, height: 70)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "music.note")
                            .font(.system(size: 26))
                            .foregroundColor(colors.onSecondaryContainer)
                    }
                }
                .frame(width: 70, height: 70)
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.10), radius: 8, x: 0, y: 3)
            }
            .buttonStyle(.plain)
        }
        .frame(height: 70)
    }
    
    // MARK: - Liquid Glass Mini Player (iOS Apple Music Parity)
    @ViewBuilder
    private func liquidGlassMiniPlayer(song: Song, colors: LuneColorScheme) -> some View {
        Button(action: onExpand) {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    // Album Art
                    ZStack {
                        if let data = song.artworkData, let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 44, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        } else {
                            ArtworkPlaceholderView(size: 44, cornerRadius: 10)
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.white.opacity(0.18), lineWidth: 0.8)
                    )
                    
                    // Title & Artist
                    VStack(alignment: .leading, spacing: 2) {
                        Text(song.title)
                            .font(.custom("Quicksand-Bold", size: 14))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Text(song.artist)
                            .font(.custom("Quicksand-Regular", size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Play/Pause Button
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        player.togglePlayPause()
                    } label: {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(primaryColor)
                            .frame(width: 38, height: 38)
                            .background(
                                Circle()
                                    .fill(primaryColor.opacity(colorScheme == .dark ? 0.22 : 0.14))
                                    .overlay(
                                        Circle()
                                            .stroke(primaryColor.opacity(0.4), lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    
                    // Next Track Button
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        player.next()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                
                // Thin progress line at the bottom
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.primary.opacity(0.06))
                            .frame(height: 2.5)
                        
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [primaryColor.opacity(0.7), primaryColor],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * CGFloat(player.playbackProgress), height: 2.5)
                            .animation(.linear(duration: 0.25), value: player.playbackProgress)
                    }
                }
                .frame(height: 2.5)
            }
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.clear)
                    .liquidGlass(
                        .regular,
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous),
                        interactive: true,
                        hasBorder: true,
                        shadowRadius: 12
                    )
            }
        }
        .buttonStyle(.plain)
    }
}
