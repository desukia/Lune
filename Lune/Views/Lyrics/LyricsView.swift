//
//  LyricsView.swift
//  Lune
//
//  Material 3 Expressive synchronized lyrics viewer and timing editor (1:1 Android Lune LyricsActivity).
//  Features dynamic artwork bloom, blurred inactive lines, glowing active line with spring bounce,
//  alignment toggle, timing offset controls, and auto-fetching via Vagalume and LRCLIB.
//

import SwiftUI

@MainActor
public struct LyricsView: View {
    let currentSong: Song?
    let currentTime: TimeInterval
    let onSeek: (TimeInterval) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @ObservedObject private var lyricsManager: LyricsManager
    @ObservedObject private var settings = SettingsManager.shared
    
    @State private var timeOffset: TimeInterval = 0.0
    @State private var showOffsetBar: Bool = false
    @State private var textAlign: TextAlignment = .leading
    @State private var isEditing: Bool = false
    @State private var editableLrcText: String = ""
    
    public init(currentSong: Song?, currentTime: TimeInterval, onSeek: @escaping (TimeInterval) -> Void) {
        self.currentSong = currentSong
        self.currentTime = currentTime
        self.onSeek = onSeek
        self.lyricsManager = .shared
    }
    
    public var body: some View {
        let colors = settings.resolveColors(for: colorScheme)
        let isDark = colors.isDark
        
        NavigationStack {
            ZStack {
                // Background Ambient Artwork
                backgroundBackdrop(colors: colors)
                
                VStack(spacing: 0) {
                    // Top Toolbar (Timing Sync & Alignment)
                    if !isEditing {
                        topLyricsToolbar(colors: colors)
                            .padding(.horizontal, 16)
                            .padding(.top, 4)
                            .padding(.bottom, 6)
                        
                        // Collapsible Timing Offset Control Bar
                        if showOffsetBar {
                            timingOffsetControlBar(colors: colors)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 8)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    
                    if isEditing {
                        TextEditor(text: $editableLrcText)
                            .padding()
                            .font(.custom("Quicksand-Regular", size: 14))
                            .scrollContentBackground(.hidden)
                            .background(isDark ? Color.black.opacity(0.40) : Color.white.opacity(0.85))
                            .foregroundColor(colors.onSurface)
                    } else if lyricsManager.isLoading {
                        VStack(spacing: 16) {
                            ProgressView()
                                .tint(colors.onSurface)
                                .scaleEffect(1.3)
                            Text("Searching lyrics on LRCLIB & Vagalume...")
                                .font(.custom("Quicksand-Bold", size: 15))
                                .foregroundColor(colors.onSurfaceVariant)
                        }
                        .frame(maxHeight: .infinity)
                    } else if lyricsManager.lines.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "quote.bubble")
                                .font(.system(size: 46))
                                .foregroundColor(colors.onSurfaceVariant.opacity(0.50))
                            
                            Text("No lyrics available")
                                .font(.custom("Quicksand-Bold", size: 18))
                                .foregroundColor(colors.onSurface)
                            
                            Text("Lyrics could not be found for this track.")
                                .font(.custom("Quicksand-Regular", size: 14))
                                .foregroundColor(colors.onSurfaceVariant)
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
                                        .foregroundColor(isDark ? Color.black : Color.white)
                                        .padding(.horizontal, 18)
                                        .padding(.vertical, 10)
                                        .background(
                                            Capsule()
                                                .fill(isDark ? Color.white : Color(hex: 0x141414))
                                        )
                                }
                                .buttonStyle(M3BounceButtonStyle())
                                
                                Button {
                                    isEditing = true
                                } label: {
                                    Label("Add Manually", systemImage: "pencil")
                                        .font(.custom("Quicksand-Bold", size: 14))
                                        .foregroundColor(colors.onSurface)
                                        .padding(.horizontal, 18)
                                        .padding(.vertical, 10)
                                        .background(
                                            Capsule()
                                                .fill(isDark ? Color.white.opacity(0.14) : Color.black.opacity(0.08))
                                        )
                                }
                                .buttonStyle(M3BounceButtonStyle())
                            }
                            .padding(.top, 8)
                        }
                        .frame(maxHeight: .infinity)
                    } else {
                        // Scrolling Karaoke Lyrics with Center Focus
                        ScrollViewReader { proxy in
                            ScrollView(showsIndicators: false) {
                                VStack(alignment: textAlign == .center ? .center : .leading, spacing: 22) {
                                    Spacer(minLength: 40)
                                    
                                    ForEach(Array(lyricsManager.lines.enumerated()), id: \.element.id) { index, line in
                                        let isActive = activeLineIndex == index
                                        
                                        Button {
                                            if line.timestamp >= 0 {
                                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                                onSeek(max(0, line.timestamp - timeOffset))
                                            }
                                        } label: {
                                            Text(line.text)
                                                .font(.custom("Quicksand-Bold", size: isActive ? 26 : 22))
                                                .foregroundColor(
                                                    isActive
                                                        ? colors.onSurface
                                                        : colors.onSurface.opacity(0.35)
                                                )
                                                .multilineTextAlignment(textAlign)
                                                .frame(maxWidth: .infinity, alignment: textAlign == .center ? .center : .leading)
                                                .scaleEffect(isActive ? 1.08 : 1.0, anchor: textAlign == .center ? .center : .leading)
                                                .shadow(
                                                    color: isActive ? (isDark ? Color.white.opacity(0.35) : Color.black.opacity(0.12)) : Color.clear,
                                                    radius: isActive ? 8 : 0,
                                                    x: 0,
                                                    y: 0
                                                )
                                                .padding(.horizontal, 28)
                                                .padding(.vertical, 6)
                                                .animation(.spring(response: 0.35, dampingFraction: 0.65), value: isActive)
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
                                    withAnimation(.easeInOut(duration: 0.40)) {
                                        proxy.scrollTo(idx, anchor: .center)
                                    }
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
                            .foregroundColor(colors.onSurface)
                    } else {
                        Button("Done") { dismiss() }
                            .font(.custom("Quicksand-Bold", size: 15))
                            .foregroundColor(colors.onSurface)
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
                        .foregroundColor(colors.onSurface)
                    } else if !lyricsManager.lines.isEmpty {
                        Button("Edit") {
                            editableLrcText = lyricsManager.exportLrc(lines: lyricsManager.lines)
                            isEditing = true
                        }
                        .foregroundColor(colors.onSurfaceVariant)
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
    
    // MARK: - Top Lyrics Toolbar
    private func topLyricsToolbar(colors: LuneColorScheme) -> some View {
        let isDark = colors.isDark
        
        return HStack {
            if lyricsManager.isSynced {
                Text("SYNCED")
                    .font(.custom("Quicksand-Bold", size: 9))
                    .foregroundColor(colors.onSurface)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(isDark ? Color.white.opacity(0.18) : Color.black.opacity(0.08))
                    )
            }
            
            if timeOffset != 0 {
                Text(String(format: "Offset: %+.1fs", timeOffset))
                    .font(.custom("Quicksand-Medium", size: 11))
                    .foregroundColor(colors.onSurfaceVariant)
            }
            
            Spacer()
            
            // Divided Pill Toolbar: [ Alignment | Timing Offset ]
            HStack(spacing: 0) {
                // 1. Text Alignment Toggle
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.70)) {
                        textAlign = (textAlign == .leading) ? .center : .leading
                    }
                } label: {
                    Image(systemName: textAlign == .leading ? "text.alignleft" : "text.aligncenter")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(colors.onSurface)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(M3BounceButtonStyle(scale: 0.92))
                
                // Divider
                Rectangle()
                    .fill(isDark ? Color.white.opacity(0.20) : Color.black.opacity(0.14))
                    .frame(width: 1, height: 16)
                
                // 2. Timing Offset Toggle
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.75)) {
                        showOffsetBar.toggle()
                    }
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(showOffsetBar ? (isDark ? Color.black : Color.white) : colors.onSurface)
                        .frame(width: 36, height: 36)
                        .background(
                            Group {
                                if showOffsetBar {
                                    Circle().fill(colors.onSurface)
                                } else {
                                    Color.clear
                                }
                            }
                        )
                }
                .buttonStyle(M3BounceButtonStyle(scale: 0.92))
            }
            .padding(.horizontal, 4)
            .frame(height: 38)
            .background(
                Capsule()
                    .fill(isDark ? Color.white.opacity(0.14) : Color.black.opacity(0.08))
                    .overlay(
                        Capsule()
                            .stroke(isDark ? Color.white.opacity(0.16) : Color.black.opacity(0.10), lineWidth: 0.8)
                    )
            )
        }
    }
    
    // MARK: - Timing Offset Control Bar
    private func timingOffsetControlBar(colors: LuneColorScheme) -> some View {
        let isDark = colors.isDark
        
        return HStack(spacing: 8) {
            timingButton(label: "-0.5s", colors: colors) { timeOffset -= 0.5 }
            timingButton(label: "-0.1s", colors: colors) { timeOffset -= 0.1 }
            
            if timeOffset != 0 {
                Button("Reset") {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation { timeOffset = 0 }
                }
                .font(.custom("Quicksand-Bold", size: 11))
                .foregroundColor(colors.onSurface)
                .padding(.horizontal, 8)
            }
            
            Spacer()
            
            timingButton(label: "+0.1s", colors: colors) { timeOffset += 0.1 }
            timingButton(label: "+0.5s", colors: colors) { timeOffset += 0.5 }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isDark ? Color(hex: 0x1E1E1E) : Color(hex: 0xEAEAEA))
        )
    }
    
    private func timingButton(label: String, colors: LuneColorScheme, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.25, dampingFraction: 0.70)) {
                action()
            }
        } label: {
            Text(label)
                .font(.custom("Quicksand-Bold", size: 11.5))
                .foregroundColor(colors.onSurface)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(colors.isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.08))
                )
        }
        .buttonStyle(M3BounceButtonStyle(scale: 0.94))
    }
    
    private var activeLineIndex: Int? {
        lyricsManager.findActiveLineIndex(lines: lyricsManager.lines, currentTime: currentTime + timeOffset)
    }
    
    @ViewBuilder
    private func backgroundBackdrop(colors: LuneColorScheme) -> some View {
        let isDark = colors.isDark
        
        ZStack {
            (isDark ? Color.black : colors.background)
                .ignoresSafeArea()
            
            if let data = currentSong?.artworkData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .blur(radius: 65)
                    .opacity(isDark ? 0.40 : 0.18)
                    .overlay(
                        LinearGradient(
                            colors: isDark
                                ? [Color.black.opacity(0.50), Color.black.opacity(0.85)]
                                : [Color.white.opacity(0.65), Color.white.opacity(0.88)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .ignoresSafeArea()
            }
        }
    }
}
