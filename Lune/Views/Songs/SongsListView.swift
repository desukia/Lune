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
    
    @MainActor
    public init(
        title: String = "Songs",
        filterFavoritesOnly: Bool = false,
        library: MusicLibraryManager = .shared,
        player: AudioPlayerManager = .shared,
        settings: SettingsManager = .shared
    ) {
        self.title = title
        self.filterFavoritesOnly = filterFavoritesOnly
        self.library = library
        self.player = player
        self.settings = settings
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header stats & sort bar
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
                    .foregroundColor(settings.resolveColors(for: .dark).primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(settings.resolveColors(for: .dark).primary.opacity(0.12)))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)
            
            // List of songs
            if filteredSongs.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredSongs) { song in
                            SongRowView(
                                song: song,
                                isCurrentSong: player.currentSong?.id == song.id,
                                isPlaying: player.isPlaying,
                                primaryColor: settings.resolveColors(for: .dark).primary,
                                onPlay: {
                                    player.playQueue(filteredSongs, startingAt: filteredSongs.firstIndex(of: song) ?? 0)
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
                    .padding(.bottom, 160)
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
}
