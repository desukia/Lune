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
    @ObservedObject private var library = MusicLibraryManager.shared
    @ObservedObject private var lyricsManager = LyricsManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    private var primaryColor: Color {
        settings.resolveColors(for: colorScheme).primary
    }
    
    @State private var activeMode: NowPlayingMode = .artwork
    @State private var showQueue: Bool = false
    @State private var showEqualizer: Bool = false
    @State private var showSleepTimer: Bool = false
    
    // Scrubber drag state
    @State private var isDraggingScrubber: Bool = false
    @State private var dragScrubProgress: Double = 0.0
    
    // Volume drag state
    @State private var isDraggingVolume: Bool = false
    @State private var dragVolume: Float = 1.0
    
    // Cover artwork drag state
    @State private var coverDragOffset: CGFloat = 0.0
    
    @MainActor
    public init(
        player: AudioPlayerManager = .shared,
        settings: SettingsManager = .shared
    ) {
        self.player = player
        self.settings = settings
    }
    
    public var body: some View {
        GeometryReader { geo in
            let screenWidth = geo.size.width
            let screenHeight = geo.size.height
            let isCompact = screenHeight < 720
            
            // Dynamic Cover Size strictly proportionate to screen width
            let coverSize = min(screenWidth - 64, isCompact ? 220 : min(screenHeight * 0.36, 300))
            
            ZStack(alignment: .center) {
                // 0. Apple Music Dynamic Ambient Blurred Artwork Backdrop (strictly sized to screen)
                backgroundBackdrop(width: screenWidth, height: screenHeight)
                
                // 1. Content Column strictly sized and centered
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
                    
                    // Top Header Bar (Comfortably positioned below Dynamic Island / Status Bar)
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
                    
                    // Middle Body: Switch between Album Artwork and Live Synced Lyrics
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
                    
                    // Bare Playback Controls (All 5 centered across screenWidth)
                    controlsRow
                        .padding(.horizontal, 24)
                        .frame(width: screenWidth)
                    
                    Spacer(minLength: isCompact ? 10 : 16)
                    
                    // Inline Volume Slider
                    volumeSliderSection
                        .padding(.horizontal, 32)
                        .frame(width: screenWidth)
                    
                    Spacer(minLength: isCompact ? 12 : 20)
                    
                    // Bottom Action Bar (Lyrics, Equalizer, Queue)
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
        .ignoresSafeArea()
        .sheet(isPresented: $showQueue) {
            QueueView(player: player, primaryColor: primaryColor)
        }
        .sheet(isPresented: $showEqualizer) {
            EqualizerView(primaryColor: primaryColor)
        }
        .confirmationDialog("Sleep Timer", isPresented: $showSleepTimer, titleVisibility: .visible) {
            Button("15 Minutes") { player.setSleepTimer(minutes: 15) }
            Button("30 Minutes") { player.setSleepTimer(minutes: 30) }
            Button("45 Minutes") { player.setSleepTimer(minutes: 45) }
            Button("60 Minutes") { player.setSleepTimer(minutes: 60) }
            if player.sleepTimerMinutesRemaining != nil {
                Button("Turn Off Timer", role: .destructive) { player.setSleepTimer(minutes: 0) }
            }
            Button("Cancel", role: .cancel) {}
        }
        .task(id: player.currentSong?.id) {
            if let song = player.currentSong {
                await lyricsManager.fetchLyrics(for: song)
            }
        }
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
                    Text("LYRICS")
                        .font(.custom("Quicksand-Bold", size: 11))
                        .foregroundColor(.white.opacity(0.70))
                        .tracking(1.4)
                } else if let song = player.currentSong {
                    Text(song.album.isEmpty ? "PLAYING FROM LIBRARY" : song.album.uppercased())
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
                        Label(isFav ? "Remove from Favorites" : "Add to Favorites", systemImage: isFav ? "heart.slash" : "heart")
                    }
                }
                
                Button {
                    showEqualizer = true
                } label: {
                    Label("Equalizer & Sound FX", systemImage: "slider.vertical.3")
                }
                
                Button {
                    showSleepTimer = true
                } label: {
                    Label(player.sleepTimerMinutesRemaining != nil ? "Sleep Timer: \(player.sleepTimerMinutesRemaining!)m remaining" : "Sleep Timer", systemImage: "moon.zzz")
                }
                
                Divider()
                
                if let song = player.currentSong {
                    Section("Audio Fidelity") {
                        Text("Format: \(song.format.uppercased())")
                        if let sr = song.sampleRate {
                            Text(String(format: "Sample Rate: %.1f kHz", Double(sr) / 1000.0))
                        }
                        if let bd = song.bitDepth {
                            Text("Depth: \(bd)-bit")
                        }
                        if let br = song.bitrate, br > 0 {
                            Text("Bitrate: \(br) kbps")
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
                    Text(player.currentSong?.title ?? "No Song Playing")
                        .font(.custom("Quicksand-Bold", size: isCompact ? 20 : 22))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        Text(player.currentSong?.artist ?? "Select a track to play")
                            .font(.custom("Quicksand-Medium", size: isCompact ? 14 : 16))
                            .foregroundColor(.white.opacity(0.65))
                            .lineLimit(1)
                        
                        if let song = player.currentSong {
                            Text(song.isHiRes ? "HI-RES LOSSLESS" : "LOSSLESS")
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
                    Text(player.currentSong?.title ?? "Unknown Title")
                        .font(.custom("Quicksand-Bold", size: 16))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        Text(player.currentSong?.artist ?? "Unknown Artist")
                            .font(.custom("Quicksand-Medium", size: 13))
                            .foregroundColor(.white.opacity(0.65))
                            .lineLimit(1)
                        
                        if lyricsManager.isSynced {
                            Text("SYNCED")
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
                    Text("Fetching lyrics from Vagalume...")
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
                    Text("No lyrics available")
                        .font(.custom("Quicksand-Bold", size: 17))
                        .foregroundColor(.white)
                    Button {
                        if let song = player.currentSong {
                            Task { await lyricsManager.fetchLyrics(for: song) }
                        }
                    } label: {
                        Label("Search Again", systemImage: "arrow.clockwise")
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
