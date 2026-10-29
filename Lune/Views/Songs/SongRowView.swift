//
//  SongRowView.swift
//  Lune
//
//  Song row component with artwork, Hi-Fi badge, and context menus.
//

import SwiftUI

@MainActor
public struct SongRowView: View {
    let song: Song
    let isCurrentSong: Bool
    let isPlaying: Bool
    let primaryColor: Color
    let onPlay: () -> Void
    let onToggleFavorite: () -> Void
    let onAddToPlaylist: () -> Void
    
    public init(
        song: Song,
        isCurrentSong: Bool = false,
        isPlaying: Bool = false,
        primaryColor: Color = Color(hex: 0xD0BCFF),
        onPlay: @escaping () -> Void,
        onToggleFavorite: @escaping () -> Void = {},
        onAddToPlaylist: @escaping () -> Void = {}
    ) {
        self.song = song
        self.isCurrentSong = isCurrentSong
        self.isPlaying = isPlaying
        self.primaryColor = primaryColor
        self.onPlay = onPlay
        self.onToggleFavorite = onToggleFavorite
        self.onAddToPlaylist = onAddToPlaylist
    }
    
    public var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onPlay()
        } label: {
            HStack(spacing: 12) {
                // Artwork
                ZStack {
                    if let data = song.artworkData, let img = UIImage(data: data) {
                        Image(uiImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 48, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    } else {
                        ArtworkPlaceholderView(size: 48, cornerRadius: 12)
                    }
                    
                    if isCurrentSong && isPlaying {
                        Circle()
                            .fill(primaryColor.opacity(0.85))
                            .frame(width: 24, height: 24)
                            .overlay(Image(systemName: "waveform").font(.system(size: 11, weight: .bold)).foregroundColor(.white))
                    }
                }
                
                // Metadata
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(song.title)
                            .font(.custom("Quicksand-Bold", size: 15))
                            .foregroundColor(isCurrentSong ? primaryColor : .primary)
                            .lineLimit(1)
                        
                        if song.isHiFi {
                            HiFiBadge(isHiRes: song.isHiRes)
                        }
                    }
                    
                    Text("\(song.artist) • \(song.album)")
                        .font(.custom("Quicksand-Regular", size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Favorite Heart Button
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onToggleFavorite()
                } label: {
                    Image(systemName: song.isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 15))
                        .foregroundColor(song.isFavorite ? Color(hex: 0xEF4444) : Color.secondary.opacity(0.35))
                        .padding(6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                // Duration
                Text(song.formattedDuration)
                    .font(.custom("Quicksand-Regular", size: 12))
                    .foregroundColor(.secondary)
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .liquidGlass(
                isCurrentSong ? .tinted(primaryColor, opacity: 0.12) : .regular,
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                onPlay()
            } label: {
                Label("Play Now", systemImage: "play.fill")
            }
            
            Button {
                AudioPlayerManager.shared.queue.insert(song, at: AudioPlayerManager.shared.currentIndex + 1)
            } label: {
                Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward")
            }
            
            Button {
                onToggleFavorite()
            } label: {
                Label(song.isFavorite ? "Remove from Favorites" : "Add to Favorites", systemImage: song.isFavorite ? "heart.slash" : "heart")
            }
            
            Button {
                onAddToPlaylist()
            } label: {
                Label("Add to Playlist", systemImage: "plus.circle")
            }
        }
    }
}
