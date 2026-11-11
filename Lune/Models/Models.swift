//
//  Models.swift
//  Lune
//
//  Data models matching Android Lune: Album, Artist, Playlist, PlaybackStats.
//

import Foundation

// MARK: - Stable Deterministic ID Generator (Immutable 64-bit FNV-1a)
public enum LuneIdGenerator {
    /// Generates an immutable, persistent 64-bit ID for a local song that never changes across app restarts or updates.
    public static func songId(url: URL, title: String, artist: String) -> Int64 {
        let stableSubpath: String
        if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let docsPath = docs.path
            if url.path.hasPrefix(docsPath) {
                stableSubpath = String(url.path.dropFirst(docsPath.count))
            } else {
                stableSubpath = url.lastPathComponent
            }
        } else {
            stableSubpath = url.lastPathComponent
        }
        
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let a = artist.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let key = "LUNE_SONG:\(stableSubpath.lowercased()):\(a):\(t)"
        return fnv1a64(key)
    }
    
    /// Generates an immutable, persistent 64-bit ID for an album name + artist.
    public static func albumId(album: String, artist: String) -> Int64 {
        let alb = album.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let art = artist.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let key = "LUNE_ALBUM:\(alb):\(art)"
        return fnv1a64(key)
    }
    
    /// Generates an immutable, persistent 64-bit ID for any arbitrary string key.
    public static func stableId(for string: String) -> Int64 {
        return fnv1a64(string.lowercased())
    }
    
    private static func fnv1a64(_ string: String) -> Int64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        let positive = Int64(hash & 0x7FFFFFFFFFFFFFFF)
        return positive == 0 ? 1 : positive
    }
}

public struct Album: Identifiable, Hashable, Codable, Sendable {
    public let id: Int64
    public let name: String
    public let artist: String
    public var artworkData: Data?
    public var songCount: Int
    
    public init(id: Int64 = 0, name: String, artist: String, artworkData: Data? = nil, songCount: Int = 0) {
        self.id = (id != 0) ? id : LuneIdGenerator.albumId(album: name, artist: artist)
        self.name = name
        self.artist = artist
        self.artworkData = artworkData
        self.songCount = songCount
    }
}

public struct Artist: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let name: String
    public var songCount: Int
    public var albumCount: Int
    public var playCount: Int
    public var artworkData: Data?
    
    public init(id: String = UUID().uuidString, name: String, songCount: Int = 0, albumCount: Int = 0, playCount: Int = 0, artworkData: Data? = nil) {
        self.id = id
        self.name = name
        self.songCount = songCount
        self.albumCount = albumCount
        self.playCount = playCount
        self.artworkData = artworkData
    }
}

public struct Playlist: Identifiable, Hashable, Codable, Sendable {
    public let id: Int64
    public var name: String
    public let createdAt: Date
    public var songIds: [Int64]
    
    public init(id: Int64 = Int64(Date().timeIntervalSince1970 * 1000), name: String, createdAt: Date = Date(), songIds: [Int64] = []) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.songIds = songIds
    }
}

public struct PlaybackStats: Identifiable, Hashable, Codable, Sendable {
    public let id: String // "SONG_123", "ARTIST_Queen", "GENRE_Rock"
    public let type: String // "SONG", "ARTIST", "GENRE"
    public var playCount: Int64
    public var totalTimeMs: Int64
    public var lastPlayed: Date
    
    public init(id: String, type: String, playCount: Int64 = 0, totalTimeMs: Int64 = 0, lastPlayed: Date = Date()) {
        self.id = id
        self.type = type
        self.playCount = playCount
        self.totalTimeMs = totalTimeMs
        self.lastPlayed = lastPlayed
    }
}
