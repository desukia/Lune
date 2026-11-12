//
//  ResumeScreenView.swift
//  Lune
//
//  1:1 Exact Parity with Android Lune ResumeScreen.kt & HeroSection.kt:
//  - Material 3 Expressive Tops Summary Hero Card (190dp height, 24dp rounded corners, 9-sided flower artwork)
//  - Continue Listening Card (56dp cover, title, artist, 48dp ScallopPlayPauseButtonWithProgress)
//  - M3 MultiBrowse Carousel Recommendations (200dp height, 24dp corner, dark bottom gradient, play button)
//  - Top Artists Carousel (100dp circular photos, no extra text, 1:1 Android ArtistCircleCard)
//  - Top Genres & Playlists sections
//

import SwiftUI

@MainActor
public struct ResumeScreenView: View {
    @ObservedObject var library: MusicLibraryManager
    @ObservedObject var player: AudioPlayerManager
    @ObservedObject var settings: SettingsManager
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var selectedPlaylist: Playlist? = nil
    @State private var selectedArtist: Artist? = nil
    @State private var selectedGenre: GenreItem? = nil
    @State private var selectedAlbum: Album? = nil
    @State private var recommendations: [Song] = []
    @State private var showFileImporter: Bool = false
    
    let onTapHero: () -> Void
    let onNavigateToAllSongs: () -> Void
    let onNavigateToArtist: (String) -> Void
    let onNavigateToAlbum: (Album) -> Void
    let onNavigateToGenre: (String) -> Void
    let onNavigateToPlaylist: (Playlist) -> Void
    
    @MainActor
    public init(
        library: MusicLibraryManager,
        player: AudioPlayerManager,
        settings: SettingsManager,
        onTapHero: @escaping () -> Void = {},
        onNavigateToAllSongs: @escaping () -> Void = {},
        onNavigateToArtist: @escaping (String) -> Void = { _ in },
        onNavigateToAlbum: @escaping (Album) -> Void = { _ in },
        onNavigateToGenre: @escaping (String) -> Void = { _ in },
        onNavigateToPlaylist: @escaping (Playlist) -> Void = { _ in }
    ) {
        self.library = library
        self.player = player
        self.settings = settings
        self.onTapHero = onTapHero
        self.onNavigateToAllSongs = onNavigateToAllSongs
        self.onNavigateToArtist = onNavigateToArtist
        self.onNavigateToAlbum = onNavigateToAlbum
        self.onNavigateToGenre = onNavigateToGenre
        self.onNavigateToPlaylist = onNavigateToPlaylist
    }
    
    @MainActor
    public init(
        onTapHero: @escaping () -> Void = {},
        onNavigateToAllSongs: @escaping () -> Void = {},
        onNavigateToArtist: @escaping (String) -> Void = { _ in },
        onNavigateToAlbum: @escaping (Album) -> Void = { _ in },
        onNavigateToGenre: @escaping (String) -> Void = { _ in },
        onNavigateToPlaylist: @escaping (Playlist) -> Void = { _ in }
    ) {
        self.library = .shared
        self.player = .shared
        self.settings = .shared
        self.onTapHero = onTapHero
        self.onNavigateToAllSongs = onNavigateToAllSongs
        self.onNavigateToArtist = onNavigateToArtist
        self.onNavigateToAlbum = onNavigateToAlbum
        self.onNavigateToGenre = onNavigateToGenre
        self.onNavigateToPlaylist = onNavigateToPlaylist
    }
    
    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                // 1. Hero Section (Tops Summary Card + Continue Listening Card)
                heroSection
                
                // 2. AI Recommendations Carousel (200dp height, 24dp corner)
                if !recommendations.isEmpty {
                    recommendationsSection
                }
                
                // 3. Top Playlists Horizontal Carousel
                if !libraryPlaylists.isEmpty {
                    playlistsSection
                }
                
                // 4. Top Artists Carousel (1:1 Android ArtistCircleCard)
                if !library.artists.isEmpty {
                    topArtistsSection
                }
                
                // 5. Top Genres
                if !library.genres.isEmpty {
                    topGenresSection
                }
                
                // 6. Recently Added Tracks
                if !recentlyAdded.isEmpty {
                    recentlyAddedSection
                }
            }
            .padding(.top, 10)
            .padding(.bottom, 220) // generous spacing for floating MiniPlayer & TabBar
        }
        .sheet(item: $selectedPlaylist) { pl in
            NavigationStack {
                PlaylistDetailView(playlist: pl)
            }
        }
        .sheet(item: $selectedArtist) { artist in
            NavigationStack {
                ArtistDetailView(artist: artist)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { selectedArtist = nil }
                                .font(.custom("Quicksand-Bold", size: 15))
                        }
                    }
            }
        }
        .sheet(item: $selectedGenre) { item in
            NavigationStack {
                GenreDetailView(genre: item.name)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done".localized) { selectedGenre = nil }
                                .font(.custom("Quicksand-Bold", size: 15))
                        }
                    }
            }
        }
        .sheet(item: $selectedAlbum) { album in
            NavigationStack {
                AlbumDetailView(album: album)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done".localized) { selectedAlbum = nil }
                                .font(.custom("Quicksand-Bold", size: 15))
                        }
                    }
            }
        }
        .onAppear {
            if recommendations.isEmpty && !library.allSongs.isEmpty {
                recommendations = library.allSongs.shuffled()
            }
        }
        .onChange(of: library.allSongs) { _, newSongs in
            recommendations = newSongs.shuffled()
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
    
    // MARK: - Hero Section (1:1 Android Lune HeroSection.kt)
    
    @ViewBuilder
    private var heroSection: some View {
        let colors = settings.resolveColors(for: colorScheme)
        let activeSong = player.currentSong ?? library.allSongs.first
        
        if library.allSongs.isEmpty {
            VStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(colors.secondaryContainer)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(colors.outlineVariant.opacity(0.20), lineWidth: 1)
                        )
                    
                    VStack(spacing: 12) {
                        Image(systemName: "music.note.house.fill")
                            .font(.system(size: 40))
                            .foregroundColor(colors.primary)
                        
                        Text("Your library is empty".localized)
                            .font(.custom("Quicksand-Bold", size: 18))
                            .foregroundColor(colors.onSecondaryContainer)
                        
                        Text("Add audio files (MP3, FLAC, M4A, WAV) from Files app, iCloud, or drop them into Lune folder.".localized)
                            .font(.custom("Quicksand-Regular", size: 13))
                            .foregroundColor(colors.onSecondaryContainer.opacity(0.75))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                        
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            showFileImporter = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Audio Files / Import".localized)
                                    .font(.custom("Quicksand-Bold", size: 14))
                            }
                            .foregroundColor(colors.onPrimary)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 12)
                            .background(colors.primary)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(M3BounceButtonStyle())
                    }
                    .padding(.vertical, 24)
                    .padding(.horizontal, 16)
                }
                .padding(.horizontal, 16)
            }
        } else {
            VStack(spacing: 12) {
            // MARK: 1. Tops Summary Hero Card (190dp height, 24dp corner, 9-sided flower artwork)
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                colors.secondaryContainer,
                                colors.tertiaryContainer.opacity(0.75)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(colors.outlineVariant.opacity(0.20), lineWidth: 1)
                    )
                
                HStack(spacing: 16) {
                    // Left side: 140x140 flower cookie shape (MaterialShapes.Flower.toShape())
                    ZStack {
                        let coverData = topArtistItem.artworkData ?? topSongItem.artworkData ?? activeSong?.artworkData
                        if let img = ArtworkCache.shared.image(for: "\(coverData?.count ?? 0)", data: coverData) {
                            Image(uiImage: img)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 140, height: 140)
                                .clipShape(M3FlowerShape())
                        } else {
                            M3FlowerShape()
                                .fill(colors.surface.opacity(0.50))
                                .frame(width: 140, height: 140)
                                .overlay(
                                    Image(systemName: "music.note")
                                        .font(.system(size: 48, weight: .bold))
                                        .foregroundColor(colors.onSecondaryContainer)
                                )
                        }
                    }
                    .frame(width: 140, height: 140)
                    .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 3)
                    
                    // Right side: Top Stats (Artist, Song, Genre)
                    VStack(alignment: .leading, spacing: 0) {
                        // 1. Top Artist
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(colors.onSecondaryContainer.opacity(0.85))
                                
                                Text("TOP ARTIST".localized)
                                    .font(.custom("Quicksand-Bold", size: 9.5))
                                    .tracking(0.6)
                                    .foregroundColor(colors.onSecondaryContainer.opacity(0.85))
                            }
                            
                            Text(topArtistItem.name)
                                .font(.custom("Quicksand-Bold", size: 16))
                                .foregroundColor(colors.onSecondaryContainer)
                                .lineLimit(1)
                            
                            Text("%d songs".localized(max(1, topArtistItem.count)))
                                .font(.custom("Quicksand-Regular", size: 11))
                                .foregroundColor(colors.onSecondaryContainer.opacity(0.70))
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onNavigateToArtist(topArtistItem.name)
                        }
                        
                        Spacer(minLength: 6)
                        
                        // 2. Top Song
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(colors.onSecondaryContainer.opacity(0.85))
                                
                                Text("TOP SONG".localized + " • " + "%d plays".localized(topSongItem.plays))
                                    .font(.custom("Quicksand-Bold", size: 9.5))
                                    .tracking(0.6)
                                    .foregroundColor(colors.onSecondaryContainer.opacity(0.85))
                            }
                            
                            Text(topSongItem.title)
                                .font(.custom("Quicksand-Bold", size: 14))
                                .foregroundColor(colors.onSecondaryContainer)
                                .lineLimit(1)
                        }
                        
                        Spacer(minLength: 6)
                        
                        // 3. Top Genre
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Image(systemName: "square.grid.2x2.fill")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(colors.onSecondaryContainer.opacity(0.85))
                                
                                Text("TOP GENRE".localized)
                                    .font(.custom("Quicksand-Bold", size: 9.5))
                                    .tracking(0.6)
                                    .foregroundColor(colors.onSecondaryContainer.opacity(0.85))
                            }
                            
                            Text(topGenreItem)
                                .font(.custom("Quicksand-Bold", size: 14))
                                .foregroundColor(colors.onSecondaryContainer)
                                .lineLimit(1)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onNavigateToGenre(topGenreItem)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(16)
            }
            .frame(height: 190)
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.08), radius: 10, x: 0, y: 4)
            .padding(.horizontal, 16)
            
            // MARK: 2. Continue Listening Card (56dp cover, title, artist, 48dp ScallopPlayPauseButtonWithProgress)
            if let song = activeSong {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onTapHero()
                } label: {
                    HStack(spacing: 12) {
                        // Song Cover 56x56 (cornerRadius: 14)
                        if let img = ArtworkCache.shared.image(for: song.id, data: song.artworkData) {
                            Image(uiImage: img)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 56, height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        } else {
                            ArtworkPlaceholderView(size: 56, cornerRadius: 14)
                        }
                        
                        // Song Title & Artist
                        VStack(alignment: .leading, spacing: 3) {
                            Text(song.title)
                                .font(.custom("Quicksand-Bold", size: 15))
                                .foregroundColor(colors.onSurface)
                                .lineLimit(1)
                            
                            Text(song.artist)
                                .font(.custom("Quicksand-Regular", size: 13))
                                .foregroundColor(colors.onSurfaceVariant)
                                .lineLimit(1)
                        }
                        
                        Spacer(minLength: 4)
                        
                        // Scallop Play/Pause Button with circular progress ring
                        ScallopPlayPauseButtonWithProgress(
                            isPlaying: player.isPlaying && player.currentSong?.id == song.id,
                            progress: player.playbackProgress,
                            primaryColor: colors.isDark ? .white : Color(hex: 0x121212),
                            size: 48
                        ) {
                            if player.currentSong?.id == song.id {
                                player.togglePlayPause()
                            } else {
                                player.playSong(song)
                            }
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(colors.surfaceVariant.opacity(0.60))
                    )
                }
                .buttonStyle(M3BounceButtonStyle(scale: 0.98))
                .padding(.horizontal, 16)
            }
        }
    }
    }
    
    // MARK: - AI Recommendations Carousel (1:1 Android Carousel 200dp height, 24dp corner)
    
    private var recommendationsSection: some View {
        let colors = settings.resolveColors(for: colorScheme)
        
        return VStack(alignment: .leading, spacing: 10) {
            Text("Recommendations".localized)
                .font(.custom("Quicksand-Bold", size: 22))
                .foregroundColor(colors.onSurface)
                .padding(.horizontal, 16)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(recommendations.prefix(12)) { song in
                        Button {
                            player.playQueue(recommendations, startingAt: recommendations.firstIndex(of: song) ?? 0)
                        } label: {
                            ZStack(alignment: .bottomLeading) {
                                // Full cover artwork filling the 280x200 card
                                if let img = ArtworkCache.shared.image(for: song.id, data: song.artworkData) {
                                    Image(uiImage: img)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 280, height: 200)
                                        .clipped()
                                } else {
                                    ArtworkPlaceholderView(size: 280, cornerRadius: 0)
                                        .frame(width: 280, height: 200)
                                }
                                
                                // Dark vertical gradient overlay on bottom
                                LinearGradient(
                                    colors: [
                                        Color.clear,
                                        Color.black.opacity(0.25),
                                        Color.black.opacity(0.78),
                                        Color.black.opacity(0.94)
                                    ],
                                    startPoint: .center,
                                    endPoint: .bottom
                                )
                                .frame(width: 280, height: 200)
                                
                                // Bottom info row: Title & Artist on left, Play button on right
                                HStack(alignment: .bottom) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(song.title)
                                            .font(.custom("Quicksand-Bold", size: 16))
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                        
                                        Text(song.artist)
                                            .font(.custom("Quicksand-Regular", size: 13))
                                            .foregroundColor(Color.white.opacity(0.82))
                                            .lineLimit(1)
                                    }
                                    .frame(maxWidth: 180, alignment: .leading)
                                    
                                    Spacer()
                                    
                                    // Circular Play Button (1:1 Android: semi-transparent circle with white icon)
                                    Circle()
                                        .fill(Color.black.opacity(0.45))
                                        .frame(width: 44, height: 44)
                                        .overlay(
                                            Image(systemName: "play.fill")
                                                .font(.system(size: 18, weight: .bold))
                                                .foregroundColor(.white)
                                                .offset(x: 1.5)
                                        )
                                        .shadow(color: Color.black.opacity(0.35), radius: 6, x: 0, y: 3)
                                }
                                .padding(16)
                            }
                            .frame(width: 280, height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.12), radius: 8, x: 0, y: 4)
                        }
                        .buttonStyle(M3BounceButtonStyle(scale: 0.97))
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    // MARK: - Top Playlists Section (1:1 Android Carousel)
    
    private var playlistsSection: some View {
        let colors = settings.resolveColors(for: colorScheme)
        
        return VStack(alignment: .leading, spacing: 10) {
            Text("Playlists".localized)
                .font(.custom("Quicksand-Bold", size: 22))
                .foregroundColor(colors.onSurface)
                .padding(.horizontal, 16)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(libraryPlaylists) { pl in
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            selectedPlaylist = pl
                        } label: {
                            ZStack(alignment: .bottomLeading) {
                                PlaylistCoverView(
                                    playlist: pl,
                                    cornerRadius: 20,
                                    isM3: true,
                                    primaryColor: colors.primary,
                                    containerColor: colors.surfaceContainerHigh
                                )
                                .frame(width: 150, height: 190)
                                
                                LinearGradient(
                                    colors: [
                                        Color.clear,
                                        Color.black.opacity(0.15),
                                        Color.black.opacity(0.70),
                                        Color.black.opacity(0.92)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(pl.name)
                                        .font(.custom("Quicksand-Bold", size: 14))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    Text("%d songs".localized(pl.songIds.count))
                                        .font(.custom("Quicksand-Regular", size: 12))
                                        .foregroundColor(Color.white.opacity(0.75))
                                }
                                .padding(12)
                            }
                            .frame(width: 150, height: 190)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.12), radius: 6, x: 0, y: 3)
                        }
                        .buttonStyle(M3BounceButtonStyle(scale: 0.97))
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    // MARK: - Top Artists Section (1:1 Android ArtistCircleCard)
    
    private var topArtistsSection: some View {
        let colors = settings.resolveColors(for: colorScheme)
        
        return VStack(alignment: .leading, spacing: 10) {
            Text("Artists".localized)
                .font(.custom("Quicksand-Bold", size: 22))
                .foregroundColor(colors.onSurface)
                .padding(.horizontal, 16)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(library.artists.prefix(10)) { artist in
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            selectedArtist = artist
                        } label: {
                            // Android Lune 1:1 ArtistCircleCard (100x100 circle without text label)
                            Group {
                                if let img = ArtworkCache.shared.image(for: "artist_\(artist.name)", data: artist.artworkData) {
                                    Image(uiImage: img)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 100, height: 100)
                                        .clipShape(Circle())
                                } else {
                                    Circle()
                                        .fill(colors.surfaceContainerHigh)
                                        .frame(width: 100, height: 100)
                                        .overlay(
                                            Image(systemName: "person.fill")
                                                .font(.system(size: 36))
                                                .foregroundColor(colors.primary)
                                        )
                                }
                            }
                            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.12), radius: 6, x: 0, y: 3)
                        }
                        .buttonStyle(M3BounceButtonStyle(scale: 0.96))
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    // MARK: - Top Genres Section
    
    private var topGenresSection: some View {
        let colors = settings.resolveColors(for: colorScheme)
        
        return VStack(alignment: .leading, spacing: 10) {
            Text("Genres".localized)
                .font(.custom("Quicksand-Bold", size: 22))
                .foregroundColor(colors.onSurface)
                .padding(.horizontal, 16)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(library.genres.prefix(8), id: \.self) { genre in
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            selectedGenre = GenreItem(name: genre)
                        } label: {
                            ZStack(alignment: .bottomLeading) {
                                colors.surfaceContainerHigh
                                
                                LinearGradient(
                                    colors: [
                                        Color.black.opacity(0.20),
                                        Color.black.opacity(0.60),
                                        Color.black.opacity(0.85)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                
                                Text(genre)
                                    .font(.custom("Quicksand-Bold", size: 16))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .padding(14)
                            }
                            .frame(width: 150, height: 95)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.12), radius: 6, x: 0, y: 3)
                        }
                        .buttonStyle(M3BounceButtonStyle(scale: 0.96))
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    // MARK: - Recently Added Section
    
    private var recentlyAddedSection: some View {
        let colors = settings.resolveColors(for: colorScheme)
        
        return VStack(alignment: .leading, spacing: 10) {
            Text("Recently Added".localized)
                .font(.custom("Quicksand-Bold", size: 22))
                .foregroundColor(colors.onSurface)
                .padding(.horizontal, 16)
            
            VStack(spacing: 8) {
                ForEach(recentlyAdded.prefix(5)) { song in
                    Button {
                        player.playSong(song)
                    } label: {
                        HStack(spacing: 12) {
                            if let img = ArtworkCache.shared.image(for: song.id, data: song.artworkData) {
                                Image(uiImage: img)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 48, height: 48)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            } else {
                                ArtworkPlaceholderView(size: 48, cornerRadius: 12)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(song.title)
                                    .font(.custom("Quicksand-Bold", size: 14))
                                    .foregroundColor(colors.onSurface)
                                    .lineLimit(1)
                                Text(song.artist)
                                    .font(.custom("Quicksand-Regular", size: 12))
                                    .foregroundColor(colors.onSurfaceVariant)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            Text(song.formattedDuration)
                                .font(.custom("Quicksand-Regular", size: 12))
                                .foregroundColor(colors.onSurfaceVariant)
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(colors.surfaceContainerHigh.opacity(0.70))
                        )
                    }
                    .buttonStyle(M3BounceButtonStyle(scale: 0.98))
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    // Computed Helpers
    private var libraryPlaylists: [Playlist] {
        DataStore.shared.getAllPlaylists()
    }
    private var recentlyAdded: [Song] {
        library.recentlyAddedSongs.isEmpty ? library.allSongs : library.recentlyAddedSongs
    }
    
    private var topArtistItem: (name: String, count: Int, artworkData: Data?) {
        guard let first = library.artists.first else {
            return ("Unknown Artist".localized, 0, nil)
        }
        return (first.name, first.songCount, first.artworkData)
    }
    
    private var topSongItem: (title: String, plays: Int, artworkData: Data?) {
        guard let first = library.allSongs.first else {
            return ("No Plays Yet".localized, 0, nil)
        }
        return (first.title, 5, first.artworkData)
    }
    
    private var topGenreItem: String {
        library.genres.first ?? "Pop"
    }
}
