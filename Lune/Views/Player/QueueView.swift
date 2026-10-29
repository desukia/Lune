//
//  QueueView.swift
//  Lune
//
//  Reorderable up-next queue modal.
//

import SwiftUI

@MainActor
public struct QueueView: View {
    @ObservedObject var player: AudioPlayerManager
    let primaryColor: Color
    @Environment(\.dismiss) private var dismiss
    
    @MainActor
    public init(player: AudioPlayerManager = .shared, primaryColor: Color = Color(hex: 0xD0BCFF)) {
        self.player = player
        self.primaryColor = primaryColor
    }
    
    public var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Currently Playing").font(.custom("Quicksand-Bold", size: 13))) {
                    if let current = player.currentSong {
                        HStack(spacing: 12) {
                            if let data = current.artworkData, let img = UIImage(data: data) {
                                Image(uiImage: img)
                                    .resizable()
                                    .frame(width: 44, height: 44)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            } else {
                                ArtworkPlaceholderView(size: 44, cornerRadius: 8)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(current.title)
                                    .font(.custom("Quicksand-Bold", size: 15))
                                    .foregroundColor(primaryColor)
                                Text(current.artist)
                                    .font(.custom("Quicksand-Regular", size: 13))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "waveform")
                                .foregroundColor(primaryColor)
                        }
                    }
                }
                
                Section(header: Text("Up Next (\(max(0, player.queue.count - player.currentIndex - 1)))").font(.custom("Quicksand-Bold", size: 13))) {
                    ForEach(Array(player.queue.enumerated()), id: \.element.id) { index, song in
                        if index > player.currentIndex {
                            HStack(spacing: 12) {
                                Text("\(index - player.currentIndex)")
                                    .font(.custom("Quicksand-Bold", size: 12))
                                    .foregroundColor(.secondary)
                                    .frame(width: 20)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(song.title)
                                        .font(.custom("Quicksand-Bold", size: 14))
                                    Text(song.artist)
                                        .font(.custom("Quicksand-Regular", size: 12))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                player.playQueue(player.queue, startingAt: index)
                            }
                        }
                    }
                    .onDelete { indexSet in
                        player.queue.remove(atOffsets: indexSet)
                    }
                    .onMove { indices, newOffset in
                        player.queue.move(fromOffsets: indices, toOffset: newOffset)
                    }
                }
            }
            .navigationTitle("Play Queue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .font(.custom("Quicksand-Bold", size: 15))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
            }
        }
    }
}
