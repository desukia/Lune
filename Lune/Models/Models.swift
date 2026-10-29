//
//  Models.swift
//  Lune
//
//  Data models matching Android Lune: Album, Artist, Playlist, PlaybackStats.
//

import Foundation

public struct Album: Identifiable, Hashable, Codable, Sendable {
    public let id: Int64
    public let name: String
    public let artist: String
    public var artworkData: Data?
    public var songCount: Int
    
    public init(id: Int64 = Int64(UUID().hashValue), name: String, artist: String, artworkData: Data? = nil, songCount: Int = 0) {
        self.id = id
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
