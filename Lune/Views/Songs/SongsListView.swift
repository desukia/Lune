//
//  SongsListView.swift
//  Lune
//
//  Searchable, sortable song list with file importer and fast scroll index.
//

import SwiftUI
import UniformTypeIdentifiers

public enum SongSortOption: String, CaseIterable, Identifiable {
    case title = "Title"
    case artist = "Artist"
    case album = "Album"
    case dateAdded = "Recently Added"
    case duration = "Duration"
    
    public var id: String { rawValue }
}

@MainActor
public struct SongsListView: View {
    let title: String
    let filterFavoritesOnly: Bool
    @ObservedObject var library: MusicLibraryManager
    @ObservedObject var player: AudioPlayerManager
    @ObservedObject var settings: SettingsManager
    
    @State private var searchText: String = ""
    @State private var sortOption: SongSortOption = .title
    @State private var showFileImporter: Bool = false
    @State private var showPlaylistSheetForSong: Song? = nil
    @State private var isGridLayout: Bool = false
    @Environment(\.colorScheme) private var colorScheme
    
    @MainActor
    public init(
        title: String = "Songs",
        filterFavoritesOnly: Bool = false,
        library: MusicLibraryManager,
        player: AudioPlayerManager,
        settings: SettingsManager
    ) {
        self.title = title
        self.filterFavoritesOnly = filterFavoritesOnly
        self.library = library
        self.player = player
        self.settings = settings
    }
    
    public init(
        title: String = "Songs",
        filterFavoritesOnly: Bool = false
    ) {
        self.title = title
        self.filterFavoritesOnly = filterFavoritesOnly
        self.library = .shared
        self.player = .shared
        self.settings = .shared
    }
    
    public var body: some View {
        let colors = settings.resolveColors(for: colorScheme)
        let isM3 = settings.uiStyle == .materialYou
        
        VStack(spacing: 0) {
            // Header: Authentic M3 SongsListHeader or Liquid Glass Bar
            if isM3 {
                m3SongsListHeader(colors: colors)
            } else {
                HStack {
                    Text("\(filteredSongs.count) \(filteredSongs.count == 1 ? "track" : "tracks")")
                        .font(.custom("Quicksand-Bold", size: 13))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Menu {
                        Picker("Sort by", selection: $sortOption) {
                            ForEach(SongSortOption.allCases) { opt in
                                Text(opt.rawValue).tag(opt)
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.system(size: 11))
                            Text(sortOption.rawValue)
                                .font(.custom("Quicksand-Bold", size: 12))
                        }
                        .foregroundColor(colors.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(colors.primary.opacity(0.12)))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 12)
            }
            
            // List of songs
            if filteredSongs.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: isM3 ? 2 : 8) {
                        ForEach(Array(filteredSongs.enumerated()), id: \.element.id) { index, song in
                            let pos: RowPosition = {
                                if filteredSongs.count == 1 { return .single }
                                if index == 0 { return .first }
                                if index == filteredSongs.count - 1 { return .last }
                                return .middle
                            }()
                            
                            SongRowView(
                                song: song,
                                isCurrentSong: player.currentSong?.id == song.id,
                                isPlaying: player.isPlaying,
                                position: pos,
                                primaryColor: colors.primary,
                                onPlay: {
                                    player.playQueue(filteredSongs, startingAt: index)
                                },
                                onToggleFavorite: {
                                    library.toggleFavorite(for: song)
                                },
                                onAddToPlaylist: {
                                    showPlaylistSheetForSong = song
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 220)
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search title, artist, album...")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showFileImporter = true
                    } label: {
                        Label("Import Audio Files", systemImage: "square.and.arrow.down")
                    }
                    Button {
                        Task { await library.scanLibrary() }
                    } label: {
                        Label("Rescan Library", systemImage: "arrow.clockwise")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 18))
                }
            }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result {
                Task {
                    await library.importAudioFiles(from: urls)
                }
            }
        }
        .sheet(item: $showPlaylistSheetForSong) { song in
            AddToPlaylistSheet(song: song)
        }
    }
    
    private var filteredSongs: [Song] {
        var list = library.allSongs
        if filterFavoritesOnly {
            list = list.filter { $0.isFavorite }
        }
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            list = list.filter {
                $0.title.lowercased().contains(q) ||
                $0.artist.lowercased().contains(q) ||
                $0.album.lowercased().contains(q) ||
                ($0.genre?.lowercased().contains(q) ?? false)
            }
        }
        
        switch sortOption {
        case .title:
            return list.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .artist:
            return list.sorted { $0.artist.localizedCaseInsensitiveCompare($1.artist) == .orderedAscending }
        case .album:
            return list.sorted { $0.album.localizedCaseInsensitiveCompare($1.album) == .orderedAscending }
        case .dateAdded:
            return list.sorted { $0.dateAdded > $1.dateAdded }
        case .duration:
            return list.sorted { $0.duration > $1.duration }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: filterFavoritesOnly ? "heart.slash" : "music.note")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text(filterFavoritesOnly ? "No favorite tracks yet" : "No songs found")
                .font(.custom("Quicksand-Bold", size: 16))
                .foregroundColor(.secondary)
            if !filterFavoritesOnly {
                Button("Import Audio Files") {
                    showFileImporter = true
                }
                .font(.custom("Quicksand-Bold", size: 14))
                .buttonStyle(.liquidGlassProminent)
                .padding(.top, 8)
            }
            Spacer()
        }
    }
    
    // MARK: - Material 3 Expressive SongsListHeader (Android Lune Parity)
    private func m3SongsListHeader(colors: LuneColorScheme) -> some View {
        HStack(spacing: 8) {
            // 1. Grid / List Layout toggle
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                isGridLayout.toggle()
            } label: {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(colors.secondaryContainer)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: isGridLayout ? "list.bullet" : "square.grid.2x2")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(colors.onSecondaryContainer)
                    )
            }
            .buttonStyle(M3BounceButtonStyle())
            
            // 2. Large Play / Pause pill in center (Android Lune 1:1)
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                if player.isPlaying {
                    player.pause()
                } else {
                    if !filteredSongs.isEmpty {
                        player.playQueue(filteredSongs, startingAt: 0)
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: player.isPlaying ? 10 : 20, style: .continuous)
                        .fill(colors.onPrimary.opacity(0.22))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(colors.onPrimary)
                                .offset(x: player.isPlaying ? 0 : 1.5)
                        )
                    
                    Text(player.isPlaying ? "Pause" : "Play (\(filteredSongs.count))")
                        .font(.custom("Quicksand-Bold", size: 15))
                        .foregroundColor(colors.onPrimary)
                }
                .padding(.horizontal, 16)
                .frame(height: 48)
                .background(colors.primary)
                .clipShape(RoundedRectangle(cornerRadius: player.isPlaying ? 14 : 28, style: .continuous))
                .shadow(color: colors.primary.opacity(0.30), radius: 8, x: 0, y: 3)
            }
            .buttonStyle(M3BounceButtonStyle(scale: 0.94))
            
            // 3. Shuffle / Sort menu button
            Menu {
                Picker("Sort by", selection: $sortOption) {
                    ForEach(SongSortOption.allCases) { opt in
                        Text(opt.rawValue).tag(opt)
                    }
                }
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
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}
