//
//  VinylRecordView.swift
//  Lune
//
//  Album artwork & vinyl record with dynamic ambient bloom glow,
//  continuous corner geometry, tactile spring bounce, and swipe gestures.
//

import SwiftUI

@MainActor
public struct VinylRecordView: View {
    let artworkData: Data?
    let isPlaying: Bool
    let size: CGFloat
    let shape: PlayerCoverShape
    let allowSpin: Bool
    let onSwipeLeft: (() -> Void)?
    let onSwipeRight: (() -> Void)?
    let onTap: (() -> Void)?
    
    @State private var rotationDegrees: Double = 0
    @State private var isPressed: Bool = false
    @State private var dragOffset: CGFloat = 0
    
    public init(
        artworkData: Data?,
        isPlaying: Bool,
        size: CGFloat = 280,
        shape: PlayerCoverShape = .rounded,
        allowSpin: Bool = true,
        onSwipeLeft: (() -> Void)? = nil,
        onSwipeRight: (() -> Void)? = nil,
        onTap: (() -> Void)? = nil
    ) {
        self.artworkData = artworkData
        self.isPlaying = isPlaying
        self.size = size
        self.shape = shape
        self.allowSpin = allowSpin
        self.onSwipeLeft = onSwipeLeft
        self.onSwipeRight = onSwipeRight
        self.onTap = onTap
    }
    
    public var body: some View {
        Group {
            switch shape {
            case .circle:
                vinylDiscView
            case .rounded:
                roundedArtworkView
            case .square:
                squareArtworkView
            }
        }
        .offset(x: dragOffset)
        .scaleEffect(isPressed ? 0.96 : 1.0)
        .animation(.spring(response: 0.28, dampingFraction: 0.70), value: isPressed)
        .animation(.interactiveSpring(response: 0.35, dampingFraction: 0.75), value: dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation.width * 0.4
                }
                .onEnded { value in
                    let threshold: CGFloat = 60
                    if value.translation.width < -threshold {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onSwipeLeft?()
                    } else if value.translation.width > threshold {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onSwipeRight?()
                    }
                    dragOffset = 0
                }
        )
        .onTapGesture {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.70)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.70)) {
                    isPressed = false
                }
                onTap?()
            }
        }
    }
    
    // MARK: - Rounded Artwork Mode (Default Premium Cover)
    private var roundedArtworkView: some View {
        ZStack {
            // Ambient Colorful Bloom Glow behind the artwork
            if let data = artworkData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size * 0.94, height: size * 0.94)
                    .blur(radius: 34)
                    .opacity(0.55)
                    .offset(y: 12)
            }
            
            // Primary Cover Artwork
            ZStack {
                if let data = artworkData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size, height: size)
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                } else {
                    ArtworkPlaceholderView(size: size, cornerRadius: 28)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.35), Color.white.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            )
            .shadow(color: Color.black.opacity(0.35), radius: 24, x: 0, y: 12)
        }
    }
    
    // MARK: - Vinyl Disc Mode
    private var vinylDiscView: some View {
        ZStack {
            // Outer Vinyl Disc
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: 0x1A1A1A),
                            Color(hex: 0x111111),
                            Color(hex: 0x141414),
                            Color(hex: 0x080808)
                        ],
                        center: .center,
                        startRadius: size * 0.22,
                        endRadius: size * 0.50
                    )
                )
                .frame(width: size, height: size)
                .overlay(
                    Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: 0.6)
                )
                .shadow(color: Color.black.opacity(0.45), radius: 20, x: 0, y: 12)
            
            // Vinyl Grooves
            ForEach(1..<6) { i in
                Circle()
                    .stroke(Color.white.opacity(0.035), lineWidth: 1.0)
                    .frame(width: size * (0.44 + CGFloat(i) * 0.09), height: size * (0.44 + CGFloat(i) * 0.09))
            }
            
            // Center Album Art Label
            ZStack {
                if let data = artworkData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size * 0.44, height: size * 0.44)
                        .clipShape(Circle())
                } else {
                    ArtworkPlaceholderView(size: size * 0.44, cornerRadius: size * 0.22)
                }
                
                // Spindle Hole
                Circle()
                    .fill(Color(hex: 0x0A0A0A))
                    .frame(width: size * 0.09, height: size * 0.09)
                    .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
            }
            .overlay(Circle().strokeBorder(Color.white.opacity(0.15), lineWidth: 0.6))
        }
        .rotationEffect(.degrees(rotationDegrees))
        .onAppear {
            if isPlaying && allowSpin {
                startSpin()
            }
        }
        .onChange(of: isPlaying) { _, playing in
            if playing && allowSpin {
                startSpin()
            }
        }
    }
    
    // MARK: - Square Mode
    private var squareArtworkView: some View {
        ZStack {
            if let data = artworkData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipped()
            } else {
                ArtworkPlaceholderView(size: size, cornerRadius: 0)
            }
        }
        .overlay(
            Rectangle()
                .strokeBorder(Color.white.opacity(0.20), lineWidth: 0.6)
        )
        .shadow(color: Color.black.opacity(0.30), radius: 18, x: 0, y: 10)
    }
    
    private func startSpin() {
        withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
            rotationDegrees += 360
        }
    }
}
