//
//  ResumeScreenView.swift
//  Lune
//
//  Complete parity with Android ResumeScreen.kt:
//  - Hero Section (Current / Last played with live playback stats)
//  - AI Recommendations carousel
//  - Top Playlists grid
//  - Top Artists & Top Genres
//  - Recently Added tracks
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
    
    let onTapHero: () -> Void
    let onNavigateToAllSongs: () -> Void
    let onNavigateToArtist: (String) -> Void
    let onNavigateToAlbum: (Album) -> Void
    let onNavigateToGenre: (String) -> Void
    let onNavigateToPlaylist: (Playlist) -> Void
    
    @MainActor
    public init(
        library: MusicLibraryManager = .shared,
        player: AudioPlayerManager = .shared,
        settings: SettingsManager = .shared,
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
    
    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 24) {
                // 1. Hero Section
                heroCard
                
                // 2. AI Recommendations
                if !recommendations.isEmpty {
                    recommendationsSection
                }
                
                // 3. Top Playlists Grid
                if !libraryPlaylists.isEmpty {
                    playlistsGridSection
                }
                
                // 4. Top Artists Carousel
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
            .padding(.top, 16)
            .padding(.bottom, 160) // spacing for floating MiniPlayer & TabBar
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
                            Button("Done") { selectedGenre = nil }
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
                            Button("Done") { selectedAlbum = nil }
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
    }
    
    // MARK: - Hero Card
    
    private var heroCard: some View {
        let colors = settings.resolveColors(for: colorScheme)
        let activeSong = player.currentSong ?? library.allSongs.first
        
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                // Album artwork + Song title & artist (tappable to open Now Playing)
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onTapHero()
                } label: {
                    HStack(spacing: 14) {
                        if let song = activeSong {
                            if let data = song.artworkData, let img = UIImage(data: data) {
                                Image(uiImage: img)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 80, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            } else {
                                ArtworkPlaceholderView(size: 80, cornerRadius: 16)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(player.isPlaying ? "NOW PLAYING" : "LAST PLAYED")
                                .font(.custom("Quicksand-Bold", size: 10))
                                .foregroundColor(colors.primary)
                                .tracking(1.0)
                            
                            Text(activeSong?.title ?? "Welcome to Lune")
                                .font(.custom("Quicksand-Bold", size: 18))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            
                            Text(activeSong?.artist ?? "Scan or import audio to begin")
                                .font(.custom("Quicksand-Regular", size: 14))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                // Play / Pause Glass Action
                if let song = activeSong {
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        if player.currentSong?.id == song.id {
                            player.togglePlayPause()
                        } else {
                            player.playSong(song)
                        }
                    } label: {
                        Image(systemName: (player.currentSong?.id == song.id && player.isPlaying) ? "pause.fill" : "play.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 52, height: 52)
                            .liquidGlass(.tinted(colors.primary, opacity: 0.9), in: Circle(), interactive: true)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Quick Stat Badges
            HStack(spacing: 8) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onNavigateToAllSongs()
                } label: {
                    statPill(title: "\(library.allSongs.count) Songs", icon: "music.note")
                }
                .buttonStyle(.plain)
                
                if let topArt = library.artists.first?.name {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onNavigateToArtist(topArt)
                    } label: {
                        statPill(title: topArt, icon: "person.fill")
                    }
                    .buttonStyle(.plain)
                }
                
                if let topGen = library.genres.first {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onNavigateToGenre(topGen)
                    } label: {
                        statPill(title: topGen, icon: "guitars.fill")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(18)
        .liquidGlass(
            .regular,
            in: RoundedRectangle(cornerRadius: 24, style: .continuous),
            interactive: false,
            hasBorder: true,
            shadowRadius: 10
        )
        .padding(.horizontal, 16)
    }
    
    private func statPill(title: String, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(title)
                .font(.custom("Quicksand-Bold", size: 11))
                .lineLimit(1)
        }
        .foregroundColor(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(Color.primary.opacity(0.06)))
    }
    
    // MARK: - AI Recommendations
    
    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Recommendations", subtitle: "Curated for your habits")
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(recommendations.prefix(10)) { song in
                        Button {
                            player.playQueue(recommendations, startingAt: recommendations.firstIndex(of: song) ?? 0)
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                if let data = song.artworkData, let img = UIImage(data: data) {
                                    Image(uiImage: img)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 130, height: 130)
                                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                } else {
                                    ArtworkPlaceholderView(size: 130, cornerRadius: 18)
                                }
                                
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
                                .frame(width: 130, alignment: .leading)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    // MARK: - Top Playlists Grid
    
    private var playlistsGridSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Playlists", subtitle: "Your collections")
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(libraryPlaylists.prefix(4)) { pl in
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        selectedPlaylist = pl
                    } label: {
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(LinearGradient(colors: [Color(hex: 0x6650A4), Color(hex: 0x8B5CF6)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 44, height: 44)
                                .overlay(Image(systemName: "music.note.list").foregroundColor(.white))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(pl.name)
                                    .font(.custom("Quicksand-Bold", size: 14))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                Text("\(pl.songIds.count) songs")
                                    .font(.custom("Quicksand-Regular", size: 11))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(10)
                        .liquidGlass(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Top Artists Section
    
    private var topArtistsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Artists", subtitle: "Your most played creators")
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(library.artists.prefix(8)) { artist in
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            selectedArtist = artist
                        } label: {
                            VStack(spacing: 8) {
                                if let data = artist.artworkData, let img = UIImage(data: data) {
                                    Image(uiImage: img)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 80, height: 80)
                                        .clipShape(Circle())
                                } else {
                                    Circle()
                                        .fill(LinearGradient(colors: [Color(hex: 0x6366F1), Color(hex: 0xEC4899)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                        .frame(width: 80, height: 80)
                                        .overlay(Image(systemName: "person.fill").font(.system(size: 28)).foregroundColor(.white))
                                }
                                
                                Text(artist.name)
                                    .font(.custom("Quicksand-Bold", size: 13))
                                    .foregroundColor(.primary)
                                    .frame(width: 85)
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    // MARK: - Top Genres Section
    
    private var topGenresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Genres", subtitle: "Styles in your library")
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(library.genres.prefix(8), id: \.self) { genre in
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            selectedGenre = GenreItem(name: genre)
                        } label: {
                            Text(genre)
                                .font(.custom("Quicksand-Bold", size: 13))
                                .foregroundColor(.primary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .liquidGlass(.regular, in: Capsule(style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    // MARK: - Recently Added Section
    
    private var recentlyAddedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Recently Added", subtitle: "Latest tracks in your collection")
            
            VStack(spacing: 8) {
                ForEach(recentlyAdded.prefix(5)) { song in
                    Button {
                        player.playSong(song)
                    } label: {
                        HStack(spacing: 12) {
                            if let data = song.artworkData, let img = UIImage(data: data) {
                                Image(uiImage: img)
                                    .resizable()
                                    .frame(width: 44, height: 44)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            } else {
                                ArtworkPlaceholderView(size: 44, cornerRadius: 10)
                            }
                            
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
                            
                            Text(song.formattedDuration)
                                .font(.custom("Quicksand-Regular", size: 12))
                                .foregroundColor(.secondary)
                        }
                        .padding(10)
                        .liquidGlass(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.custom("Quicksand-Bold", size: 20))
                .foregroundColor(.primary)
            Text(subtitle)
                .font(.custom("Quicksand-Regular", size: 13))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
    }
    
    // Computed Helpers
    private var libraryPlaylists: [Playlist] {
        DataStore.shared.getAllPlaylists()
    }
    private var recentlyAdded: [Song] {
        library.allSongs.sorted { $0.dateAdded > $1.dateAdded }
    }
}
