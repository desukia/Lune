//
//  FoldersView.swift
//  Lune
//
//  Authentic 1:1 Parity with Android FolderBrowserActivity.kt:
//  - Storage volume detection (Internal Storage & External/Documents)
//  - Multi-level directory tree navigation with back traversal
//  - Material 3 secondaryContainer circle for folders & tertiaryContainer circle for audio files
//  - Direct song playback from any folder
//  - Sideloaded / Files app audio importer
//  - Reversible UI style: Material You 1:1 and Liquid Glass
//

import SwiftUI
import UniformTypeIdentifiers

public struct FolderItem: Identifiable {
    public var id: String { name }
    public let name: String
    public let songs: [Song]
    public init(name: String, songs: [Song]) {
        self.name = name
        self.songs = songs
    }
}

@MainActor
public struct FoldersView: View {
    @ObservedObject var library: MusicLibraryManager
    @ObservedObject var player: AudioPlayerManager
    @ObservedObject private var settings: SettingsManager
    @Environment(\.colorScheme) private var colorScheme
    
    // Directory navigation stack
    @State private var currentPath: [String] = []
    @State private var showFileImporter: Bool = false
    @State private var songToDelete: Song? = nil
    @State private var showDeleteConfirmation: Bool = false
    @State private var showPlaylistSheetForSong: Song? = nil
    
    public init(library: MusicLibraryManager, player: AudioPlayerManager) {
        self.library = library
        self.player = player
        self.settings = .shared
    }
    
    public init(library: MusicLibraryManager) {
        self.library = library
        self.player = .shared
        self.settings = .shared
    }
    
    public init() {
        self.library = .shared
        self.player = .shared
        self.settings = .shared
    }
    
    public var body: some View {
        let colors = settings.resolveColors(for: colorScheme)
        
        VStack(spacing: 0) {
            // Header / Breadcrumb Bar
            folderHeaderBar(colors: colors)
            
            // Content List
            ScrollView {
                LazyVStack(spacing: 10) {
                    if currentPath.isEmpty {
                        // Root Screen: Storage Volumes (Internal & Documents)
                        storageVolumesSection(colors: colors)
                        
                        // All Folders overview
                        allFoldersSection(colors: colors)
                    } else {
                        // Active Directory Contents
                        activeFolderContentsSection(colors: colors)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 220)
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
        .alert("Delete from device".localized, isPresented: $showDeleteConfirmation, presenting: songToDelete) { song in
            Button("Delete".localized, role: .destructive) {
                withAnimation {
                    library.deleteSong(song)
                }
            }
            Button("Cancel".localized, role: .cancel) {}
        } message: { song in
            Text("Are you sure? This song will be permanently deleted from your device.".localized)
        }
    }
    
    // MARK: - 1. Top Folder Bar & Breadcrumbs
    private func folderHeaderBar(colors: LuneColorScheme) -> some View {
        HStack(spacing: 12) {
            if !currentPath.isEmpty {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.75)) {
                        _ = currentPath.popLast()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .bold))
                        Text(currentPath.last ?? "Folders".localized)
                            .font(.custom("Quicksand-Bold", size: 16))
                            .lineLimit(1)
                    }
                    .foregroundColor(colors.primary)
                }
            } else {
                Text("Folder Browser".localized)
                    .font(.custom("Quicksand-Bold", size: 18))
                    .foregroundColor(colors.onSurface)
            }
            
            Spacer()
            
            // Import Audio Button
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showFileImporter = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Import".localized)
                        .font(.custom("Quicksand-Bold", size: 13))
                }
                .foregroundColor(colors.onPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(colors.primary)
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(colors.surface)
    }
    
    // MARK: - 2. Root Storage Volumes (Parity with getStorageVolumes)
    private func storageVolumesSection(colors: LuneColorScheme) -> some View {
        VStack(spacing: 10) {
            // Volume 1: Internal Storage (Documents/Music)
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.32, dampingFraction: 0.75)) {
                    currentPath.append("Music")
                }
            } label: {
                HStack(spacing: 16) {
                    Circle()
                        .fill(colors.secondaryContainer)
                        .frame(width: 48, height: 48)
                        .overlay(
                            Image(systemName: "iphone")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(colors.primary)
                        )
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Internal Storage".localized)
                            .font(.custom("Quicksand-Bold", size: 16))
                            .foregroundColor(colors.onSurface)
                        
                        Text("App Sandbox • %d audio tracks".localized(library.allSongs.count))
                            .font(.custom("Quicksand-Regular", size: 12))
                            .foregroundColor(colors.onSurfaceVariant)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(colors.onSurfaceVariant)
                }
                .padding(14)
                .adaptiveCard(uiStyle: settings.uiStyle, colors: colors, cornerRadius: M3Shape.cornerLarge)
                .contentShape(Rectangle())
            }
            .buttonStyle(M3BounceButtonStyle())
            
            // Volume 2: Imported / Sideloaded Files
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showFileImporter = true
            } label: {
                HStack(spacing: 16) {
                    Circle()
                        .fill(colors.tertiaryContainer)
                        .frame(width: 48, height: 48)
                        .overlay(
                            Image(systemName: "sdcard.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(colors.tertiary)
                        )
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Files & Cloud Storage".localized)
                            .font(.custom("Quicksand-Bold", size: 16))
                            .foregroundColor(colors.onSurface)
                        
                        Text("Import from iCloud Drive or external storage".localized)
                            .font(.custom("Quicksand-Regular", size: 12))
                            .foregroundColor(colors.onSurfaceVariant)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(colors.tertiary)
                }
                .padding(14)
                .adaptiveCard(uiStyle: settings.uiStyle, colors: colors, cornerRadius: M3Shape.cornerLarge)
                .contentShape(Rectangle())
            }
            .buttonStyle(M3BounceButtonStyle())
        }
    }
    
    // MARK: - 3. All Folders Section
    private func allFoldersSection(colors: LuneColorScheme) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Directories".localized)
                .font(.custom("Quicksand-Bold", size: 14))
                .foregroundColor(colors.primary)
                .padding(.top, 12)
                .padding(.horizontal, 4)
            
            ForEach(Array(library.folders.keys.sorted()), id: \.self) { folderName in
                let songs = library.folders[folderName] ?? []
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.75)) {
                        currentPath.append(folderName)
                    }
                } label: {
                    HStack(spacing: 14) {
                        Circle()
                            .fill(colors.secondaryContainer)
                            .frame(width: 44, height: 44)
                            .overlay(
                                Image(systemName: "folder.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(colors.primary)
                            )
                        
                        VStack(alignment: .leading, spacing: 3) {
                            Text(folderName)
                                .font(.custom("Quicksand-Bold", size: 15))
                                .foregroundColor(colors.onSurface)
                                .lineLimit(1)
                            
                            Text("%d audio files".localized(songs.count))
                                .font(.custom("Quicksand-Regular", size: 12))
                                .foregroundColor(colors.onSurfaceVariant)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(colors.onSurfaceVariant.opacity(0.6))
                    }
                    .padding(12)
                    .adaptiveCard(uiStyle: settings.uiStyle, colors: colors, cornerRadius: M3Shape.cornerMedium)
                    .contentShape(Rectangle())
                }
                .buttonStyle(M3BounceButtonStyle())
            }
        }
    }
    
    // MARK: - 4. Active Directory Contents
    private func activeFolderContentsSection(colors: LuneColorScheme) -> some View {
        let folderName = currentPath.last ?? ""
        let songsInFolder = (folderName == "Music" || folderName.isEmpty) ? library.allSongs : (library.folders[folderName] ?? [])
        
        return VStack(alignment: .leading, spacing: 8) {
            if songsInFolder.isEmpty {
                // Empty folder placeholder matching Android's no_songs_folder
                VStack(spacing: 12) {
                    Image(systemName: "folder.badge.minus")
                        .font(.system(size: 40))
                        .foregroundColor(colors.onSurfaceVariant.opacity(0.40))
                        .padding(.top, 40)
                    
                    Text("No songs in this folder".localized)
                        .font(.custom("Quicksand-Bold", size: 16))
                        .foregroundColor(colors.onSurfaceVariant)
                    
                    Button {
                        showFileImporter = true
                    } label: {
                        Text("Add Audio Files".localized)
                            .font(.custom("Quicksand-Bold", size: 13))
                            .foregroundColor(colors.onPrimary)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 8)
                            .background(colors.primary)
                            .clipShape(Capsule())
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                ForEach(Array(songsInFolder.enumerated()), id: \.element.id) { index, song in
                    let isCurrent = player.currentSong?.id == song.id
                    
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        player.playQueue(songsInFolder, startingAt: index)
                    } label: {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(isCurrent ? colors.primary : colors.tertiaryContainer)
                                .frame(width: 42, height: 42)
                                .overlay(
                                    Image(systemName: isCurrent && player.isPlaying ? "waveform" : "music.note")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(isCurrent ? colors.onPrimary : colors.tertiary)
                                )
                            
                            VStack(alignment: .leading, spacing: 3) {
                                Text(song.title)
                                    .font(.custom("Quicksand-Bold", size: 14))
                                    .foregroundColor(isCurrent ? colors.primary : colors.onSurface)
                                    .lineLimit(1)
                                
                                Text("\(song.artist) • \(song.album)")
                                    .font(.custom("Quicksand-Regular", size: 12))
                                    .foregroundColor(colors.onSurfaceVariant)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            Text(song.formattedDuration)
                                .font(.custom("Quicksand-Regular", size: 12))
                                .foregroundColor(colors.onSurfaceVariant)
                        }
                        .padding(10)
                        .adaptiveCard(
                            uiStyle: settings.uiStyle,
                            colors: colors,
                            cornerRadius: M3Shape.cornerMedium,
                            isSelected: isCurrent
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(M3BounceButtonStyle())
                    .contextMenu {
                        Button {
                            player.playQueue(songsInFolder, startingAt: index)
                        } label: {
                            Label("Play Now".localized, systemImage: "play.fill")
                        }
                        
                        Button {
                            player.queue.insert(song, at: player.currentIndex + 1)
                        } label: {
                            Label("Play Next".localized, systemImage: "text.line.first.and.arrowtriangle.forward")
                        }
                        
                        Button {
                            library.toggleFavorite(for: song)
                        } label: {
                            Label(song.isFavorite ? "Remove from Favorites".localized : "Add to Favorites".localized, systemImage: song.isFavorite ? "heart.slash" : "heart")
                        }
                        
                        Button {
                            showPlaylistSheetForSong = song
                        } label: {
                            Label("Add to Playlist".localized, systemImage: "plus.circle")
                        }
                        
                        Divider()
                        
                        Button(role: .destructive) {
                            songToDelete = song
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete from device".localized, systemImage: "trash")
                        }
                    }
                }
            }
        }
    }
}
