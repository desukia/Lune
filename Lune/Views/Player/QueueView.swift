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
    public init(player: AudioPlayerManager, primaryColor: Color = Color(hex: 0xD0BCFF)) {
        self.player = player
        self.primaryColor = primaryColor
    }
    
    @MainActor
    public init(primaryColor: Color = Color(hex: 0xD0BCFF)) {
        self.player = .shared
        self.primaryColor = primaryColor
    }
    
    public var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Currently Playing".localized).font(.custom("Quicksand-Bold", size: 13))) {
                    if let current = player.currentSong {
                        HStack(spacing: 12) {
                            if let img = ArtworkCache.shared.image(for: current.id, data: current.artworkData) {
                                Image(uiImage: img)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
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
                
                Section(header: Text("Up Next (%d)".localized(upNextSongs.count)).font(.custom("Quicksand-Bold", size: 13))) {
                    ForEach(Array(upNextSongs.enumerated()), id: \.element.id) { relativeIndex, song in
                        let originalIndex = player.currentIndex + 1 + relativeIndex
                        HStack(spacing: 12) {
                            Text("\(relativeIndex + 1)")
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
                            player.playQueue(player.queue, startingAt: originalIndex)
                        }
                    }
                    .onDelete { offsets in
                        let start = player.currentIndex + 1
                        let mappedIndices = IndexSet(offsets.map { $0 + start })
                        player.queue.remove(atOffsets: mappedIndices)
                    }
                    .onMove { source, destination in
                        let start = player.currentIndex + 1
                        let mappedSource = IndexSet(source.map { $0 + start })
                        let mappedDest = destination + start
                        player.queue.move(fromOffsets: mappedSource, toOffset: mappedDest)
                    }
                }
            }
            .navigationTitle("Play Queue".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done".localized) { dismiss() }
                        .font(.custom("Quicksand-Bold", size: 15))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
            }
        }
    }
    
    private var upNextSongs: [Song] {
        guard player.currentIndex + 1 < player.queue.count else { return [] }
        return Array(player.queue[(player.currentIndex + 1)...])
    }
}
