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
    @ObservedObject private var settings: SettingsManager = .shared
    @Environment(\.colorScheme) private var colorScheme
    
    public init(library: MusicLibraryManager) {
        self.library = library
    }
    
    public init() {
        self.library = .shared
    }
    
    public var body: some View {
        let colors = settings.resolveColors(for: colorScheme)
        let isM3 = settings.uiStyle == .materialYou
        
        VStack(spacing: 0) {
            if isM3 {
                m3GenresHeader(colors: colors)
            }
            
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    ForEach(library.genres, id: \.self) { genre in
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            selectedGenreItem = GenreItem(name: genre)
                        } label: {
                            ZStack {
                                if isM3 {
                                    colors.secondaryContainer
                                } else {
                                    LinearGradient(
                                        colors: [Color(hex: 0x554492), Color(hex: 0x8C74D9)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                }
                                
                                VStack(spacing: 6) {
                                    Image(systemName: "guitars.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(isM3 ? colors.primary : .white)
                                    Text(genre)
                                        .font(.custom("Quicksand-Bold", size: 16))
                                        .foregroundColor(isM3 ? colors.onSecondaryContainer : .white)
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
                .padding(.top, isM3 ? 8 : 16)
                .padding(.bottom, 220)
            }
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
    
    // MARK: - Material 3 Expressive GenresHeader (Android Lune Parity)
    private func m3GenresHeader(colors: LuneColorScheme) -> some View {
        HStack(spacing: 8) {
            // Count pill: [ 🎸 6 ]
            HStack(spacing: 8) {
                Image(systemName: "guitars.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(colors.primary)
                
                Text("\(library.genres.count)")
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
public struct GenreDetailView: View {
    let genre: String
    @ObservedObject var library: MusicLibraryManager
    @ObservedObject var player: AudioPlayerManager
    
    public init(genre: String, library: MusicLibraryManager, player: AudioPlayerManager) {
        self.genre = genre
        self.library = library
        self.player = player
    }
    
    public init(genre: String) {
        self.genre = genre
        self.library = .shared
        self.player = .shared
    }
    
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
            .padding(.bottom, 220)
        }
        .navigationTitle(genre)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var genreSongs: [Song] {
        library.allSongs.filter { $0.genre == genre }
    }
}
