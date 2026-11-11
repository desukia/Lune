//
//  AlbumsView.swift
//  Lune
//
//  Albums grid and Album Detail views.
//

import SwiftUI

@MainActor
public struct AlbumsView: View {
    @ObservedObject var library: MusicLibraryManager
    let onAlbumClick: (Album) -> Void
    
    @State private var selectedAlbum: Album? = nil
    @ObservedObject private var settings: SettingsManager = .shared
    @Environment(\.colorScheme) private var colorScheme
    
    @MainActor
    public init(library: MusicLibraryManager, onAlbumClick: @escaping (Album) -> Void = { _ in }) {
        self.library = library
        self.onAlbumClick = onAlbumClick
    }
    
    public init() {
        self.library = .shared
        self.onAlbumClick = { _ in }
    }
    
    public var body: some View {
        let colors = settings.resolveColors(for: colorScheme)
        let isM3 = settings.uiStyle == .materialYou
        
        VStack(spacing: 0) {
            if isM3 {
                m3AlbumsHeader(colors: colors)
            }
            
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 18) {
                    ForEach(library.albums) { album in
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            selectedAlbum = album
                            onAlbumClick(album)
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                if let data = album.artworkData, let img = UIImage(data: data) {
                                    Image(uiImage: img)
                                        .resizable()
                                        .aspectRatio(1, contentMode: .fill)
                                        .frame(maxWidth: .infinity)
                                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                } else {
                                    ArtworkPlaceholderView(size: 160, cornerRadius: 18)
                                        .frame(maxWidth: .infinity)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(album.name)
                                        .font(.custom("Quicksand-Bold", size: 14))
                                        .foregroundColor(isM3 ? colors.onSurface : .primary)
                                        .lineLimit(1)
                                    Text(album.artist)
                                        .font(.custom("Quicksand-Regular", size: 12))
                                        .foregroundColor(isM3 ? colors.onSurfaceVariant : .secondary)
                                        .lineLimit(1)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, isM3 ? 8 : 16)
                .padding(.bottom, 220)
            }
        }
        .sheet(item: $selectedAlbum) { album in
            NavigationStack {
                AlbumDetailView(album: album)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") {
                                selectedAlbum = nil
                            }
                            .font(.custom("Quicksand-Bold", size: 15))
                        }
                    }
            }
        }
    }
    
    // MARK: - Material 3 Expressive AlbumsHeader (Android Lune Parity)
    private func m3AlbumsHeader(colors: LuneColorScheme) -> some View {
        HStack(spacing: 8) {
            // Count pill: [ 💿 42 ]
            HStack(spacing: 8) {
                Image(systemName: "square.stack.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(colors.primary)
                
                Text("\(library.albums.count)")
                    .font(.custom("Quicksand-Bold", size: 14))
                    .foregroundColor(colors.onSecondaryContainer)
            }
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(colors.secondaryContainer)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            
            Spacer()
            
            // Sort Button
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(colors.secondaryContainer)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(colors.onSecondaryContainer)
                    )
            }
            .buttonStyle(M3BounceButtonStyle())
            
            // View Style Button
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(colors.secondaryContainer)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(colors.onSecondaryContainer)
                    )
            }
            .buttonStyle(M3BounceButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

@MainActor
public struct AlbumDetailView: View {
    let album: Album
    @ObservedObject var library: MusicLibraryManager
    @ObservedObject var player: AudioPlayerManager
    @State private var showPlaylistSheetForSong: Song? = nil
    
    public init(album: Album, library: MusicLibraryManager, player: AudioPlayerManager) {
        self.album = album
        self.library = library
        self.player = player
    }
    
    public init(album: Album) {
        self.album = album
        self.library = .shared
        self.player = .shared
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 12) {
                    if let data = album.artworkData, let img = UIImage(data: data) {
                        Image(uiImage: img)
                            .resizable()
                            .aspectRatio(1, contentMode: .fill)
                            .frame(width: 180, height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .shadow(radius: 12)
                    } else {
                        ArtworkPlaceholderView(size: 180, cornerRadius: 24)
                    }
                    
                    Text(album.name)
                        .font(.custom("Quicksand-Bold", size: 22))
                    Text(album.artist)
                        .font(.custom("Quicksand-Regular", size: 16))
                        .foregroundColor(.secondary)
                    
                    Button {
                        player.playQueue(albumSongs)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                            Text("Play Album".localized)
                                .font(.custom("Quicksand-Bold", size: 14))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .liquidGlass(.prominent, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 16)
                
                // Tracklist
                LazyVStack(spacing: 8) {
                    ForEach(Array(albumSongs.enumerated()), id: \.element.id) { index, song in
                        SongRowView(
                            song: song,
                            isCurrentSong: player.currentSong?.id == song.id,
                            isPlaying: player.isPlaying,
                            onPlay: { player.playQueue(albumSongs, startingAt: index) },
                            onToggleFavorite: { library.toggleFavorite(for: song) },
                            onAddToPlaylist: { showPlaylistSheetForSong = song }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 220)
            }
        }
        .navigationTitle(album.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $showPlaylistSheetForSong) { song in
            AddToPlaylistSheet(song: song)
        }
    }
    
    private var albumSongs: [Song] {
        library.allSongs.filter { $0.album == album.name && $0.artist == album.artist }
            .sorted { $0.trackNumber < $1.trackNumber }
    }
}
