//
//  MiniPlayerView.swift
//  Lune
//
//  Floating interactive Liquid Glass mini player capsule.
//  Parity with Android MiniPlayer with specular glass styling,
//  luminous progress bar, and fluid haptic feedback.
//

import SwiftUI

@MainActor
public struct MiniPlayerView: View {
    @ObservedObject var player: AudioPlayerManager
    let primaryColor: Color
    let onExpand: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    @MainActor
    public init(
        player: AudioPlayerManager = .shared,
        primaryColor: Color = Color(hex: 0xD0BCFF),
        onExpand: @escaping () -> Void
    ) {
        self.player = player
        self.primaryColor = primaryColor
        self.onExpand = onExpand
    }
    
    public var body: some View {
        if let song = player.currentSong {
            Button(action: onExpand) {
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        // Album Art
                        ZStack {
                            if let data = song.artworkData, let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 44, height: 44)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            } else {
                                ArtworkPlaceholderView(size: 44, cornerRadius: 10)
                            }
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.white.opacity(0.18), lineWidth: 0.8)
                        )
                        
                        // Title & Artist
                        VStack(alignment: .leading, spacing: 2) {
                            Text(song.title)
                                .font(.custom("Quicksand-Bold", size: 14))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            
                            Text(song.artist)
                                .font(.custom("Quicksand-Regular", size: 12))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        // Play/Pause Button
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            player.togglePlayPause()
                        } label: {
                            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(primaryColor)
                                .frame(width: 38, height: 38)
                                .background(
                                    Circle()
                                        .fill(primaryColor.opacity(colorScheme == .dark ? 0.22 : 0.14))
                                        .overlay(
                                            Circle()
                                                .stroke(primaryColor.opacity(0.4), lineWidth: 1)
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                        
                        // Next Track Button
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            player.next()
                        } label: {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)
                                .frame(width: 34, height: 34)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    
                    // Thin progress line at the bottom
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.primary.opacity(0.06))
                                .frame(height: 2.5)
                            
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [primaryColor.opacity(0.7), primaryColor],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * CGFloat(player.playbackProgress), height: 2.5)
                                .animation(.linear(duration: 0.25), value: player.playbackProgress)
                        }
                    }
                    .frame(height: 2.5)
                }
                .liquidGlass(
                    .regular,
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous),
                    interactive: true,
                    hasBorder: true,
                    shadowRadius: 12
                )
            }
            .buttonStyle(.plain)
        }
    }
}
