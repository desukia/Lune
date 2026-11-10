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
                // Background (Material 3 Adaptive: Pure Black in Dark, Pure White in Light + Ambient Blur)
                (colors.isDark ? Color.black : colors.background)
                    .ignoresSafeArea()
                
                if let data = player.currentSong?.artworkData ?? library.allSongs.first?.artworkData,
                   let img = UIImage(data: data) {
                    GeometryReader { bgGeo in
                        Image(uiImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: bgGeo.size.width, height: bgGeo.size.height)
                            .clipped()
                            .blur(radius: 45)
                            .opacity(colors.isDark ? 0.38 : 0.16)
                            .overlay(
                                colors.isDark ? Color.black.opacity(0.48) : Color.white.opacity(0.72)
                            )
                    }
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.35), value: player.currentSong?.id)
                }
                
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
    
    // MARK: - Lune Top Bar (Android Lune 1:1)
    private func topBar(colors: LuneColorScheme) -> some View {
        HStack(spacing: 12) {
            // Lune Logo + Title (Vector flower badge + Quicksand brand)
            HStack(spacing: 10) {
                Image("AppLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
                
                Text("Lune")
                    .font(.custom("Quicksand-Bold", size: 28))
                    .foregroundColor(colors.onSurface)
            }
            
            Spacer()
            
            // Trailing Action Buttons: Chevron, Theme Toggle & Settings (1:1 with Android Lune)
            HStack(spacing: 8) {
                // 1. Collapse / Section Header toggle
                topBarButton(icon: "chevron.up", colors: colors) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
                
                // 2. Theme Toggle (Sun / Moon)
                topBarButton(icon: themeIcon, colors: colors) {
                    cycleThemeMode()
                }
                
                // 3. Settings Gear
                topBarButton(icon: "gearshape.fill", colors: colors) {
                    showSettings = true
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 6)
    }
    
    @ViewBuilder
    private func topBarButton(icon: String, colors: LuneColorScheme, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(colors.onSurface)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(colors.surfaceContainerHigh)
                        .overlay(
                            Circle()
                                .stroke(colors.outlineVariant.opacity(0.35), lineWidth: 0.8)
                        )
                )
        }
        .buttonStyle(M3BounceButtonStyle())
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
