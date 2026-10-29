//
//  LiquidTabBar.swift
//  Lune
//
//  Liquid Glass Navigation System:
//  - LiquidGlassPageBar: Floating Liquid Glass Page Switcher Bar with sliding lens highlight
//  - UnifiedHeaderPill: Signature Lune 70dp bottom capsule dock with active section pill & search trigger
//  - SectionMenuSheet: Modal glass sheet to jump between all 9 sections
//  - SearchSheetView: Liquid glass live search sheet with instant filtering
//

import SwiftUI

// MARK: - Navigation Tabs
public enum NavigationTab: String, CaseIterable, Identifiable {
    case resume = "resume"
    case mixes = "mixes"
    case songs = "songs"
    case favorites = "favorites"
    case albums = "albums"
    case artists = "artists"
    case genres = "genres"
    case playlists = "playlists"
    case folders = "folders"
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .resume: return "Resume"
        case .mixes: return "AI Mixes"
        case .songs: return "All Songs"
        case .favorites: return "Favorites"
        case .albums: return "Albums"
        case .artists: return "Artists"
        case .genres: return "Genres"
        case .playlists: return "Playlists"
        case .folders: return "Folders"
        }
    }
    
    public var icon: String {
        switch self {
        case .resume: return "house.fill"
        case .mixes: return "sparkles"
        case .songs: return "music.note.list"
        case .favorites: return "heart.fill"
        case .albums: return "square.stack.fill"
        case .artists: return "person.2.fill"
        case .genres: return "guitars.fill"
        case .playlists: return "music.note"
        case .folders: return "folder.fill"
        }
    }
}

// MARK: - Liquid Glass Page Switcher Bar
/// The signature Apple Liquid Glass bar that allows users to seamlessly switch between all pages
/// with a fluid sliding refraction lens, specular highlight rim, and auto-centering scroll physics.
@MainActor
public struct LiquidGlassPageBar: View {
    @Binding var selectedTab: NavigationTab
    let tabs: [NavigationTab]
    let primaryColor: Color
    
    @Namespace private var pageLensNamespace
    @Environment(\.colorScheme) private var colorScheme
    
    @MainActor
    public init(
        selectedTab: Binding<NavigationTab>,
        tabs: [NavigationTab] = NavigationTab.allCases,
        primaryColor: Color = Color(hex: 0xD0BCFF)
    ) {
        self._selectedTab = selectedTab
        self.tabs = tabs
        self.primaryColor = primaryColor
    }
    
    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(tabs) { tab in
                        let isSelected = selectedTab == tab
                        
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            withAnimation(.spring(response: 0.38, dampingFraction: 0.74)) {
                                selectedTab = tab
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: tab.icon)
                                    .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                                    .foregroundColor(isSelected ? primaryColor : .secondary)
                                
                                Text(tab.title)
                                    .font(.custom(isSelected ? "Quicksand-Bold" : "Quicksand-Regular", size: 13))
                                    .foregroundColor(isSelected ? (colorScheme == .dark ? .white : .black) : .secondary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background {
                                if isSelected {
                                    Capsule()
                                        .fill(primaryColor.opacity(colorScheme == .dark ? 0.22 : 0.16))
                                        .background(
                                            Capsule()
                                                .fill(.ultraThinMaterial)
                                        )
                                        .overlay(
                                            // Specular refraction border
                                            Capsule()
                                                .stroke(
                                                    LinearGradient(
                                                        colors: [
                                                            Color.white.opacity(colorScheme == .dark ? 0.35 : 0.6),
                                                            Color.white.opacity(colorScheme == .dark ? 0.10 : 0.2)
                                                        ],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    ),
                                                    lineWidth: 0.8
                                                )
                                        )
                                        .shadow(color: primaryColor.opacity(0.2), radius: 6, x: 0, y: 2)
                                        .matchedGeometryEffect(id: "activePageLens", in: pageLensNamespace)
                                }
                            }
                            .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .id(tab)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
            }
            .liquidGlass(
                .regular,
                in: Capsule(style: .continuous),
                interactive: false,
                hasBorder: true,
                shadowRadius: 10
            )
            .padding(.horizontal, 16)
            .onChange(of: selectedTab) { _, newTab in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    proxy.scrollTo(newTab, anchor: .center)
                }
            }
            .onAppear {
                proxy.scrollTo(selectedTab, anchor: .center)
            }
        }
    }
}

// MARK: - Unified Header Pill (Bottom Navigation Dock)
/// Mirrors Android Lune's signature 70dp bottom capsule dock:
/// Left: Active section badge with spring bounce animation + tap to open SectionMenuSheet
/// Right: Search button trigger with circular glass magnifying icon
@MainActor
public struct UnifiedHeaderPill: View {
    @Binding var selectedTab: NavigationTab
    let primaryColor: Color
    let onShowSectionMenu: () -> Void
    let onShowSearch: () -> Void
    
    @State private var bounceScale: CGFloat = 1.0
    @Environment(\.colorScheme) private var colorScheme
    
    @MainActor
    public init(
        selectedTab: Binding<NavigationTab>,
        primaryColor: Color = Color(hex: 0xD0BCFF),
        onShowSectionMenu: @escaping () -> Void,
        onShowSearch: @escaping () -> Void
    ) {
        self._selectedTab = selectedTab
        self.primaryColor = primaryColor
        self.onShowSectionMenu = onShowSectionMenu
        self.onShowSearch = onShowSearch
    }
    
    public var body: some View {
        HStack(spacing: 8) {
            // LEFT SIDE: Active Section Pill
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onShowSectionMenu()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: selectedTab.icon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(primaryColor)
                    
                    Text(selectedTab.title)
                        .font(.custom("Quicksand-Bold", size: 14))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(primaryColor.opacity(0.85))
                }
                .padding(.horizontal, 16)
                .frame(maxHeight: .infinity)
                .background(
                    Capsule()
                        .fill(primaryColor.opacity(colorScheme == .dark ? 0.22 : 0.15))
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(colorScheme == .dark ? 0.22 : 0.40), lineWidth: 0.6)
                        )
                        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.08), radius: 6, x: 0, y: 2)
                )
                .scaleEffect(bounceScale)
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .onChange(of: selectedTab) { _, _ in
                withAnimation(.spring(response: 0.28, dampingFraction: 0.55)) {
                    bounceScale = 0.90
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                        bounceScale = 1.0
                    }
                }
            }
            
            Spacer()
            
            // RIGHT SIDE: Search Bar Trigger
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onShowSearch()
            } label: {
                HStack(spacing: 8) {
                    Text("Search...")
                        .font(.custom("Quicksand-Regular", size: 13))
                        .foregroundColor(.secondary)
                    
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(colorScheme == .dark ? 0.20 : 0.35), lineWidth: 0.6)
                        )
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(primaryColor)
                        )
                }
                .padding(.leading, 12)
                .padding(.trailing, 6)
                .frame(maxHeight: .infinity)
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(6)
        .frame(height: 64)
        .liquidGlass(
            .regular,
            in: Capsule(style: .continuous),
            interactive: false,
            hasBorder: true,
            shadowRadius: 14
        )
    }
}

// MARK: - Section Menu Sheet
/// Bottom modal sheet listing all 9 sections of Lune with track counts and quick-switch capabilities
@MainActor
public struct SectionMenuSheet: View {
    @Binding var selectedTab: NavigationTab
    @ObservedObject var library: MusicLibraryManager
    let primaryColor: Color
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @MainActor
    public init(
        selectedTab: Binding<NavigationTab>,
        library: MusicLibraryManager = .shared,
        primaryColor: Color = Color(hex: 0xD0BCFF)
    ) {
        self._selectedTab = selectedTab
        self.library = library
        self.primaryColor = primaryColor
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(NavigationTab.allCases) { tab in
                        let isSelected = selectedTab == tab
                        
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            selectedTab = tab
                            dismiss()
                        } label: {
                            HStack(spacing: 14) {
                                // Section Icon Badge
                                Circle()
                                    .fill(isSelected ? primaryColor.opacity(0.25) : Color.primary.opacity(0.06))
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Image(systemName: tab.icon)
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundColor(isSelected ? primaryColor : .primary)
                                    )
                                
                                // Title & Subtitle
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(tab.title)
                                        .font(.custom("Quicksand-Bold", size: 16))
                                        .foregroundColor(.primary)
                                    
                                    Text(subtitle(for: tab))
                                        .font(.custom("Quicksand-Regular", size: 12))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if isSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(primaryColor)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(isSelected ? primaryColor.opacity(colorScheme == .dark ? 0.18 : 0.10) : Color.primary.opacity(0.03))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .stroke(isSelected ? primaryColor.opacity(0.4) : Color.white.opacity(0.08), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
            }
            .navigationTitle("Sections")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.custom("Quicksand-Bold", size: 15))
                    .foregroundColor(primaryColor)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    
    private func subtitle(for tab: NavigationTab) -> String {
        switch tab {
        case .resume: return "Dashboard & recent activity"
        case .mixes: return "8 On-Device AI playlists"
        case .songs: return "\(library.allSongs.count) local tracks"
        case .favorites: return "\(library.favoriteSongs.count) favorite songs"
        case .albums: return "\(library.albums.count) albums"
        case .artists: return "\(library.artists.count) artists"
        case .genres: return "\(library.genres.count) genres"
        case .playlists: return "\(library.playlists.count) user playlists"
        case .folders: return "\(library.folders.count) directories"
        }
    }
}

// MARK: - Search Sheet View
/// Liquid Glass Instant Search overlay with real-time filtering across tracks, artists, and albums
@MainActor
public struct SearchSheetView: View {
    @ObservedObject var library: MusicLibraryManager = .shared
    @ObservedObject var player: AudioPlayerManager = .shared
    let primaryColor: Color
    
    @State private var query: String = ""
    @Environment(\.dismiss) private var dismiss
    
    @MainActor
    public init(primaryColor: Color = Color(hex: 0xD0BCFF)) {
        self.primaryColor = primaryColor
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                // Liquid Glass Search Input Field
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(primaryColor)
                    
                    TextField("Search songs, artists, albums...", text: $query)
                        .font(.custom("Quicksand-Regular", size: 15))
                        .autocorrectionDisabled()
                    
                    if !query.isEmpty {
                        Button {
                            query = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .liquidGlass(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 16)
                .padding(.top, 12)
                
                // Results List
                if searchResults.isEmpty {
                    VStack(spacing: 14) {
                        Spacer()
                        Image(systemName: "music.note.magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary.opacity(0.6))
                        Text(query.isEmpty ? "Search your library" : "No results for \"\(query)\"")
                            .font(.custom("Quicksand-Bold", size: 16))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(searchResults) { song in
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                player.playQueue(searchResults, startingAt: searchResults.firstIndex(of: song) ?? 0)
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    if let data = song.artworkData, let img = UIImage(data: data) {
                                        Image(uiImage: img)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 44, height: 44)
                                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    } else {
                                        ArtworkPlaceholderView(size: 44, cornerRadius: 8)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(song.title)
                                            .font(.custom("Quicksand-Bold", size: 14))
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                        Text("\(song.artist) • \(song.album)")
                                            .font(.custom("Quicksand-Regular", size: 12))
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                    
                                    Spacer()
                                    
                                    HiFiBadge()
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .font(.custom("Quicksand-Bold", size: 15))
                    .foregroundColor(primaryColor)
                }
            }
        }
    }
    
    private var searchResults: [Song] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return library.allSongs
        }
        return library.allSongs.filter {
            $0.title.localizedCaseInsensitiveContains(trimmed) ||
            $0.artist.localizedCaseInsensitiveContains(trimmed) ||
            $0.album.localizedCaseInsensitiveContains(trimmed)
        }
    }
}

// MARK: - Backwards Compatibility Alias
@MainActor
public struct LiquidTabBar: View {
    @Binding var selectedTab: NavigationTab
    let visibleTabs: [NavigationTab]
    let primaryColor: Color
    
    @MainActor
    public init(
        selectedTab: Binding<NavigationTab>,
        visibleTabs: [NavigationTab] = NavigationTab.allCases,
        primaryColor: Color = Color(hex: 0xD0BCFF)
    ) {
        self._selectedTab = selectedTab
        self.visibleTabs = visibleTabs
        self.primaryColor = primaryColor
    }
    
    public var body: some View {
        LiquidGlassPageBar(
            selectedTab: $selectedTab,
            tabs: visibleTabs,
            primaryColor: primaryColor
        )
    }
}
