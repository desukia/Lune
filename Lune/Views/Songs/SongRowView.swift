//
//  SongRowView.swift
//  Lune
//
//  Song row component with artwork, Hi-Fi badge, and context menus.
//  Supports Material You (Material 3 Expressive connected shapes) and Liquid Glass.
//

import SwiftUI

public enum RowPosition {
    case first
    case middle
    case last
    case single
}

public struct GroupedCardShape: Shape {
    var topLeading: CGFloat
    var bottomLeading: CGFloat
    var bottomTrailing: CGFloat
    var topTrailing: CGFloat
    
    public init(topLeading: CGFloat, bottomLeading: CGFloat, bottomTrailing: CGFloat, topTrailing: CGFloat) {
        self.topLeading = topLeading
        self.bottomLeading = bottomLeading
        self.bottomTrailing = bottomTrailing
        self.topTrailing = topTrailing
    }
    
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let tl = min(topLeading, min(rect.width / 2, rect.height / 2))
        let tr = min(topTrailing, min(rect.width / 2, rect.height / 2))
        let bl = min(bottomLeading, min(rect.width / 2, rect.height / 2))
        let br = min(bottomTrailing, min(rect.width / 2, rect.height / 2))
        
        path.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        path.addArc(center: CGPoint(x: rect.maxX - tr, y: rect.minY + tr), radius: tr, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        path.addArc(center: CGPoint(x: rect.maxX - br, y: rect.maxY - br), radius: br, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
        path.addArc(center: CGPoint(x: rect.minX + bl, y: rect.maxY - bl), radius: bl, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
        path.addArc(center: CGPoint(x: rect.minX + tl, y: rect.minY + tl), radius: tl, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        path.closeSubpath()
        return path
    }
}

@MainActor
public struct SongRowView: View {
    let song: Song
    let isCurrentSong: Bool
    let isPlaying: Bool
    let position: RowPosition
    let primaryColor: Color
    let onPlay: () -> Void
    let onToggleFavorite: () -> Void
    let onAddToPlaylist: () -> Void
    
    @ObservedObject private var settings: SettingsManager
    @Environment(\.colorScheme) private var colorScheme
    
    public init(
        song: Song,
        isCurrentSong: Bool = false,
        isPlaying: Bool = false,
        position: RowPosition = .single,
        primaryColor: Color = Color(hex: 0xD0BCFF),
        onPlay: @escaping () -> Void,
        onToggleFavorite: @escaping () -> Void = {},
        onAddToPlaylist: @escaping () -> Void = {}
    ) {
        self.song = song
        self.isCurrentSong = isCurrentSong
        self.isPlaying = isPlaying
        self.position = position
        self.primaryColor = primaryColor
        self.onPlay = onPlay
        self.onToggleFavorite = onToggleFavorite
        self.onAddToPlaylist = onAddToPlaylist
        self.settings = .shared
    }
    
    public var body: some View {
        let colors = settings.resolveColors(for: colorScheme)
        let isM3 = settings.uiStyle == .materialYou
        
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onPlay()
        } label: {
            HStack(spacing: 12) {
                // Artwork (48x48 rounded 12dp)
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
                            .fill(colors.primary.opacity(0.85))
                            .frame(width: 24, height: 24)
                            .overlay(Image(systemName: "waveform").font(.system(size: 11, weight: .bold)).foregroundColor(.white))
                    }
                }
                
                // Metadata (Supporting Content: duration • artist + bitrate)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(song.title)
                            .font(.custom("Quicksand-Bold", size: 15))
                            .foregroundColor(isCurrentSong ? colors.primary : (isM3 ? colors.onSurface : .primary))
                            .lineLimit(1)
                        
                        if song.isHiFi {
                            HiFiBadge(isHiRes: song.isHiRes)
                        }
                    }
                    
                    Text("\(song.formattedDuration) • \(song.artist)")
                        .font(.custom("Quicksand-Regular", size: 12))
                        .foregroundColor(isM3 ? colors.onSurfaceVariant : .secondary)
                        .lineLimit(1)
                    
                    if isM3 {
                        let bitrateText = song.isHiFi ? "FLAC | 1000kbps" : "MP3 | 320kbps"
                        Text(bitrateText)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(colors.onSurfaceVariant.opacity(0.60))
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // Trailing: Favorite Button + 3-dots Menu Button
                HStack(spacing: 6) {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onToggleFavorite()
                    } label: {
                        Image(systemName: song.isFavorite ? "heart.fill" : "heart")
                            .font(.system(size: 16))
                            .foregroundColor(song.isFavorite ? Color(hex: 0xEF4444) : (isM3 ? colors.onSurfaceVariant.opacity(0.40) : Color.secondary.opacity(0.35)))
                            .padding(6)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    
                    Menu {
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
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(isM3 ? colors.onSurfaceVariant.opacity(0.70) : .secondary)
                            .frame(width: 30, height: 30)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(isM3 ? colors.primary.opacity(0.08) : Color.clear)
                            )
                    }
                }
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 14)
            .padding(.vertical, isM3 ? 8 : 10)
            .background {
                if isM3 {
                    let cardShape: GroupedCardShape = {
                        switch position {
                        case .first:
                            return GroupedCardShape(topLeading: 28, bottomLeading: 4, bottomTrailing: 4, topTrailing: 28)
                        case .middle:
                            return GroupedCardShape(topLeading: 4, bottomLeading: 4, bottomTrailing: 4, topTrailing: 4)
                        case .last:
                            return GroupedCardShape(topLeading: 4, bottomLeading: 28, bottomTrailing: 28, topTrailing: 4)
                        case .single:
                            return GroupedCardShape(topLeading: 28, bottomLeading: 28, bottomTrailing: 28, topTrailing: 28)
                        }
                    }()
                    
                    cardShape
                        .fill(isCurrentSong ? colors.primaryContainer.opacity(0.70) : colors.secondaryContainer.opacity(0.40))
                } else {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.clear)
                        .liquidGlass(
                            .regular,
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous),
                            interactive: false,
                            hasBorder: true,
                            shadowRadius: 6
                        )
                }
            }
        }
        .buttonStyle(M3BounceButtonStyle(scale: 0.98))
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
