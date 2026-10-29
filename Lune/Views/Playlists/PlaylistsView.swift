//
//  PlaylistsView.swift
//  Lune
//
//  Playlists management, creation dialog, song picker, and Playlist Detail.
//

import SwiftUI

@MainActor
public struct PlaylistsView: View {
    @ObservedObject var library: MusicLibraryManager
    @State private var playlists: [Playlist] = []
    @State private var showCreateDialog: Bool = false
    @State private var newPlaylistName: String = ""
    @State private var selectedPlaylist: Playlist? = nil
    
    public init(library: MusicLibraryManager) {
        self.library = library
    }
    
    public init() {
        self.library = .shared
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Create Playlist Button
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    showCreateDialog = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                        Text("New Playlist")
                            .font(.custom("Quicksand-Bold", size: 15))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .liquidGlass(.prominent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                
                // Playlists Grid or Empty State
                if playlists.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                            .padding(.top, 40)
                        
                        Text("No playlists yet")
                            .font(.custom("Quicksand-Bold", size: 17))
                            .foregroundColor(.primary)
                        
                        Text("Tap 'New Playlist' above to create your first collection.")
                            .font(.custom("Quicksand-Regular", size: 13))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                } else {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                        ForEach(playlists) { pl in
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                selectedPlaylist = pl
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: [Color(hex: 0x554492), Color(hex: 0x8C74D9)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .aspectRatio(1, contentMode: .fit)
                                        .overlay(
                                            Image(systemName: "music.note.list")
                                                .font(.system(size: 36))
                                                .foregroundColor(.white)
                                        )
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(pl.name)
                                            .font(.custom("Quicksand-Bold", size: 14))
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                        Text("\(pl.songIds.count) \(pl.songIds.count == 1 ? "song" : "songs")")
                                            .font(.custom("Quicksand-Regular", size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 160)
                }
            }
            .padding(.top, 16)
        }
        .onAppear { reload() }
        .sheet(item: $selectedPlaylist) { pl in
            NavigationStack {
                PlaylistDetailView(playlist: pl, onUpdate: { reload() })
            }
        }
        .alert("New Playlist", isPresented: $showCreateDialog) {
            TextField("Playlist Name", text: $newPlaylistName)
            Button("Create") {
                let trimmed = newPlaylistName.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    let created = DataStore.shared.createPlaylist(name: trimmed)
                    newPlaylistName = ""
                    reload()
                    selectedPlaylist = created
                }
            }
            Button("Cancel", role: .cancel) { newPlaylistName = "" }
        }
    }
    
    private func reload() {
        playlists = DataStore.shared.getAllPlaylists()
    }
}

// MARK: - Playlist Detail View
@MainActor
public struct PlaylistDetailView: View {
    @State var playlist: Playlist
    var onUpdate: () -> Void = {}
    @ObservedObject var library: MusicLibraryManager = .shared
    @ObservedObject var player: AudioPlayerManager = .shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var showAddSongsSheet: Bool = false
    
    public init(playlist: Playlist, onUpdate: @escaping () -> Void = {}) {
        self._playlist = State(initialValue: playlist)
        self.onUpdate = onUpdate
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header Cover & Title
                VStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(LinearGradient(colors: [Color(hex: 0x554492), Color(hex: 0x8C74D9)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 150, height: 150)
                        .overlay(Image(systemName: "music.note.list").font(.system(size: 52)).foregroundColor(.white))
                        .shadow(color: Color(hex: 0x554492).opacity(0.35), radius: 16, x: 0, y: 8)
                    
                    Text(playlist.name)
                        .font(.custom("Quicksand-Bold", size: 24))
                        .foregroundColor(.primary)
                    
                    Text("\(playlistSongs.count) \(playlistSongs.count == 1 ? "track" : "tracks")")
                        .font(.custom("Quicksand-Regular", size: 14))
                        .foregroundColor(.secondary)
                    
                    // Buttons Row: Play & Add Songs
                    HStack(spacing: 12) {
                        if !playlistSongs.isEmpty {
                            Button {
                                player.playQueue(playlistSongs)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "play.fill")
                                    Text("Play")
                                        .font(.custom("Quicksand-Bold", size: 14))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 11)
                                .liquidGlass(.prominent, in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        
                        Button {
                            showAddSongsSheet = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus")
                                Text("Add Songs")
                                    .font(.custom("Quicksand-Bold", size: 14))
                            }
                            .foregroundColor(.primary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 11)
                            .liquidGlass(.regular, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 16)
                
                // Songs List or Empty State
                if playlistSongs.isEmpty {
                    VStack(spacing: 12) {
                        Text("This playlist has no songs yet.")
                            .font(.custom("Quicksand-Medium", size: 15))
                            .foregroundColor(.secondary)
                            .padding(.top, 24)
                        
                        Button {
                            showAddSongsSheet = true
                        } label: {
                            Text("Browse and Add Songs")
                                .font(.custom("Quicksand-Bold", size: 14))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color(hex: 0x8C74D9))
                                .clipShape(Capsule())
                        }
                    }
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(playlistSongs.enumerated()), id: \.element.id) { index, song in
                            HStack(spacing: 0) {
                                SongRowView(
                                    song: song,
                                    isCurrentSong: player.currentSong?.id == song.id,
                                    isPlaying: player.isPlaying,
                                    onPlay: { player.playQueue(playlistSongs, startingAt: index) }
                                )
                                
                                Button {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    removeSong(song.id)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(.secondary.opacity(0.7))
                                        .padding(.horizontal, 8)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 160)
                }
            }
        }
        .navigationTitle(playlist.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Done") {
                    dismiss()
                }
                .font(.custom("Quicksand-Bold", size: 15))
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showAddSongsSheet = true
                    } label: {
                        Label("Add Songs", systemImage: "plus")
                    }
                    
                    Button(role: .destructive) {
                        DataStore.shared.deletePlaylist(id: playlist.id)
                        onUpdate()
                        dismiss()
                    } label: {
                        Label("Delete Playlist", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showAddSongsSheet) {
            PlaylistSongPickerView(playlist: playlist, onUpdate: {
                refreshPlaylist()
            })
        }
    }
    
    private var playlistSongs: [Song] {
        let set = Set(playlist.songIds)
        return library.allSongs.filter { set.contains($0.id) }
    }
    
    private func removeSong(_ songId: Int64) {
        DataStore.shared.removeSongFromPlaylist(playlistId: playlist.id, songId: songId)
        refreshPlaylist()
    }
    
    private func refreshPlaylist() {
        if let updated = DataStore.shared.getAllPlaylists().first(where: { $0.id == playlist.id }) {
            playlist = updated
        }
        onUpdate()
    }
}

// MARK: - Playlist Song Picker Sheet
@MainActor
public struct PlaylistSongPickerView: View {
    let playlist: Playlist
    var onUpdate: () -> Void = {}
    @ObservedObject var library: MusicLibraryManager = .shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText: String = ""
    @State private var currentSongIds: Set<Int64> = []
    
    public init(playlist: Playlist, onUpdate: @escaping () -> Void = {}) {
        self.playlist = playlist
        self.onUpdate = onUpdate
        self._currentSongIds = State(initialValue: Set(playlist.songIds))
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search tracks to add...", text: $searchText)
                        .font(.custom("Quicksand-Regular", size: 15))
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(12)
                .liquidGlass(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
                
                // Songs List with Toggle Checkmarks
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredSongs) { song in
                            let isAdded = currentSongIds.contains(song.id)
                            
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                toggleSong(song.id)
                            } label: {
                                HStack(spacing: 12) {
                                    // Artwork
                                    if let data = song.artworkData, let img = UIImage(data: data) {
                                        Image(uiImage: img)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 44, height: 44)
                                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    } else {
                                        ArtworkPlaceholderView(size: 44, cornerRadius: 10)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(song.title)
                                            .font(.custom("Quicksand-Bold", size: 15))
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                        Text("\(song.artist) • \(song.album)")
                                            .font(.custom("Quicksand-Regular", size: 12))
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: isAdded ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 22))
                                        .foregroundColor(isAdded ? Color(hex: 0x8C74D9) : .secondary.opacity(0.4))
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .liquidGlass(isAdded ? .tinted(Color(hex: 0x8C74D9), opacity: 0.10) : .regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Add to Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.custom("Quicksand-Bold", size: 15))
                }
            }
        }
    }
    
    private var filteredSongs: [Song] {
        if searchText.isEmpty {
            return library.allSongs
        }
        let q = searchText.lowercased()
        return library.allSongs.filter {
            $0.title.lowercased().contains(q) ||
            $0.artist.lowercased().contains(q) ||
            $0.album.lowercased().contains(q)
        }
    }
    
    private func toggleSong(_ songId: Int64) {
        if currentSongIds.contains(songId) {
            currentSongIds.remove(songId)
            DataStore.shared.removeSongFromPlaylist(playlistId: playlist.id, songId: songId)
        } else {
            currentSongIds.insert(songId)
            DataStore.shared.addSongToPlaylist(playlistId: playlist.id, songId: songId)
        }
        onUpdate()
    }
}

// MARK: - Add To Playlist Sheet (Used from Song context menus)
@MainActor
public struct AddToPlaylistSheet: View {
    let song: Song
    @Environment(\.dismiss) private var dismiss
    @State private var playlists: [Playlist] = []
    @State private var showNewPlaylistAlert: Bool = false
    @State private var newName: String = ""
    @State private var addedPlaylistId: Int64? = nil
    
    public init(song: Song) {
        self.song = song
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Song info badge
                    HStack(spacing: 12) {
                        if let data = song.artworkData, let img = UIImage(data: data) {
                            Image(uiImage: img)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 44, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        } else {
                            ArtworkPlaceholderView(size: 44, cornerRadius: 10)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(song.title)
                                .font(.custom("Quicksand-Bold", size: 15))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            Text(song.artist)
                                .font(.custom("Quicksand-Regular", size: 12))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                    }
                    .padding(12)
                    .liquidGlass(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    
                    // Button to create new playlist
                    Button {
                        showNewPlaylistAlert = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                            Text("Create New Playlist")
                                .font(.custom("Quicksand-Bold", size: 14))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .liquidGlass(.prominent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    
                    // List of existing playlists
                    LazyVStack(spacing: 8) {
                        ForEach(playlists) { pl in
                            let isAlreadyIn = pl.songIds.contains(song.id) || addedPlaylistId == pl.id
                            
                            Button {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                DataStore.shared.addSongToPlaylist(playlistId: pl.id, songId: song.id)
                                addedPlaylistId = pl.id
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                    dismiss()
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "music.note.list")
                                        .font(.system(size: 20))
                                        .foregroundColor(Color(hex: 0x8C74D9))
                                        .frame(width: 36, height: 36)
                                        .background(Color(hex: 0x8C74D9).opacity(0.15))
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(pl.name)
                                            .font(.custom("Quicksand-Bold", size: 15))
                                            .foregroundColor(.primary)
                                        Text("\(pl.songIds.count) songs")
                                            .font(.custom("Quicksand-Regular", size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    if isAlreadyIn {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                    }
                                }
                                .padding(12)
                                .liquidGlass(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Add to Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .font(.custom("Quicksand-Bold", size: 15))
                }
            }
            .onAppear {
                playlists = DataStore.shared.getAllPlaylists()
            }
            .alert("New Playlist", isPresented: $showNewPlaylistAlert) {
                TextField("Playlist Name", text: $newName)
                Button("Create and Add") {
                    let trimmed = newName.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty {
                        let newPl = DataStore.shared.createPlaylist(name: trimmed)
                        DataStore.shared.addSongToPlaylist(playlistId: newPl.id, songId: song.id)
                        newName = ""
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) { newName = "" }
            }
        }
    }
}
