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
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                Text(album.artist)
                                    .font(.custom("Quicksand-Regular", size: 12))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 160)
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
}

@MainActor
public struct AlbumDetailView: View {
    let album: Album
    @ObservedObject var library: MusicLibraryManager = .shared
    @ObservedObject var player: AudioPlayerManager = .shared
    @State private var showPlaylistSheetForSong: Song? = nil
    
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
                            Text("Play Album")
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
                .padding(.bottom, 160)
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
