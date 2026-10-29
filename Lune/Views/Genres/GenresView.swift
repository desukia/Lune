//
//  GenresView.swift
//  Lune
//
//  Genres grid and Genre Detail views.
//

import SwiftUI

public struct GenreItem: Identifiable {
    public var id: String { name }
    public let name: String
    public init(name: String) { self.name = name }
}

@MainActor
public struct GenresView: View {
    @ObservedObject var library: MusicLibraryManager
    @State private var selectedGenreItem: GenreItem? = nil
    
    public init(library: MusicLibraryManager) {
        self.library = library
    }
    
    public init() {
        self.library = .shared
    }
    
    public var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                ForEach(library.genres, id: \.self) { genre in
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        selectedGenreItem = GenreItem(name: genre)
                    } label: {
                        ZStack {
                            LinearGradient(
                                colors: [Color(hex: 0x554492), Color(hex: 0x8C74D9)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            
                            VStack(spacing: 6) {
                                Image(systemName: "guitars.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                                Text(genre)
                                    .font(.custom("Quicksand-Bold", size: 16))
                                    .foregroundColor(.white)
                            }
                            .padding(20)
                        }
                        .frame(height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 160)
        }
        .sheet(item: $selectedGenreItem) { item in
            NavigationStack {
                GenreDetailView(genre: item.name)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") {
                                selectedGenreItem = nil
                            }
                            .font(.custom("Quicksand-Bold", size: 15))
                        }
                    }
            }
        }
    }
}

@MainActor
public struct GenreDetailView: View {
    let genre: String
    @ObservedObject var library: MusicLibraryManager = .shared
    @ObservedObject var player: AudioPlayerManager = .shared
    
    public var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(Array(genreSongs.enumerated()), id: \.element.id) { index, song in
                    SongRowView(
                        song: song,
                        isCurrentSong: player.currentSong?.id == song.id,
                        isPlaying: player.isPlaying,
                        onPlay: { player.playQueue(genreSongs, startingAt: index) }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 160)
        }
        .navigationTitle(genre)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var genreSongs: [Song] {
        library.allSongs.filter { $0.genre == genre }
    }
}
