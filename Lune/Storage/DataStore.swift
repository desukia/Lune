//
//  DataStore.swift
//  Lune
//
//  Persistent storage for Playlists, Song Overrides, and Playback Stats.
//  Provides backup export and restore compatible with Lune JSON schema.
//

import Foundation

public final class DataStore: @unchecked Sendable {
    public static let shared = DataStore()
    
    private let lock = NSLock()
    private var playlists: [Playlist] = []
    private var favorites: Set<Int64> = []
    private var stats: [String: PlaybackStats] = [:]
    
    private let playlistsFileURL: URL
    private let favoritesFileURL: URL
    private let statsFileURL: URL
    
    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        
        self.playlistsFileURL = appSupport.appendingPathComponent("playlists.json")
        self.favoritesFileURL = appSupport.appendingPathComponent("favorites.json")
        self.statsFileURL = appSupport.appendingPathComponent("playback_stats.json")
        
        load()
    }
    
    private func load() {
        lock.lock()
        defer { lock.unlock() }
        
        if let data = try? Data(contentsOf: playlistsFileURL),
           let list = try? JSONDecoder().decode([Playlist].self, from: data) {
            self.playlists = list
        }
        
        if let data = try? Data(contentsOf: favoritesFileURL),
           let set = try? JSONDecoder().decode(Set<Int64>.self, from: data) {
            self.favorites = set
        }
        
        if let data = try? Data(contentsOf: statsFileURL),
           let dict = try? JSONDecoder().decode([String: PlaybackStats].self, from: data) {
            self.stats = dict
        }
    }
    
    // MARK: - Playlists
    
    public func getAllPlaylists() -> [Playlist] {
        lock.lock()
        defer { lock.unlock() }
        return playlists
    }
    
    public func createPlaylist(name: String) -> Playlist {
        lock.lock()
        let playlist = Playlist(name: name)
        playlists.append(playlist)
        lock.unlock()
        savePlaylists()
        return playlist
    }
    
    public func deletePlaylist(id: Int64) {
        lock.lock()
        playlists.removeAll { $0.id == id }
        lock.unlock()
        savePlaylists()
    }
    
    public func addSongToPlaylist(playlistId: Int64, songId: Int64) {
        lock.lock()
        if let idx = playlists.firstIndex(where: { $0.id == playlistId }) {
            if !playlists[idx].songIds.contains(songId) {
                playlists[idx].songIds.append(songId)
            }
        }
        lock.unlock()
        savePlaylists()
    }
    
    public func removeSongFromPlaylist(playlistId: Int64, songId: Int64) {
        lock.lock()
        if let idx = playlists.firstIndex(where: { $0.id == playlistId }) {
            playlists[idx].songIds.removeAll { $0 == songId }
        }
        lock.unlock()
        savePlaylists()
    }
    
    public func reorderPlaylist(playlistId: Int64, newSongIds: [Int64]) {
        lock.lock()
        if let idx = playlists.firstIndex(where: { $0.id == playlistId }) {
            playlists[idx].songIds = newSongIds
        }
        lock.unlock()
        savePlaylists()
    }
    
    private func savePlaylists() {
        lock.lock()
        let copy = playlists
        lock.unlock()
        if let encoded = try? JSONEncoder().encode(copy) {
            try? encoded.write(to: playlistsFileURL, options: .atomic)
        }
    }
    
    // MARK: - Favorites
    
    public func isFavorite(songId: Int64) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return favorites.contains(songId)
    }
    
    public func setFavorite(songId: Int64, isFavorite: Bool) {
        lock.lock()
        if isFavorite {
            favorites.insert(songId)
        } else {
            favorites.remove(songId)
        }
        let copy = favorites
        lock.unlock()
        if let encoded = try? JSONEncoder().encode(copy) {
            try? encoded.write(to: favoritesFileURL, options: .atomic)
        }
    }
    
    // MARK: - Playback Stats
    
    public func recordPlay(songId: Int64, durationMs: Int64) {
        lock.lock()
        let key = "SONG_\(songId)"
        var entry = stats[key] ?? PlaybackStats(id: key, type: "SONG")
        entry.playCount += 1
        entry.totalTimeMs += durationMs
        entry.lastPlayed = Date()
        stats[key] = entry
        let copy = stats
        lock.unlock()
        if let encoded = try? JSONEncoder().encode(copy) {
            try? encoded.write(to: statsFileURL, options: .atomic)
        }
    }
    
    public func getTopSongsStats(limit: Int = 10) -> [PlaybackStats] {
        lock.lock()
        defer { lock.unlock() }
        return stats.values
            .filter { $0.type == "SONG" }
            .sorted { $0.playCount > $1.playCount }
            .prefix(limit)
            .map { $0 }
    }
}
