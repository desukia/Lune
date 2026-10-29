//
//  LyricsView.swift
//  Lune
//
//  Apple Music karaoke-style synchronized lyrics viewer and timing editor.
//  Features dynamic artwork bloom, blurred inactive lines, glowing active line,
//  and auto-fetching via Vagalume and LRCLIB.
//

import SwiftUI

@MainActor
public struct LyricsView: View {
    let currentSong: Song?
    let currentTime: TimeInterval
    let onSeek: (TimeInterval) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @ObservedObject private var lyricsManager = LyricsManager.shared
    @State private var timeOffset: TimeInterval = 0.0
    @State private var isEditing: Bool = false
    @State private var editableLrcText: String = ""
    
    public init(currentSong: Song?, currentTime: TimeInterval, onSeek: @escaping (TimeInterval) -> Void) {
        self.currentSong = currentSong
        self.currentTime = currentTime
        self.onSeek = onSeek
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                // Background Ambient Artwork
                backgroundBackdrop
                
                if isEditing {
                    TextEditor(text: $editableLrcText)
                        .padding()
                        .font(.custom("Quicksand-Regular", size: 14))
                        .scrollContentBackground(.hidden)
                        .background(Color.black.opacity(0.40))
                } else if lyricsManager.isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.4)
                        Text("Searching lyrics on Vagalume...")
                            .font(.custom("Quicksand-Bold", size: 15))
                            .foregroundColor(.white.opacity(0.80))
                    }
                } else if lyricsManager.lines.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "quote.bubble")
                            .font(.system(size: 48))
                            .foregroundColor(.white.opacity(0.50))
                        
                        Text("No lyrics available")
                            .font(.custom("Quicksand-Bold", size: 18))
                            .foregroundColor(.white)
                        
                        Text("Lyrics could not be found for this track.")
                            .font(.custom("Quicksand-Regular", size: 14))
                            .foregroundColor(.white.opacity(0.65))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        
                        HStack(spacing: 12) {
                            Button {
                                if let song = currentSong {
                                    Task { await lyricsManager.fetchLyrics(for: song) }
                                }
                            } label: {
                                Label("Search Again", systemImage: "arrow.clockwise")
                                    .font(.custom("Quicksand-Bold", size: 14))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 18)
                                    .padding(.vertical, 10)
                                    .liquidGlass(.regular, in: Capsule())
                            }
                            
                            Button {
                                isEditing = true
                            } label: {
                                Label("Add Manually", systemImage: "pencil")
                                    .font(.custom("Quicksand-Bold", size: 14))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 18)
                                    .padding(.vertical, 10)
                                    .liquidGlass(.regular, in: Capsule())
                            }
                        }
                        .padding(.top, 8)
                    }
                } else {
                    // Apple Music Scrolling Karaoke Lyrics
                    ScrollViewReader { proxy in
                        ScrollView(showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 24) {
                                Spacer(minLength: 40)
                                
                                ForEach(Array(lyricsManager.lines.enumerated()), id: \.element.id) { index, line in
                                    let isActive = activeLineIndex == index
                                    
                                    Button {
                                        if line.timestamp >= 0 {
                                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                            onSeek(line.timestamp)
                                        }
                                    } label: {
                                        Text(line.text)
                                            .font(.custom("Quicksand-Bold", size: 24))
                                            .foregroundColor(isActive ? Color.white : Color.white.opacity(0.35))
                                            .multilineTextAlignment(.leading)
                                            .scaleEffect(isActive ? 1.02 : 1.0, anchor: .leading)
                                            .shadow(color: isActive ? Color.white.opacity(0.35) : Color.clear, radius: 8, x: 0, y: 0)
                                            .padding(.horizontal, 28)
                                            .padding(.vertical, 6)
                                            .animation(.easeInOut(duration: 0.28), value: isActive)
                                    }
                                    .buttonStyle(.plain)
                                    .id(index)
                                }
                                
                                Spacer(minLength: 80)
                            }
                        }
                        .mask(
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0.0),
                                    .init(color: .black, location: 0.07),
                                    .init(color: .black, location: 0.88),
                                    .init(color: .clear, location: 1.0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .onChange(of: activeLineIndex) { _, newIndex in
                            if let idx = newIndex {
                                withAnimation(.easeInOut(duration: 0.45)) {
                                    proxy.scrollTo(idx, anchor: .center)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(currentSong?.title ?? "Lyrics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if isEditing {
                        Button("Cancel") { isEditing = false }
                            .foregroundColor(.white)
                    } else {
                        Button("Done") { dismiss() }
                            .font(.custom("Quicksand-Bold", size: 15))
                            .foregroundColor(.white)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if isEditing {
                        Button("Save") {
                            let parsed = lyricsManager.parseLrc(editableLrcText)
                            lyricsManager.lines = parsed
                            if let songId = currentSong?.id {
                                MusicLibraryManager.shared.updateLyrics(for: songId, lyrics: editableLrcText)
                            }
                            isEditing = false
                        }
                        .font(.custom("Quicksand-Bold", size: 15))
                        .foregroundColor(.white)
                    } else if !lyricsManager.lines.isEmpty {
                        Button("Edit") {
                            editableLrcText = lyricsManager.exportLrc(lines: lyricsManager.lines)
                            isEditing = true
                        }
                        .foregroundColor(.white.opacity(0.85))
                    }
                }
            }
            .task {
                if let song = currentSong {
                    await lyricsManager.fetchLyrics(for: song)
                }
            }
        }
    }
    
    private var activeLineIndex: Int? {
        lyricsManager.findActiveLineIndex(lines: lyricsManager.lines, currentTime: currentTime + timeOffset)
    }
    
    @ViewBuilder
    private var backgroundBackdrop: some View {
        ZStack {
            if let data = currentSong?.artworkData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .blur(radius: 65)
                    .overlay(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.50),
                                Color.black.opacity(0.85)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .ignoresSafeArea()
            } else {
                Color(hex: 0x141022)
                    .ignoresSafeArea()
            }
        }
    }
}
