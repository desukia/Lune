//
//  AiMixDetailView.swift
//  Lune
//
//  Detail tracklist view for personalized AI mixes.
//

import SwiftUI

@MainActor
public struct AiMixDetailView: View {
    let mix: AiMix
    @ObservedObject var player: AudioPlayerManager
    let primaryColor: Color
    @Environment(\.dismiss) private var dismiss
    
    @MainActor
    public init(mix: AiMix, player: AudioPlayerManager = .shared, primaryColor: Color = Color(hex: 0xD0BCFF)) {
        self.mix = mix
        self.player = player
        self.primaryColor = primaryColor
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header card with mix gradient
                    ZStack {
                        LinearGradient(
                            colors: mix.gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        
                        VStack(spacing: 12) {
                            Image(systemName: mix.iconName)
                                .font(.system(size: 44, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text(mix.title)
                                .font(.custom("Quicksand-Bold", size: 24))
                                .foregroundColor(.white)
                            
                            Text(mix.description)
                                .font(.custom("Quicksand-Regular", size: 14))
                                .foregroundColor(.white.opacity(0.85))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                            
                            // Play All & Smart Shuffle buttons
                            HStack(spacing: 16) {
                                Button {
                                    player.playQueue(mix.songs)
                                    dismiss()
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "play.fill")
                                        Text("Play All")
                                            .font(.custom("Quicksand-Bold", size: 14))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 22)
                                    .padding(.vertical, 12)
                                    .background(Capsule().fill(Color.white.opacity(0.25)))
                                    .overlay(Capsule().stroke(Color.white.opacity(0.4), lineWidth: 1))
                                }
                                
                                Button {
                                    let shuffled = LuneAiEngine.shared.generateSmartShuffle(mix.songs)
                                    player.playQueue(shuffled)
                                    dismiss()
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "shuffle")
                                        Text("Smart Shuffle")
                                            .font(.custom("Quicksand-Bold", size: 14))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 22)
                                    .padding(.vertical, 12)
                                    .background(Capsule().fill(Color.white.opacity(0.25)))
                                    .overlay(Capsule().stroke(Color.white.opacity(0.4), lineWidth: 1))
                                }
                            }
                            .padding(.top, 8)
                        }
                        .padding(.vertical, 32)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .padding(.horizontal, 16)
                    
                    // Track list
                    LazyVStack(spacing: 8) {
                        ForEach(Array(mix.songs.enumerated()), id: \.element.id) { index, song in
                            Button {
                                player.playQueue(mix.songs, startingAt: index)
                                dismiss()
                            } label: {
                                HStack(spacing: 14) {
                                    Text("\(index + 1)")
                                        .font(.custom("Quicksand-Bold", size: 13))
                                        .foregroundColor(.secondary)
                                        .frame(width: 24)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(song.title)
                                            .font(.custom("Quicksand-Bold", size: 15))
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                        Text(song.artist)
                                            .font(.custom("Quicksand-Regular", size: 13))
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    Text(song.formattedDuration)
                                        .font(.custom("Quicksand-Regular", size: 12))
                                        .foregroundColor(.secondary)
                                }
                                .padding(12)
                                .liquidGlass(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .navigationTitle(mix.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .font(.custom("Quicksand-Bold", size: 15))
                }
            }
        }
    }
}
