//
//  MainView.swift
//  Lune
//
//  Root interface with:
//  - Top Bar: Animated Lune Logo + Title + Glass Theme / Search / Settings buttons
//  - LiquidGlassPageBar: Signature Apple Liquid Glass Page Switcher Bar
//  - Horizontal Pager: Fluid full-screen swipe between all 9 sections (matching Android Lune's HorizontalPager)
//  - Floating Bottom Dock: MiniPlayer + UnifiedHeaderPill (Active Section Pill & Search Trigger)
//

import SwiftUI

@MainActor
public struct MainView: View {
    @StateObject private var library = MusicLibraryManager.shared
    @StateObject private var player = AudioPlayerManager.shared
    @StateObject private var aiEngine = LuneAiEngine.shared
    @StateObject private var settings = SettingsManager.shared
    
    @State private var selectedTab: NavigationTab = .resume
    @State private var showNowPlaying: Bool = false
    @State private var showSettings: Bool = false
    @State private var showSectionMenu: Bool = false
    @State private var showSearch: Bool = false
    
    @Environment(\.colorScheme) private var colorScheme
    
    public init() {}
    
    public var body: some View {
        let colors = settings.resolveColors(for: colorScheme)
        
        NavigationStack {
            ZStack(alignment: .bottom) {
                // Background
                colors.background
                    .ignoresSafeArea()
                
                // Main Content Column
                VStack(spacing: 0) {
                    // 1. Lune Top Bar (Clean, uncluttered, authentic native header)
                    topBar(colors: colors)
                    
                    // 2. Fluid Horizontal Pager (Full Swipeable Pager across all sections)
                    TabView(selection: $selectedTab) {
                        ResumeScreenView(
                            library: library,
                            player: player,
                            settings: settings,
                            onTapHero: { showNowPlaying = true },
                            onNavigateToAllSongs: { withAnimation { selectedTab = .songs } },
                            onNavigateToArtist: { _ in withAnimation { selectedTab = .artists } },
                            onNavigateToAlbum: { _ in withAnimation { selectedTab = .albums } },
                            onNavigateToGenre: { _ in withAnimation { selectedTab = .genres } },
                            onNavigateToPlaylist: { _ in withAnimation { selectedTab = .playlists } }
                        )
                        .tag(NavigationTab.resume)
                        
                        AiMixesView(aiEngine: aiEngine, library: library, player: player, settings: settings)
                            .tag(NavigationTab.mixes)
                        
                        SongsListView(title: "All Songs", filterFavoritesOnly: false, library: library, player: player, settings: settings)
                            .tag(NavigationTab.songs)
                        
                        SongsListView(title: "Favorites", filterFavoritesOnly: true, library: library, player: player, settings: settings)
                            .tag(NavigationTab.favorites)
                        
                        AlbumsView(library: library)
                            .tag(NavigationTab.albums)
                        
                        ArtistsView(library: library)
                            .tag(NavigationTab.artists)
                        
                        GenresView(library: library)
                            .tag(NavigationTab.genres)
                        
                        PlaylistsView(library: library)
                            .tag(NavigationTab.playlists)
                        
                        FoldersView(library: library)
                            .tag(NavigationTab.folders)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .ignoresSafeArea(.keyboard, edges: .bottom)
                }
                
                // 4. Floating Overlays: MiniPlayer + UnifiedHeaderPill
                VStack(spacing: 8) {
                    if player.currentSong != nil {
                        MiniPlayerView(player: player, primaryColor: colors.primary) {
                            showNowPlaying = true
                        }
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        ))
                    }
                    
                    UnifiedHeaderPill(
                        selectedTab: $selectedTab,
                        primaryColor: colors.primary,
                        onShowSectionMenu: { showSectionMenu = true },
                        onShowSearch: { showSearch = true }
                    )
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 8)
            }
            .toolbar(.hidden, for: .navigationBar)
            .task {
                await library.scanLibrary()
            }
            .sheet(isPresented: $showSectionMenu) {
                SectionMenuSheet(
                    selectedTab: $selectedTab,
                    library: library,
                    primaryColor: colors.primary
                )
            }
            .sheet(isPresented: $showSearch) {
                SearchSheetView(primaryColor: colors.primary)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(settings: settings, library: library)
            }
            .fullScreenCover(isPresented: $showNowPlaying) {
                NowPlayingView(player: player, settings: settings)
            }
        }
    }
    
    // MARK: - Lune Top Bar
    private func topBar(colors: LuneColorScheme) -> some View {
        HStack(spacing: 12) {
            // Lune Logo + Title (Static, transparent background vector)
            HStack(spacing: 10) {
                Image("AppLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 34, height: 34)
                
                Text("Lune")
                    .font(.custom("Quicksand-Bold", size: 26))
                    .foregroundColor(colors.onSurface)
            }
            
            Spacer()
            
            // Trailing Liquid Glass Action Buttons
            HStack(spacing: 8) {
                // Theme Toggle
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    cycleThemeMode()
                } label: {
                    Image(systemName: themeIcon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(colors.onSurface)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.liquidGlassCircle)
                
                // Search Button
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showSearch = true
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(colors.onSurface)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.liquidGlassCircle)
                
                // Settings Button
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(colors.onSurface)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.liquidGlassCircle)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }
    
    private func cycleThemeMode() {
        switch settings.themeMode {
        case .system: settings.themeMode = .light
        case .light: settings.themeMode = .dark
        case .dark: settings.themeMode = .system
        }
    }
    
    private var themeIcon: String {
        switch settings.themeMode {
        case .system: return "circle.righthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
    
    private var activeTabs: [NavigationTab] {
        let allowed = settings.visibleTabs
        let tabs = NavigationTab.allCases.filter { allowed.contains($0.rawValue) }
        return tabs.isEmpty ? NavigationTab.allCases : tabs
    }
}
