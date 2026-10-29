//
//  ArtistsView.swift
//  Lune
//
//  Artists grid and Artist Detail views.
//

import SwiftUI

@MainActor
public struct ArtistsView: View {
    @ObservedObject var library: MusicLibraryManager
    @State private var selectedArtist: Artist? = nil
    
    public init(library: MusicLibraryManager) {
        self.library = library
    }
    
    public init() {
        self.library = .shared
    }
    
    public var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                ForEach(library.artists) { artist in
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        selectedArtist = artist
                    } label: {
                        VStack(spacing: 8) {
                            if let data = artist.artworkData, let img = UIImage(data: data) {
                                Image(uiImage: img)
                                    .resizable()
                                    .aspectRatio(1, contentMode: .fill)
                                    .frame(width: 80, height: 80)
                                    .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(LinearGradient(colors: [Color(hex: 0x554492), Color(hex: 0x8C74D9)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 80, height: 80)
                                    .overlay(Image(systemName: "person.fill").font(.system(size: 32)).foregroundColor(.white))
                            }
                            
                            VStack(spacing: 2) {
                                Text(artist.name)
                                    .font(.custom("Quicksand-Bold", size: 13))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                Text("\(artist.songCount) tracks")
                                    .font(.custom("Quicksand-Regular", size: 11))
                                    .foregroundColor(.secondary)
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
        .sheet(item: $selectedArtist) { artist in
            NavigationStack {
                ArtistDetailView(artist: artist)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") {
                                selectedArtist = nil
                            }
                            .font(.custom("Quicksand-Bold", size: 15))
                        }
                    }
            }
        }
    }
}

@MainActor
public struct ArtistDetailView: View {
    let artist: Artist
    @ObservedObject var library: MusicLibraryManager = .shared
    @ObservedObject var player: AudioPlayerManager = .shared
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 12) {
                    if let data = artist.artworkData, let img = UIImage(data: data) {
                        Image(uiImage: img)
                            .resizable()
                            .aspectRatio(1, contentMode: .fill)
                            .frame(width: 140, height: 140)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(LinearGradient(colors: [Color(hex: 0x554492), Color(hex: 0x8C74D9)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 140, height: 140)
                            .overlay(Image(systemName: "person.fill").font(.system(size: 50)).foregroundColor(.white))
                    }
                    
                    Text(artist.name)
                        .font(.custom("Quicksand-Bold", size: 24))
                    Text("\(artistSongs.count) songs • \(artist.albumCount) albums")
                        .font(.custom("Quicksand-Regular", size: 14))
                        .foregroundColor(.secondary)
                    
                    Button {
                        player.playQueue(artistSongs)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                            Text("Play Artist")
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
                
                // Track list
                LazyVStack(spacing: 8) {
                    ForEach(Array(artistSongs.enumerated()), id: \.element.id) { index, song in
                        SongRowView(
                            song: song,
                            isCurrentSong: player.currentSong?.id == song.id,
                            isPlaying: player.isPlaying,
                            onPlay: { player.playQueue(artistSongs, startingAt: index) }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 160)
            }
        }
        .navigationTitle(artist.name)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var artistSongs: [Song] {
        library.allSongs.filter { $0.artist == artist.name }
    }
}
