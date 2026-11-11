//
//  NowPlayingView.swift
//  Lune
//
//  Authentic 1:1 Apple Music styled Now Playing interface:
//  - Fully centered, responsive layout constrained strictly to screen bounds
//  - Dynamic ambient artwork bloom backdrop with zero lag or frame drops
//  - Interactive continuous squircle artwork with playback scale animation
//  - Direct song title, artist, lossless fidelity badge, and favorite toggle
//  - Sleek Apple Music 5pt scrubber bar with live elapsed and remaining timestamps
//  - Bare Apple Music playback controls (Shuffle, Prev, Play/Pause, Next, Repeat)
//  - Inline Apple Music volume slider
//  - Bottom Apple Music utility dock (Synced Lyrics, Equalizer, Queue)
//  - Seamless Apple Music karaoke live synchronized lyrics mode (Vagalume + LRCLIB)
//

import SwiftUI

public enum NowPlayingMode {
    case artwork
    case lyrics
}

@MainActor
public struct NowPlayingView: View {
    @ObservedObject var player: AudioPlayerManager
    @ObservedObject var settings: SettingsManager
    @ObservedObject private var library: MusicLibraryManager
    @ObservedObject private var lyricsManager: LyricsManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    private var primaryColor: Color {
        settings.resolveColors(for: colorScheme).primary
    }
    
    @State private var activeMode: NowPlayingMode = .artwork
    @State private var showQueue: Bool = false
    @State private var showEqualizer: Bool = false
    @State private var showSleepTimer: Bool = false
    @State private var showAddToPlaylist: Bool = false
    
    // Scrubber drag state
    @State private var isDraggingScrubber: Bool = false
    @State private var dragScrubProgress: Double = 0.0
    
    // Volume drag state
    @State private var isDraggingVolume: Bool = false
    @State private var dragVolume: Float = 1.0
    
    // Cover artwork drag state
    @State private var coverDragOffset: CGFloat = 0.0
    
    // Play state animation label state (1:1 Android Lune Play/Pause Morphing)
    @State private var showPlayStateLabel: Bool = false
    @State private var playStateWorkItem: DispatchWorkItem? = nil
    
    // Lyrics Controls (1:1 Android LyricsActivity Parity)
    @State private var lyricsAlignment: TextAlignment = .leading
    @State private var lyricsOffsetMs: Double = 0.0
    @State private var showLyricsOffsetBar: Bool = false
    
    @MainActor
    public init(
        player: AudioPlayerManager,
        settings: SettingsManager
    ) {
        self.player = player
        self.settings = settings
        self.library = .shared
        self.lyricsManager = .shared
    }
    
    @MainActor
    public init() {
        self.player = .shared
        self.settings = .shared
        self.library = .shared
        self.lyricsManager = .shared
    }
    
    public var body: some View {
        GeometryReader { geo in
            let screenWidth = geo.size.width
            let screenHeight = geo.size.height
            let isCompact = screenHeight < 720
            let colors = settings.resolveColors(for: colorScheme)
            
            if settings.uiStyle == .materialYou {
                materialYouNowPlaying(geo: geo, screenWidth: screenWidth, screenHeight: screenHeight, isCompact: isCompact, colors: colors)
            } else {
                liquidGlassNowPlaying(geo: geo, screenWidth: screenWidth, screenHeight: screenHeight, isCompact: isCompact)
            }
        }
        .ignoresSafeArea()
        .sheet(isPresented: $showQueue) {
            QueueView(player: player, primaryColor: primaryColor)
        }
        .sheet(isPresented: $showEqualizer) {
            EqualizerView(primaryColor: primaryColor)
        }
        .sheet(isPresented: $showAddToPlaylist) {
            if let song = player.currentSong {
                AddToPlaylistSheet(song: song)
            }
        }
        .confirmationDialog("Sleep Timer".localized, isPresented: $showSleepTimer, titleVisibility: .visible) {
            Button("15 Minutes".localized) { player.setSleepTimer(minutes: 15) }
            Button("30 Minutes".localized) { player.setSleepTimer(minutes: 30) }
            Button("45 Minutes".localized) { player.setSleepTimer(minutes: 45) }
            Button("60 Minutes".localized) { player.setSleepTimer(minutes: 60) }
            if player.sleepTimerMinutesRemaining != nil {
                Button("Turn Off Timer".localized, role: .destructive) { player.cancelSleepTimer() }
            }
            Button("Cancel".localized, role: .cancel) {}
        }
        .onAppear {
            if let song = player.currentSong {
                Task { await lyricsManager.fetchLyrics(for: song) }
            }
        }
        .onChange(of: player.currentSong?.id) { _, _ in
            if let song = player.currentSong {
                Task { await lyricsManager.fetchLyrics(for: song) }
            }
        }
    }
    
    // MARK: - Liquid Glass Apple Music Styled View (Reversible)
    @ViewBuilder
    private func liquidGlassNowPlaying(
        geo: GeometryProxy,
        screenWidth: CGFloat,
        screenHeight: CGFloat,
        isCompact: Bool
    ) -> some View {
        let coverSize = min(screenWidth - 64, isCompact ? 220 : min(screenHeight * 0.36, 300))
        
        ZStack(alignment: .center) {
            // 0. Apple Music Dynamic Ambient Blurred Artwork Backdrop
            backgroundBackdrop(width: screenWidth, height: screenHeight)
            
            // 1. Content Column
            VStack(spacing: 0) {
                let safeTop = max(geo.safeAreaInsets.top, 54)
                
                // Top Drag Indicator Pill
                Capsule()
                    .fill(Color.white.opacity(0.35))
                    .frame(width: 36, height: 5)
                    .padding(.top, safeTop + 2)
                    .padding(.bottom, 6)
                    .onTapGesture {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        dismiss()
                    }
                
                // Top Header Bar
                topHeaderBar
                    .padding(.horizontal, 20)
                    .frame(width: screenWidth, height: 44)
                    .gesture(
                        DragGesture(minimumDistance: 20)
                            .onEnded { val in
                                if val.translation.height > 40 {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    dismiss()
                                }
                            }
                    )
                
                Spacer(minLength: isCompact ? 6 : 14)
                
                // Middle Body
                if activeMode == .lyrics {
                    lyricsContentView
                        .frame(width: screenWidth)
                        .frame(maxHeight: .infinity)
                        .transition(.opacity)
                } else {
                    artworkContentView(coverSize: coverSize, isCompact: isCompact)
                        .frame(width: screenWidth)
                        .frame(maxHeight: .infinity)
                        .transition(.opacity)
                }
                
                Spacer(minLength: isCompact ? 8 : 16)
                
                // Scrubber Bar & Timestamps
                scrubberSection
                    .padding(.horizontal, 24)
                    .frame(width: screenWidth)
                
                Spacer(minLength: isCompact ? 8 : 14)
                
                // Controls
                controlsRow
                    .padding(.horizontal, 24)
                    .frame(width: screenWidth)
                
                Spacer(minLength: isCompact ? 10 : 16)
                
                // Volume Slider
                volumeSliderSection
                    .padding(.horizontal, 32)
                    .frame(width: screenWidth)
                
                Spacer(minLength: isCompact ? 12 : 20)
                
                // Bottom Utility Dock
                bottomUtilityDock
                    .padding(.horizontal, 32)
                    .frame(width: screenWidth)
                    .padding(.bottom, max(geo.safeAreaInsets.bottom, 16))
            }
            .frame(width: screenWidth, height: screenHeight)
        }
        .frame(width: screenWidth, height: screenHeight)
        .clipped()
    }
    
    // MARK: - Material You (Android 1:1) Layout
    @ViewBuilder
    private func materialYouNowPlaying(
        geo: GeometryProxy,
        screenWidth: CGFloat,
        screenHeight: CGFloat,
        isCompact: Bool,
        colors: LuneColorScheme
    ) -> some View {
        let safeTop = max(geo.safeAreaInsets.top, 44)
        // Elevate controls cleanly (subir os botões) with comfortable bottom clearance
        let safeBottom = max(geo.safeAreaInsets.bottom + 26, 54)
        let coverSize = isCompact ? 210 : min(screenWidth - 56, screenHeight * 0.38)
        
        ZStack {
            // 1. Material 3 Adaptive Background (Pure Black in Dark, Pure White in Light)
            (colors.isDark ? Color.black : colors.background)
            
            // 2. Global Artwork Blur Background (1:1 Android FullPlayer Parity)
            if let data = player.currentSong?.artworkData ?? library.allSongs.first?.artworkData,
               let img = UIImage(data: data) {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: screenWidth, height: screenHeight)
                    .clipped()
                    .blur(radius: 45)
                    .opacity(colors.isDark ? 0.38 : 0.16)
                    .overlay(
                        colors.isDark ? Color.black.opacity(0.48) : Color.white.opacity(0.72)
                    )
            }
            
            // 3. Main Player Layout (Elevated controls, perfectly balanced)
            VStack(spacing: 0) {
                // Top Cover Section
                VStack(spacing: 12) {
                    m3TopHeaderBar(colors: colors)
                    
                    if activeMode == .lyrics {
                        m3LyricsContentView(colors: colors)
                            .frame(width: screenWidth - 48, height: coverSize)
                    } else {
                        m3CoverArtworkView(coverSize: coverSize, colors: colors)
                    }
                }
                .padding(.top, safeTop)
                .padding(.horizontal, 24)
                .frame(width: screenWidth)
                
                Spacer(minLength: 16)
                
                // Bottom Controls Section (Raised up)
                VStack(spacing: 0) {
                    // Track Info Row
                    m3TrackInfoRow(colors: colors)
                    
                    Spacer().frame(height: 10)
                    
                    // Wavy Progress Bar & Timestamps
                    m3ProgressSection(colors: colors)
                    
                    Spacer().frame(height: 16)
                    
                    // Playback Controls Row (Skip Prev, Play/Pause, Skip Next)
                    m3ControlsRow(colors: colors)
                    
                    Spacer().frame(height: 18)
                    
                    // Bottom Option Pills Row (Shuffle, Repeat, Queue)
                    m3OptionsRow(colors: colors)
                }
                .padding(.horizontal, 24)
                .frame(width: screenWidth)
                .padding(.bottom, safeBottom)
            }
            .frame(width: screenWidth, height: screenHeight)
        }
        .frame(width: screenWidth, height: screenHeight)
        .clipped()
        .gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { val in
                    if val.translation.height > 50 && abs(val.translation.height) > abs(val.translation.width) * 1.2 {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        dismiss()
                    }
                }
        )
    }
    
    // MARK: - M3 Subviews (1:1 Android Lune Parity)
    private func m3TopHeaderBar(colors: LuneColorScheme) -> some View {
        let isDark = colors.isDark
        let pillBg = isDark ? Color.black.opacity(0.45) : Color.black.opacity(0.08)
        let iconTint = isDark ? Color.white.opacity(0.85) : Color(hex: 0x141414)
        
        return HStack(spacing: 10) {
            // Left: Add To Playlist Button
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showAddToPlaylist = true
            } label: {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(pillBg)
                    .frame(width: 46, height: 46)
                    .overlay(
                        Image(systemName: "text.badge.plus")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(iconTint)
                    )
            }
            .buttonStyle(M3BounceButtonStyle())
            
            // Middle: Left-aligned "Playing from" & Album/Category
            VStack(alignment: .leading, spacing: 2) {
                Text(activeMode == .lyrics ? "LIVE LYRICS".localized : "PLAYING FROM".localized)
                    .font(.custom("Quicksand-Bold", size: 10))
                    .tracking(1.0)
                    .foregroundColor(colors.onSurfaceVariant)
                
                Text(player.currentSong?.album.isEmpty == false ? player.currentSong!.album : "All Songs".localized)
                    .font(.custom("Quicksand-Bold", size: 16))
                    .foregroundColor(colors.onSurface)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Right: Connected Split Pill [ GraphicEq | Speaker / Options ]
            HStack(spacing: 4) {
                // EQ button
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showEqualizer = true
                } label: {
                    UnevenRoundedPillSide(topLeading: 23, bottomLeading: 23, bottomTrailing: 5, topTrailing: 5)
                        .fill(pillBg)
                        .frame(width: 46, height: 46)
                        .overlay(
                            Image(systemName: "slider.vertical.3")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(iconTint)
                        )
                }
                .buttonStyle(M3BounceButtonStyle())
                
                // Speaker / Options button
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showSleepTimer = true
                } label: {
                    UnevenRoundedPillSide(topLeading: 5, bottomLeading: 5, bottomTrailing: 23, topTrailing: 23)
                        .fill(pillBg)
                        .frame(width: 46, height: 46)
                        .overlay(
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(iconTint)
                        )
                }
                .buttonStyle(M3BounceButtonStyle())
            }
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 6)
    }
    
    private func m3CoverArtworkView(coverSize: CGFloat, colors: LuneColorScheme) -> some View {
        ZStack {
            if settings.coverShape == .circle {
                VinylRecordView(
                    artworkData: player.currentSong?.artworkData,
                    isPlaying: player.isPlaying,
                    size: coverSize,
                    shape: .circle,
                    allowSpin: settings.vinylSpin
                )
                .frame(width: coverSize, height: coverSize)
            } else {
                let cornerRadius: CGFloat = (settings.coverShape == .square) ? 8 : 28
                
                ZStack {
                    if let data = player.currentSong?.artworkData, let img = UIImage(data: data) {
                        Image(uiImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: coverSize, height: coverSize)
                            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    } else {
                        ArtworkPlaceholderView(size: coverSize, cornerRadius: cornerRadius)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(colors.outlineVariant.opacity(0.30), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.40), radius: 24, x: 0, y: 10)
            }
        }
        .frame(width: coverSize, height: coverSize)
        .offset(x: coverDragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    coverDragOffset = value.translation.width * 0.4
                }
                .onEnded { value in
                    if value.translation.height > 60 && abs(value.translation.height) > abs(value.translation.width) {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        dismiss()
                    } else if value.translation.width > 60 {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        player.previous()
                    } else if value.translation.width < -60 {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        player.next()
                    }
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.7)) {
                        coverDragOffset = 0
                    }
                }
        )
    }
    
    private func m3TrackInfoRow(colors: LuneColorScheme) -> some View {
        let isDark = colors.isDark
        let badgePillBg = isDark ? Color.black.opacity(0.45) : Color.black.opacity(0.08)
        let iconTint = isDark ? Color.white.opacity(0.85) : Color(hex: 0x141414)
        
        return HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                // Song Title
                Text(player.currentSong?.title ?? "No Song Playing".localized)
                    .font(.custom("Quicksand-Bold", size: 24))
                    .foregroundColor(colors.onSurface)
                    .lineLimit(1)
                
                // Chips Row (Artist, Hi-Fi, Format)
                HStack(spacing: 6) {
                    Text(player.currentSong?.artist ?? "Unknown Artist".localized)
                        .font(.custom("Quicksand-Bold", size: 12))
                        .foregroundColor(colors.onSurface)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(isDark ? Color.white.opacity(0.14) : Color.black.opacity(0.08))
                        .clipShape(Capsule())
                        .lineLimit(1)
                    
                    if player.currentSong?.isHiFi == true {
                        Text("HI-FI")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(isDark ? Color(hex: 0x00E5FF) : Color(hex: 0x00838F))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(isDark ? Color(hex: 0x00E5FF).opacity(0.18) : Color(hex: 0x00838F).opacity(0.12))
                            .clipShape(Capsule())
                    }
                    
                    Text(player.currentSong?.isHiFi == true ? "FLAC" : "MP3")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(colors.onSurfaceVariant)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.06))
                        .clipShape(Capsule())
                }
            }
            
            Spacer(minLength: 8)
            
            // Right Action: Connected Split Pill [ Lyrics | Favorite ]
            HStack(spacing: 4) {
                // Lyrics Button
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        activeMode = (activeMode == .lyrics) ? .artwork : .lyrics
                    }
                } label: {
                    UnevenRoundedPillSide(topLeading: 24, bottomLeading: 24, bottomTrailing: 4, topTrailing: 4)
                        .fill(activeMode == .lyrics ? (isDark ? Color.white.opacity(0.25) : Color.black.opacity(0.18)) : badgePillBg)
                        .frame(width: 48, height: 48)
                        .overlay(
                            Image(systemName: "music.note.list")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(activeMode == .lyrics ? colors.onSurface : iconTint)
                        )
                }
                .buttonStyle(M3BounceButtonStyle())
                
                // Favorite Heart Button
                if let song = player.currentSong {
                    let isFav = library.allSongs.first(where: { $0.id == song.id })?.isFavorite ?? song.isFavorite
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        library.toggleFavorite(for: song)
                    } label: {
                        UnevenRoundedPillSide(topLeading: 4, bottomLeading: 4, bottomTrailing: 24, topTrailing: 24)
                            .fill(badgePillBg)
                            .frame(width: 48, height: 48)
                            .overlay(
                                Image(systemName: isFav ? "heart.fill" : "heart")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(isFav ? Color(hex: 0xEF4444) : iconTint)
                                    .scaleEffect(isFav ? 1.15 : 1.0)
                                    .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isFav)
                            )
                    }
                    .buttonStyle(M3BounceButtonStyle())
                }
            }
        }
    }
    
    private func m3ProgressSection(colors: LuneColorScheme) -> some View {
        let isDark = colors.isDark
        let sliderColor = isDark ? Color.white : Color(hex: 0x141414)
        let trackColor = isDark ? Color.white.opacity(0.24) : Color.black.opacity(0.18)
        let badgeBg = isDark ? Color.black.opacity(0.50) : Color.black.opacity(0.08)
        let badgeFg = isDark ? Color.white.opacity(0.90) : Color(hex: 0x141414)
        
        return VStack(spacing: 6) {
            M3WavyProgressIndicator(
                progress: Binding(
                    get: { Double(player.playbackProgress) },
                    set: { player.playbackProgress = Float($0) }
                ),
                isPlaying: player.isPlaying,
                isWavy: settings.progressBarWave,
                primaryColor: sliderColor,
                trackColor: trackColor
            ) { newProgress in
                player.seek(to: newProgress * player.duration)
            }
            
            // Timestamp Badges (1:1 with Android Lune Capsule Badges)
            HStack {
                Text(formatTime(player.currentTime))
                    .font(.custom("Quicksand-Bold", size: 11))
                    .foregroundColor(badgeFg)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(badgeBg)
                    .clipShape(Capsule())
                
                Spacer()
                
                Text(formatTime(player.duration))
                    .font(.custom("Quicksand-Bold", size: 11))
                    .foregroundColor(badgeFg)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(badgeBg)
                    .clipShape(Capsule())
            }
        }
    }
    
    private func m3ControlsRow(colors: LuneColorScheme) -> some View {
        let isDark = colors.isDark
        let playBtnBg = isDark ? Color.white : Color(hex: 0x141414)
        let playBtnFg = isDark ? Color.black : Color.white
        let skipBtnBg = isDark ? Color.black.opacity(0.40) : Color.black.opacity(0.08)
        let skipBtnFg = isDark ? Color.white : Color(hex: 0x141414)
        
        return HStack(spacing: 14) {
            // Previous Track: 68x68 Squircle Button with SkipPrevious (|<) icon
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                player.previous()
            } label: {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(skipBtnBg)
                    .frame(width: 68, height: 68)
                    .overlay(
                        Image(systemName: "backward.end.fill")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(skipBtnFg)
                    )
            }
            .buttonStyle(M3BounceButtonStyle())
            
            // Center Play/Pause Button: Large Horizontal Pill (96 -> 156 animated width on tap)
            // Solid clean pill with contrasting icon, NO glow
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                player.togglePlayPause()
                
                playStateWorkItem?.cancel()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                    showPlayStateLabel = true
                }
                let item = DispatchWorkItem {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        showPlayStateLabel = false
                    }
                }
                playStateWorkItem = item
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.3, execute: item)
            } label: {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(playBtnBg)
                    .frame(width: showPlayStateLabel ? 156 : 96, height: 68)
                    .overlay(
                        HStack(spacing: 8) {
                            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(playBtnFg)
                                .offset(x: player.isPlaying ? 0 : 2)
                            
                            if showPlayStateLabel {
                                Text(player.isPlaying ? "Play".localized : "Pause".localized)
                                    .font(.custom("Quicksand-Bold", size: 16))
                                    .foregroundColor(playBtnFg)
                                    .transition(.opacity.combined(with: .scale(scale: 0.85)))
                            }
                        }
                    )
            }
            .buttonStyle(M3BounceButtonStyle(scale: 0.92))
            
            // Next Track: 68x68 Squircle Button with SkipNext (>|) icon
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                player.next()
            } label: {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(skipBtnBg)
                    .frame(width: 68, height: 68)
                    .overlay(
                        Image(systemName: "forward.end.fill")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(skipBtnFg)
                    )
            }
            .buttonStyle(M3BounceButtonStyle())
        }
        .frame(maxWidth: .infinity)
    }
    
    private func m3OptionsRow(colors: LuneColorScheme) -> some View {
        HStack(spacing: 8) {
            // 1. Shuffle Option Pill (Material 3 Expressive)
            m3OptionPill(
                icon: "shuffle",
                label: "Shuffle",
                isActive: player.isShuffleEnabled,
                colors: colors
            ) {
                player.toggleShuffle()
            }
            
            // 2. Repeat Option Pill (Material 3 Expressive)
            m3OptionPill(
                icon: player.repeatMode == .one ? "repeat.1" : "repeat",
                label: "Repeat",
                isActive: player.repeatMode != .off,
                colors: colors
            ) {
                player.cycleRepeatMode()
            }
            
            // 3. Queue Option Pill (Material 3 Expressive)
            m3OptionPill(
                icon: "music.note.list",
                label: "Queue",
                isActive: showQueue,
                colors: colors
            ) {
                showQueue = true
            }
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
    }
    
    private func m3OptionPill(
        icon: String,
        label: String,
        isActive: Bool,
        colors: LuneColorScheme,
        action: @escaping () -> Void
    ) -> some View {
        let isDark = colors.isDark
        
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            HStack(spacing: 6) {
                ZStack {
                    if isActive {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(isDark ? Color.white : Color(hex: 0x141414))
                    } else {
                        Circle()
                            .fill(isDark ? Color.white.opacity(0.14) : Color.black.opacity(0.08))
                    }
                    
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: isActive ? .bold : .semibold))
                        .foregroundColor(isActive ? (isDark ? Color.black : Color.white) : colors.onSurface)
                }
                .frame(width: 28, height: 28)
                
                Text(label)
                    .font(.custom("Quicksand-Bold", size: 11.5))
                    .foregroundColor(isActive ? colors.onSurface : colors.onSurfaceVariant)
                    .lineLimit(1)
            }
            .padding(.leading, 6)
            .padding(.trailing, 8)
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(
                Group {
                    if isActive {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(isDark ? Color.white.opacity(0.22) : Color.black.opacity(0.10))
                    } else {
                        Capsule()
                            .fill(isDark ? Color.black.opacity(0.40) : Color.black.opacity(0.06))
                    }
                }
            )
        }
        .buttonStyle(M3BounceButtonStyle(scale: 0.95))
    }
    
    private func m3UtilityPill(
        icon: String,
        label: String,
        isActive: Bool,
        colors: LuneColorScheme,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(label)
                    .font(.custom("Quicksand-Bold", size: 12))
            }
            .foregroundColor(isActive ? colors.primary : colors.onSurfaceVariant)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isActive ? colors.primaryContainer : colors.surfaceContainerHigh)
            )
            .overlay(
                Capsule()
                    .stroke(isActive ? colors.primary.opacity(0.40) : colors.outlineVariant.opacity(0.25), lineWidth: 0.8)
            )
        }
        .buttonStyle(M3BounceButtonStyle())
    }
    
    private func m3LyricsContentView(colors: LuneColorScheme) -> some View {
        let isDark = colors.isDark
        let activeIdx = lyricsManager.findActiveLineIndex(
            lines: lyricsManager.lines,
            currentTime: player.currentTime + (lyricsOffsetMs / 1000.0)
        )
        
        return VStack(spacing: 8) {
            // Header Bar: Live Lyrics title + Sync badge + M3 Toolbar Pill
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Live Lyrics".localized)
                            .font(.custom("Quicksand-Bold", size: 17))
                            .foregroundColor(colors.onSurface)
                        
                        if lyricsManager.isSynced {
                            Text("SYNCED".localized)
                                .font(.custom("Quicksand-Bold", size: 8.5))
                                .foregroundColor(isDark ? Color.white.opacity(0.90) : Color.black.opacity(0.85))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(isDark ? Color.white.opacity(0.18) : Color.black.opacity(0.08))
                                )
                        }
                    }
                    
                    if lyricsOffsetMs != 0 {
                        Text("Offset: %+.1fs".localized(lyricsOffsetMs / 1000.0))
                            .font(.custom("Quicksand-Medium", size: 11))
                            .foregroundColor(colors.onSurfaceVariant)
                    }
                }
                
                Spacer()
                
                // M3 Divided Toolbar Pill: [ Alignment | Offset ] + Close button
                HStack(spacing: 6) {
                    HStack(spacing: 0) {
                        // 1. Text Alignment Toggle
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.70)) {
                                lyricsAlignment = (lyricsAlignment == .leading) ? .center : .leading
                            }
                        } label: {
                            Image(systemName: lyricsAlignment == .leading ? "text.alignleft" : "text.aligncenter")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(colors.onSurface)
                                .frame(width: 32, height: 32)
                        }
                        .buttonStyle(M3BounceButtonStyle(scale: 0.92))
                        
                        // Divider
                        Rectangle()
                            .fill(isDark ? Color.white.opacity(0.20) : Color.black.opacity(0.14))
                            .frame(width: 1, height: 14)
                        
                        // 2. Timing Offset Toggle
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.75)) {
                                showLyricsOffsetBar.toggle()
                            }
                        } label: {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(showLyricsOffsetBar ? (isDark ? Color.black : Color.white) : colors.onSurface)
                                .frame(width: 32, height: 32)
                                .background(
                                    Group {
                                        if showLyricsOffsetBar {
                                            Circle().fill(colors.onSurface)
                                        } else {
                                            Color.clear
                                        }
                                    }
                                )
                        }
                        .buttonStyle(M3BounceButtonStyle(scale: 0.92))
                    }
                    .padding(.horizontal, 3)
                    .frame(height: 34)
                    .background(
                        Capsule()
                            .fill(isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.08))
                            .overlay(
                                Capsule()
                                    .stroke(isDark ? Color.white.opacity(0.16) : Color.black.opacity(0.10), lineWidth: 0.8)
                            )
                    )
                    
                    // 3. Close Lyrics / Back to Cover
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            activeMode = .artwork
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(colors.onSurface)
                            .frame(width: 34, height: 34)
                            .background(
                                Circle()
                                    .fill(isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.08))
                            )
                    }
                    .buttonStyle(M3BounceButtonStyle(scale: 0.92))
                }
            }
            .padding(.horizontal, 16)
            
            // Collapsible Sync Offset Control Bar (1:1 Android Lune Timing Adjustment)
            if showLyricsOffsetBar {
                HStack(spacing: 6) {
                    lyricsOffsetButton(label: "-0.5s", colors: colors) { lyricsOffsetMs -= 500 }
                    lyricsOffsetButton(label: "-0.1s", colors: colors) { lyricsOffsetMs -= 100 }
                    
                    if lyricsOffsetMs != 0 {
                        Button("Reset") {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation { lyricsOffsetMs = 0 }
                        }
                        .font(.custom("Quicksand-Bold", size: 10.5))
                        .foregroundColor(colors.onSurface)
                        .padding(.horizontal, 6)
                    }
                    
                    Spacer()
                    
                    lyricsOffsetButton(label: "+0.1s", colors: colors) { lyricsOffsetMs += 100 }
                    lyricsOffsetButton(label: "+0.5s", colors: colors) { lyricsOffsetMs += 500 }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(isDark ? Color(hex: 0x1E1E1E) : Color(hex: 0xEAEAEA))
                )
                .padding(.horizontal, 16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            // Lyrics Lines Body with Masked Top/Bottom Fade
            if lyricsManager.isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(colors.onSurface)
                        .scaleEffect(1.1)
                    Text("Searching lyrics...".localized)
                        .font(.custom("Quicksand-Bold", size: 13))
                        .foregroundColor(colors.onSurfaceVariant)
                }
                .frame(maxHeight: .infinity)
            } else if lyricsManager.lines.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "quote.bubble")
                        .font(.system(size: 34))
                        .foregroundColor(colors.onSurfaceVariant.opacity(0.50))
                    Text("No lyrics available".localized)
                        .font(.custom("Quicksand-Bold", size: 15))
                        .foregroundColor(colors.onSurface)
                    Button {
                        if let s = player.currentSong {
                            Task { await lyricsManager.fetchLyrics(for: s) }
                        }
                    } label: {
                        Text("Search Again".localized)
                            .font(.custom("Quicksand-Bold", size: 12))
                            .foregroundColor(isDark ? Color.black : Color.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(isDark ? Color.white : Color(hex: 0x141414))
                            )
                    }
                    .buttonStyle(M3BounceButtonStyle())
                }
                .frame(maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: lyricsAlignment == .center ? .center : .leading, spacing: 18) {
                            Spacer(minLength: 20)
                            
                            ForEach(Array(lyricsManager.lines.enumerated()), id: \.element.id) { index, line in
                                let isActive = activeIdx == index
                                
                                Button {
                                    if line.timestamp >= 0 {
                                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                        player.seek(to: max(0, line.timestamp - (lyricsOffsetMs / 1000.0)))
                                    }
                                } label: {
                                    Text(line.text)
                                        .font(.custom("Quicksand-Bold", size: isActive ? 24 : 20))
                                        .foregroundColor(
                                            isActive
                                                ? colors.onSurface
                                                : colors.onSurface.opacity(0.32)
                                        )
                                        .multilineTextAlignment(lyricsAlignment)
                                        .frame(maxWidth: .infinity, alignment: lyricsAlignment == .center ? .center : .leading)
                                        .scaleEffect(isActive ? 1.08 : 1.0, anchor: lyricsAlignment == .center ? .center : .leading)
                                        .shadow(
                                            color: isActive ? (isDark ? Color.white.opacity(0.35) : Color.black.opacity(0.12)) : Color.clear,
                                            radius: isActive ? 8 : 0,
                                            x: 0,
                                            y: 0
                                        )
                                        .padding(.horizontal, 24)
                                        .padding(.vertical, 6)
                                        .animation(.spring(response: 0.35, dampingFraction: 0.65), value: isActive)
                                }
                                .buttonStyle(.plain)
                                .id(index)
                            }
                            
                            Spacer(minLength: 40)
                        }
                    }
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0.0),
                                .init(color: .black, location: 0.08),
                                .init(color: .black, location: 0.88),
                                .init(color: .clear, location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .onChange(of: activeIdx) { _, newIndex in
                        if let idx = newIndex {
                            withAnimation(.easeInOut(duration: 0.40)) {
                                proxy.scrollTo(idx, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func lyricsOffsetButton(label: String, colors: LuneColorScheme, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.25, dampingFraction: 0.70)) {
                action()
            }
        } label: {
            Text(label)
                .font(.custom("Quicksand-Bold", size: 11))
                .foregroundColor(colors.onSurface)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(colors.isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.08))
                )
        }
        .buttonStyle(M3BounceButtonStyle(scale: 0.94))
    }
    
    // MARK: - 1. Top Header Bar
    private var topHeaderBar: some View {
        HStack {
            // Dismiss Chevron Button
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white.opacity(0.85))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // Header Context Pill (Album / Lyrics)
            VStack(spacing: 2) {
                if activeMode == .lyrics {
                    Text("LIVE LYRICS".localized)
                        .font(.custom("Quicksand-Bold", size: 11))
                        .foregroundColor(.white.opacity(0.70))
                        .tracking(1.4)
                } else if let song = player.currentSong {
                    Text(song.album.isEmpty ? "PLAYING FROM LIBRARY".localized : song.album.uppercased())
                        .font(.custom("Quicksand-Bold", size: 10))
                        .foregroundColor(.white.opacity(0.60))
                        .tracking(1.2)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Options Menu Button (Ellipsis)
            Menu {
                if let song = player.currentSong {
                    let isFav = library.allSongs.first(where: { $0.id == song.id })?.isFavorite ?? song.isFavorite
                    Button {
                        library.toggleFavorite(for: song)
                    } label: {
                        Label(isFav ? "Remove from Favorites".localized : "Add to Favorites".localized, systemImage: isFav ? "heart.slash" : "heart")
                    }
                }
                
                Button {
                    showEqualizer = true
                } label: {
                    Label("Equalizer & Sound FX".localized, systemImage: "slider.vertical.3")
                }
                
                Button {
                    showSleepTimer = true
                } label: {
                    Label(player.sleepTimerMinutesRemaining != nil ? "\("Sleep Timer".localized): \(player.sleepTimerMinutesRemaining!)m" : "Sleep Timer".localized, systemImage: "moon.zzz")
                }
                
                Divider()
                
                if let song = player.currentSong {
                    Section("Audio Fidelity".localized) {
                        Text("Format: %@".localized(song.format.uppercased()))
                        if let sr = song.sampleRate {
                            Text("Sample Rate: %.1f kHz".localized(Double(sr) / 1000.0))
                        }
                        if let bd = song.bitDepth {
                            Text("Depth: %d-bit".localized(bd))
                        }
                        if let br = song.bitrate, br > 0 {
                            Text("Bitrate: %d kbps".localized(br))
                        }
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
        }
    }
    
    // MARK: - 2A. Album Artwork Mode Content
    private func artworkContentView(coverSize: CGFloat, isCompact: Bool) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 4)
            
            // Hero Artwork (Centered Continuous Squircle)
            ZStack {
                if let data = player.currentSong?.artworkData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: coverSize, height: coverSize)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                } else {
                    ArtworkPlaceholderView(size: coverSize, cornerRadius: 24)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 0.8)
            )
            .shadow(color: Color.black.opacity(0.40), radius: 22, x: 0, y: 14)
            .scaleEffect(player.isPlaying ? 1.0 : 0.88)
            .offset(x: coverDragOffset)
            .animation(.spring(response: 0.40, dampingFraction: 0.75), value: player.isPlaying)
            .gesture(
                DragGesture(minimumDistance: 25)
                    .onChanged { val in
                        coverDragOffset = val.translation.width * 0.4
                    }
                    .onEnded { val in
                        let threshold: CGFloat = 50
                        if val.translation.width < -threshold {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            player.next()
                        } else if val.translation.width > threshold {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            player.previous()
                        }
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            coverDragOffset = 0
                        }
                    }
            )
            
            Spacer(minLength: isCompact ? 12 : 20)
            
            // Track Info Row: Title, Artist, Lossless Badge, and Heart
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(player.currentSong?.title ?? "No Song Playing".localized)
                        .font(.custom("Quicksand-Bold", size: isCompact ? 20 : 22))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        Text(player.currentSong?.artist ?? "Select a track to play".localized)
                            .font(.custom("Quicksand-Medium", size: isCompact ? 14 : 16))
                            .foregroundColor(.white.opacity(0.65))
                            .lineLimit(1)
                        
                        if let song = player.currentSong {
                            Text(song.isHiRes ? "HI-RES LOSSLESS".localized : "LOSSLESS".localized)
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white.opacity(0.70))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .fill(Color.white.opacity(0.14))
                                )
                        }
                    }
                }
                
                Spacer()
                
                // Favorite Heart Button
                if let song = player.currentSong {
                    let isFav = library.allSongs.first(where: { $0.id == song.id })?.isFavorite ?? song.isFavorite
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        library.toggleFavorite(for: song)
                    } label: {
                        Image(systemName: isFav ? "heart.fill" : "heart")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(isFav ? Color(hex: 0xEF4444) : .white.opacity(0.85))
                            .scaleEffect(isFav ? 1.15 : 1.0)
                            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isFav)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)
            
            Spacer(minLength: 4)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - 2B. Apple Music Live Synced Lyrics Mode Content
    private var lyricsContentView: some View {
        VStack(spacing: 8) {
            // Mini Header Bar: Artwork Thumbnail + Title + Artist + Close
            HStack(spacing: 12) {
                if let data = player.currentSong?.artworkData, let img = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(color: Color.black.opacity(0.30), radius: 6, x: 0, y: 3)
                } else {
                    ArtworkPlaceholderView(size: 44, cornerRadius: 12)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(player.currentSong?.title ?? "Unknown Title".localized)
                        .font(.custom("Quicksand-Bold", size: 16))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        Text(player.currentSong?.artist ?? "Unknown Artist".localized)
                            .font(.custom("Quicksand-Medium", size: 13))
                            .foregroundColor(.white.opacity(0.65))
                            .lineLimit(1)
                        
                        if lyricsManager.isSynced {
                            Text("SYNCED".localized)
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white.opacity(0.75))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(Capsule().fill(Color.white.opacity(0.15)))
                        }
                    }
                }
                
                Spacer()
                
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.75)) {
                        activeMode = .artwork
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.70))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 4)
            
            // Apple Music Scrolling Karaoke Body with Gradient Fade Mask
            if lyricsManager.isLoading {
                Spacer()
                VStack(spacing: 14) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                    Text("Fetching lyrics from Vagalume...".localized)
                        .font(.custom("Quicksand-Bold", size: 14))
                        .foregroundColor(.white.opacity(0.75))
                }
                Spacer()
            } else if lyricsManager.lines.isEmpty {
                Spacer()
                VStack(spacing: 14) {
                    Image(systemName: "quote.bubble")
                        .font(.system(size: 42))
                        .foregroundColor(.white.opacity(0.40))
                    Text("No lyrics available".localized)
                        .font(.custom("Quicksand-Bold", size: 17))
                        .foregroundColor(.white)
                    Button {
                        if let song = player.currentSong {
                            Task { await lyricsManager.fetchLyrics(for: song) }
                        }
                    } label: {
                        Label("Search Again".localized, systemImage: "arrow.clockwise")
                            .font(.custom("Quicksand-Bold", size: 13))
                            .foregroundColor(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .liquidGlass(.regular, in: Capsule())
                    }
                }
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 24) {
                            Spacer(minLength: 24)
                            
                            let activeIdx = lyricsManager.findActiveLineIndex(lines: lyricsManager.lines, currentTime: player.currentTime)
                            
                            ForEach(Array(lyricsManager.lines.enumerated()), id: \.element.id) { index, line in
                                let isActive = activeIdx == index
                                
                                Button {
                                    if line.timestamp >= 0 {
                                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                        player.seek(to: line.timestamp)
                                    }
                                } label: {
                                    Text(line.text)
                                        .font(.custom("Quicksand-Bold", size: 24))
                                        .foregroundColor(isActive ? Color.white : Color.white.opacity(0.35))
                                        .multilineTextAlignment(.leading)
                                        .scaleEffect(isActive ? 1.02 : 1.0, anchor: .leading)
                                        .shadow(color: isActive ? Color.white.opacity(0.35) : Color.clear, radius: 8, x: 0, y: 0)
                                        .padding(.horizontal, 28)
                                        .padding(.vertical, 6)
                                        .animation(.easeInOut(duration: 0.28), value: isActive)
                                }
                                .buttonStyle(.plain)
                                .id(index)
                            }
                            
                            Spacer(minLength: 50)
                        }
                    }
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0.0),
                                .init(color: .black, location: 0.07),
                                .init(color: .black, location: 0.88),
                                .init(color: .clear, location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .onChange(of: lyricsManager.findActiveLineIndex(lines: lyricsManager.lines, currentTime: player.currentTime)) { _, newIndex in
                        if let idx = newIndex {
                            withAnimation(.easeInOut(duration: 0.45)) {
                                proxy.scrollTo(idx, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - 3. Apple Music Scrubber Bar & Timestamps
    private var scrubberSection: some View {
        VStack(spacing: 6) {
            GeometryReader { scrubGeo in
                let scrubWidth = max(1, scrubGeo.size.width)
                let currentProgress = isDraggingScrubber ? dragScrubProgress : Double(player.playbackProgress)
                let activeWidth = scrubWidth * CGFloat(max(0, min(1, currentProgress)))
                
                ZStack(alignment: .leading) {
                    // Background track
                    Capsule()
                        .fill(Color.white.opacity(0.20))
                        .frame(height: 5)
                    
                    // Active Fill track
                    Capsule()
                        .fill(Color.white)
                        .frame(width: max(5, activeWidth), height: 5)
                    
                    // Scrub Thumb Knob
                    Circle()
                        .fill(Color.white)
                        .frame(width: isDraggingScrubber ? 16 : 10, height: isDraggingScrubber ? 16 : 10)
                        .shadow(color: Color.black.opacity(0.35), radius: 3, x: 0, y: 1)
                        .offset(x: max(0, min(scrubWidth - (isDraggingScrubber ? 16 : 10), activeWidth - (isDraggingScrubber ? 8 : 5))))
                }
                .frame(height: 24)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { val in
                            isDraggingScrubber = true
                            let pct = max(0, min(1, Double(val.location.x / scrubWidth)))
                            dragScrubProgress = pct
                        }
                        .onEnded { val in
                            let pct = max(0, min(1, Double(val.location.x / scrubWidth)))
                            dragScrubProgress = pct
                            isDraggingScrubber = false
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            player.seek(to: pct * player.duration)
                        }
                )
            }
            .frame(height: 24)
            
            // Timestamps: Elapsed (left) & Remaining (right)
            HStack {
                let currentSeconds = isDraggingScrubber ? (dragScrubProgress * player.duration) : player.currentTime
                Text(formatTime(currentSeconds))
                    .font(.custom("Quicksand-Bold", size: 12))
                    .foregroundColor(.white.opacity(0.65))
                
                Spacer()
                
                let remaining = max(0, player.duration - currentSeconds)
                Text("-" + formatTime(remaining))
                    .font(.custom("Quicksand-Bold", size: 12))
                    .foregroundColor(.white.opacity(0.65))
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - 4. Apple Music Bare Playback Controls (All 5 Centered)
    private var controlsRow: some View {
        HStack(spacing: 0) {
            // Shuffle
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                player.toggleShuffle()
            } label: {
                Image(systemName: "shuffle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(player.isShuffleEnabled ? primaryColor : .white.opacity(0.60))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // Previous Track
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                player.previous()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // Play / Pause Button (Apple Music Bare Hero Icon)
            Button {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                player.togglePlayPause()
            } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 46, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 64, height: 64)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // Next Track
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                player.next()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // Repeat Mode
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                player.cycleRepeatMode()
            } label: {
                Image(systemName: player.repeatMode.iconName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(player.repeatMode != .off ? primaryColor : .white.opacity(0.60))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - 5. Apple Music Inline Volume Slider
    private var volumeSliderSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "speaker.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.50))
                .frame(width: 16)
            
            GeometryReader { volGeo in
                let volWidth = max(1, volGeo.size.width)
                let currentVol = isDraggingVolume ? dragVolume : player.volume
                let activeVolWidth = volWidth * CGFloat(max(0, min(1, currentVol)))
                
                ZStack(alignment: .leading) {
                    // Background
                    Capsule()
                        .fill(Color.white.opacity(0.20))
                        .frame(height: 4)
                    
                    // Fill
                    Capsule()
                        .fill(Color.white.opacity(0.85))
                        .frame(width: max(4, activeVolWidth), height: 4)
                    
                    // Knob
                    Circle()
                        .fill(Color.white)
                        .frame(width: 12, height: 12)
                        .shadow(color: Color.black.opacity(0.35), radius: 2, x: 0, y: 1)
                        .offset(x: max(0, min(volWidth - 12, activeVolWidth - 6)))
                }
                .frame(height: 20)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { val in
                            isDraggingVolume = true
                            let pct = Float(max(0, min(1, val.location.x / volWidth)))
                            dragVolume = pct
                            player.volume = pct
                        }
                        .onEnded { val in
                            let pct = Float(max(0, min(1, val.location.x / volWidth)))
                            dragVolume = pct
                            player.volume = pct
                            isDraggingVolume = false
                        }
                )
            }
            .frame(height: 20)
            
            Image(systemName: "speaker.wave.3.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.50))
                .frame(width: 16)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - 6. Apple Music Bottom Action Bar
    private var bottomUtilityDock: some View {
        HStack {
            // Lyrics Toggle
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation(.spring(response: 0.38, dampingFraction: 0.75)) {
                    activeMode = (activeMode == .lyrics) ? .artwork : .lyrics
                }
            } label: {
                Image(systemName: activeMode == .lyrics ? "quote.bubble.fill" : "quote.bubble")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(activeMode == .lyrics ? .white : .white.opacity(0.65))
                    .frame(width: 44, height: 44)
                    .background(
                        Group {
                            if activeMode == .lyrics {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.white.opacity(0.25))
                            }
                        }
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // Equalizer Button
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showEqualizer = true
            } label: {
                Image(systemName: "slider.vertical.3")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white.opacity(0.65))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // Up Next Queue Button
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showQueue = true
            } label: {
                Image(systemName: "list.bullet")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white.opacity(0.65))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Dynamic Blurred Artwork Backdrop (Lightweight & Strictly Constrained)
    @ViewBuilder
    private func backgroundBackdrop(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            Color.black
            
            if let data = player.currentSong?.artworkData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: height)
                    .clipped()
                    .blur(radius: 40)
                    .opacity(0.65)
            } else {
                LinearGradient(
                    colors: [
                        primaryColor.opacity(0.35),
                        Color(hex: 0x141022),
                        Color.black
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            
            // Dark vignette overlay for Apple Music high-contrast readability
            LinearGradient(
                colors: [
                    Color.black.opacity(0.40),
                    Color.black.opacity(0.65),
                    Color.black.opacity(0.85)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .frame(width: width, height: height)
        .clipped()
        .allowsHitTesting(false)
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        guard !seconds.isNaN && !seconds.isInfinite && seconds >= 0 else { return "0:00" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - M3 Expressive Split Pill Shape
struct UnevenRoundedPillSide: Shape {
    let topLeading: CGFloat
    let bottomLeading: CGFloat
    let bottomTrailing: CGFloat
    let topTrailing: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let tl = topLeading
        let bl = bottomLeading
        let bt = bottomTrailing
        let tt = topTrailing
        
        path.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - tt, y: rect.minY))
        path.addArc(center: CGPoint(x: rect.maxX - tt, y: rect.minY + tt), radius: tt, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bt))
        path.addArc(center: CGPoint(x: rect.maxX - bt, y: rect.maxY - bt), radius: bt, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
        path.addArc(center: CGPoint(x: rect.minX + bl, y: rect.maxY - bl), radius: bl, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
        path.addArc(center: CGPoint(x: rect.minX + tl, y: rect.minY + tl), radius: tl, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        path.closeSubpath()
        return path
    }
}
