//
//  FoldersView.swift
//  Lune
//
//  Folder browser for local audio files matching Android FolderBrowserActivity.kt.
//

import SwiftUI

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
    @State private var selectedFolderItem: FolderItem? = nil
    
    public init(library: MusicLibraryManager, player: AudioPlayerManager) {
        self.library = library
        self.player = player
    }
    
    public init(library: MusicLibraryManager) {
        self.library = library
        self.player = .shared
    }
    
    public init() {
        self.library = .shared
        self.player = .shared
    }
    
    public var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(Array(library.folders.keys.sorted()), id: \.self) { folderName in
                    let songs = library.folders[folderName] ?? []
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        selectedFolderItem = FolderItem(name: folderName, songs: songs)
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(LinearGradient(colors: [Color(hex: 0x554492), Color(hex: 0x8C74D9)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 48, height: 48)
                                Image(systemName: "folder.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(.white)
                            }
                            
                            VStack(alignment: .leading, spacing: 3) {
                                Text(folderName)
                                    .font(.custom("Quicksand-Bold", size: 15))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                Text("\(songs.count) audio tracks")
                                    .font(.custom("Quicksand-Regular", size: 12))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        .padding(12)
                        .liquidGlass(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 160)
        }
        .sheet(item: $selectedFolderItem) { item in
            NavigationStack {
                FolderDetailView(folderName: item.name, songs: item.songs)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") {
                                selectedFolderItem = nil
                            }
                            .font(.custom("Quicksand-Bold", size: 15))
                        }
                    }
            }
        }
    }
}

@MainActor
public struct FolderDetailView: View {
    let folderName: String
    let songs: [Song]
    @ObservedObject var player: AudioPlayerManager = .shared
    
    public var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                    SongRowView(
                        song: song,
                        isCurrentSong: player.currentSong?.id == song.id,
                        isPlaying: player.isPlaying,
                        onPlay: { player.playQueue(songs, startingAt: index) }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 160)
        }
        .navigationTitle(folderName)
        .navigationBarTitleDisplayMode(.inline)
    }
}
