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
                m3ArtistsHeader(colors: colors)
            }
            
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
                                        .foregroundColor(isM3 ? colors.onSurface : .primary)
                                        .lineLimit(1)
                                    Text("%d tracks".localized(artist.songCount))
                                        .font(.custom("Quicksand-Regular", size: 11))
                                        .foregroundColor(isM3 ? colors.onSurfaceVariant : .secondary)
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
        .sheet(item: $selectedArtist) { artist in
            NavigationStack {
                ArtistDetailView(artist: artist)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done".localized) {
                                selectedArtist = nil
                            }
                            .font(.custom("Quicksand-Bold", size: 15))
                        }
                    }
            }
        }
    }
    
    // MARK: - Material 3 Expressive ArtistsHeader (Android Lune Parity)
    private func m3ArtistsHeader(colors: LuneColorScheme) -> some View {
        HStack(spacing: 8) {
            // Count pill: [ 👤 18 ]
            HStack(spacing: 8) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(colors.primary)
                
                Text("\(library.artists.count)")
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
public struct ArtistDetailView: View {
    let artist: Artist
    @ObservedObject var library: MusicLibraryManager
    @ObservedObject var player: AudioPlayerManager
    
    public init(artist: Artist, library: MusicLibraryManager, player: AudioPlayerManager) {
        self.artist = artist
        self.library = library
        self.player = player
    }
    
    public init(artist: Artist) {
        self.artist = artist
        self.library = .shared
        self.player = .shared
    }
    
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
                    Text("\("%d songs".localized(artistSongs.count)) • \("%d albums".localized(artist.albumCount))")
                        .font(.custom("Quicksand-Regular", size: 14))
                        .foregroundColor(.secondary)
                    
                    Button {
                        player.playQueue(artistSongs)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                            Text("Play Artist".localized)
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
                .padding(.bottom, 220)
            }
        }
        .navigationTitle(artist.name)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var artistSongs: [Song] {
        library.allSongs.filter { $0.artist == artist.name }
    }
}
