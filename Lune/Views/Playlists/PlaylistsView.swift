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
                m3PlaylistsHeader(colors: colors)
            }
            
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
                            Text("New Playlist".localized)
                                .font(.custom("Quicksand-Bold", size: 15))
                        }
                        .foregroundColor(isM3 ? colors.onPrimary : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background {
                            if isM3 {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(colors.primary)
                                    .shadow(color: colors.primary.opacity(0.30), radius: 8, x: 0, y: 3)
                            } else {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(.clear)
                                    .liquidGlass(.prominent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    
                    // Playlists Grid or Empty State
                    if playlists.isEmpty {
                        VStack(spacing: 14) {
                            Image(systemName: "music.note.list")
                                .font(.system(size: 48))
                                .foregroundColor(isM3 ? colors.onSurfaceVariant : .secondary)
                                .padding(.top, 40)
                            
                            Text("No playlists yet".localized)
                                .font(.custom("Quicksand-Bold", size: 17))
                                .foregroundColor(isM3 ? colors.onSurface : .primary)
                            
                            Text("Tap 'New Playlist' above to create your first collection.".localized)
                                .font(.custom("Quicksand-Regular", size: 13))
                                .foregroundColor(isM3 ? colors.onSurfaceVariant : .secondary)
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
                                        PlaylistCoverView(
                                            playlist: pl,
                                            cornerRadius: 18,
                                            isM3: isM3,
                                            primaryColor: colors.primary,
                                            containerColor: colors.secondaryContainer
                                        )
                                        .aspectRatio(1, contentMode: .fit)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(pl.name)
                                                .font(.custom("Quicksand-Bold", size: 14))
                                                .foregroundColor(isM3 ? colors.onSurface : .primary)
                                                .lineLimit(1)
                                            Text("%d songs".localized(pl.songIds.count))
                                                .font(.custom("Quicksand-Regular", size: 12))
                                                .foregroundColor(isM3 ? colors.onSurfaceVariant : .secondary)
                                        }
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 220)
                    }
                }
                .padding(.top, isM3 ? 8 : 16)
            }
        }
        .onAppear { reload() }
        .sheet(item: $selectedPlaylist) { pl in
            NavigationStack {
                PlaylistDetailView(playlist: pl, onUpdate: { reload() })
            }
        }
        .alert("New Playlist".localized, isPresented: $showCreateDialog) {
            TextField("Playlist Name".localized, text: $newPlaylistName)
            Button("Create".localized) {
                let trimmed = newPlaylistName.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    let created = DataStore.shared.createPlaylist(name: trimmed)
                    newPlaylistName = ""
                    reload()
                    selectedPlaylist = created
                }
            }
            Button("Cancel".localized, role: .cancel) { newPlaylistName = "" }
        }
    }
    
    private func reload() {
        playlists = DataStore.shared.getAllPlaylists()
    }
    
    // MARK: - Material 3 Expressive PlaylistsHeader (Android Lune Parity)
    private func m3PlaylistsHeader(colors: LuneColorScheme) -> some View {
        HStack(spacing: 8) {
            // Count pill: [ 📑 4 ]
            HStack(spacing: 8) {
                Image(systemName: "music.note.list")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(colors.primary)
                
                Text("\(playlists.count)")
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

// MARK: - Playlist Cover Generator (2x2 Collage of first 4 song artworks)
@MainActor
public final class PlaylistCoverGenerator {
    public static let shared = PlaylistCoverGenerator()
    
    private init() {}
    
    public func collageImage(
        for playlist: Playlist,
        library: MusicLibraryManager = .shared,
        size: CGSize = CGSize(width: 500, height: 500)
    ) -> UIImage? {
        // Collect up to 4 song artworks from the playlist
        var images: [UIImage] = []
        for songId in playlist.songIds {
            if let song = library.allSongs.first(where: { $0.id == songId }),
               let img = ArtworkCache.shared.image(for: song.id, data: song.artworkData) {
                images.append(img)
                if images.count == 4 { break }
            }
        }
        
        guard !images.isEmpty else { return nil }
        
        // Single cover if only 1 song with artwork
        if images.count == 1 {
            return images[0]
        }
        
        // Check cache with signature of the first 4 song IDs
        let songKeyPart = playlist.songIds.prefix(4).map(String.init).joined(separator: "_")
        let cacheKey = "playlist_collage_\(playlist.id)_\(songKeyPart)"
        if let cached = ArtworkCache.shared.get(key: cacheKey) {
            return cached
        }
        
        let renderer = UIGraphicsImageRenderer(size: size)
        let composite = renderer.image { context in
            let halfW = size.width / 2.0
            let halfH = size.height / 2.0
            
            let rects = [
                CGRect(x: 0, y: 0, width: halfW, height: halfH),
                CGRect(x: halfW, y: 0, width: halfW, height: halfH),
                CGRect(x: 0, y: halfH, width: halfW, height: halfH),
                CGRect(x: halfW, y: halfH, width: halfW, height: halfH)
            ]
            
            for (index, rect) in rects.enumerated() {
                let img: UIImage
                if index < images.count {
                    img = images[index]
                } else {
                    img = images[index % images.count]
                }
                
                // Draw aspect fill in the quadrant rect
                let imgSize = img.size
                let aspect = imgSize.width / max(imgSize.height, 1)
                let rectAspect = rect.width / rect.height
                
                var drawRect = rect
                if aspect > rectAspect {
                    let newWidth = rect.height * aspect
                    drawRect = CGRect(x: rect.minX - (newWidth - rect.width) / 2.0, y: rect.minY, width: newWidth, height: rect.height)
                } else {
                    let newHeight = rect.width / aspect
                    drawRect = CGRect(x: rect.minX, y: rect.minY - (newHeight - rect.height) / 2.0, width: rect.width, height: newHeight)
                }
                
                context.cgContext.saveGState()
                context.cgContext.clip(to: rect)
                img.draw(in: drawRect)
                context.cgContext.restoreGState()
            }
        }
        
        ArtworkCache.shared.set(image: composite, for: cacheKey)
        return composite
    }
}

// MARK: - Playlist Cover View (Displays 2x2 Collage or Fallback Placeholder)
@MainActor
public struct PlaylistCoverView: View {
    let playlist: Playlist
    var cornerRadius: CGFloat = 16
    var isM3: Bool = true
    var primaryColor: Color? = nil
    var containerColor: Color? = nil
    
    @ObservedObject private var library: MusicLibraryManager = .shared
    
    public init(
        playlist: Playlist,
        cornerRadius: CGFloat = 16,
        isM3: Bool = true,
        primaryColor: Color? = nil,
        containerColor: Color? = nil
    ) {
        self.playlist = playlist
        self.cornerRadius = cornerRadius
        self.isM3 = isM3
        self.primaryColor = primaryColor
        self.containerColor = containerColor
    }
    
    public var body: some View {
        if let composite = PlaylistCoverGenerator.shared.collageImage(for: playlist, library: library) {
            Image(uiImage: composite)
                .resizable()
                .aspectRatio(1, contentMode: .fill)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            // Elegant Fallback Placeholder
            ZStack {
                if isM3 {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(containerColor ?? Color.black.opacity(0.12))
                } else {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: 0x554492), Color(hex: 0x8C74D9)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                Image(systemName: "music.note.list")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(isM3 ? (primaryColor ?? Color(hex: 0x8C74D9)) : .white)
            }
            .aspectRatio(1, contentMode: .fit)
        }
    }
}

// MARK: - Playlist Detail View
@MainActor
public struct PlaylistDetailView: View {
    @State var playlist: Playlist
    var onUpdate: () -> Void = {}
    @ObservedObject var library: MusicLibraryManager
    @ObservedObject var player: AudioPlayerManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var showAddSongsSheet: Bool = false
    @State private var songToDelete: Song? = nil
    @State private var showDeleteConfirmation: Bool = false
    @State private var hasAutoOpenedPicker: Bool = false
    
    public init(playlist: Playlist, onUpdate: @escaping () -> Void = {}) {
        self._playlist = State(initialValue: playlist)
        self.onUpdate = onUpdate
        self.library = .shared
        self.player = .shared
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header Cover & Title
                VStack(spacing: 12) {
                    PlaylistCoverView(
                        playlist: playlist,
                        cornerRadius: 24,
                        isM3: true,
                        primaryColor: Color(hex: 0x8C74D9)
                    )
                    .frame(width: 160, height: 160)
                    .shadow(color: Color.black.opacity(0.35), radius: 16, x: 0, y: 8)
                    
                    Text(playlist.name)
                        .font(.custom("Quicksand-Bold", size: 24))
                        .foregroundColor(.primary)
                    
                    Text("%d tracks".localized(playlistSongs.count))
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
                                    Text("Play".localized)
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
                                Text("Add Songs".localized)
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
                        Text("This playlist has no songs yet.".localized)
                            .font(.custom("Quicksand-Medium", size: 15))
                            .foregroundColor(.secondary)
                            .padding(.top, 24)
                        
                        Button {
                            showAddSongsSheet = true
                        } label: {
                            Text("Browse and Add Songs".localized)
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
                                    onPlay: { player.playQueue(playlistSongs, startingAt: index) },
                                    onToggleFavorite: { library.toggleFavorite(for: song) },
                                    onRemoveFromPlaylist: {
                                        removeSong(song.id)
                                    },
                                    onDelete: {
                                        songToDelete = song
                                        showDeleteConfirmation = true
                                    }
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
                    .padding(.bottom, 220)
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
        .onAppear {
            if playlist.songIds.isEmpty && !hasAutoOpenedPicker {
                hasAutoOpenedPicker = true
                showAddSongsSheet = true
            }
        }
        .alert("Delete from device".localized, isPresented: $showDeleteConfirmation, presenting: songToDelete) { song in
            Button("Delete".localized, role: .destructive) {
                withAnimation {
                    library.deleteSong(song)
                    refreshPlaylist()
                }
            }
            Button("Cancel".localized, role: .cancel) {}
        } message: { song in
            Text("Are you sure? This song will be permanently deleted from your device.".localized)
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
    @ObservedObject var library: MusicLibraryManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText: String = ""
    @State private var currentSongIds: Set<Int64> = []
    
    public init(playlist: Playlist, onUpdate: @escaping () -> Void = {}) {
        self.playlist = playlist
        self.onUpdate = onUpdate
        self.library = .shared
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
                            Text("Create New Playlist".localized)
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
                                    PlaylistCoverView(
                                        playlist: pl,
                                        cornerRadius: 10,
                                        isM3: true,
                                        primaryColor: Color(hex: 0x8C74D9)
                                    )
                                    .frame(width: 38, height: 38)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(pl.name)
                                            .font(.custom("Quicksand-Bold", size: 15))
                                            .foregroundColor(.primary)
                                        Text("%d songs".localized(pl.songIds.count))
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
            .navigationTitle("Add to Playlist".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel".localized) { dismiss() }
                        .font(.custom("Quicksand-Bold", size: 15))
                }
            }
            .onAppear {
                playlists = DataStore.shared.getAllPlaylists()
            }
            .alert("New Playlist".localized, isPresented: $showNewPlaylistAlert) {
                TextField("Playlist Name".localized, text: $newName)
                Button("Create".localized) {
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
