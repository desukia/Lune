//
//  Song.swift
//  Lune
//
//  Exact data model parity with Song.kt in Lune Android.
//

import Foundation

public struct Song: Identifiable, Hashable, Codable, Sendable {
    public let id: Int64
    public let albumId: Int64
    public var title: String
    public var artist: String
    public var album: String
    public let duration: TimeInterval // in seconds
    public let url: URL
    public let path: String
    public let dateAdded: Date
    public var artworkData: Data?
    public var artworkURL: URL?
    public var genre: String?
    public let folderName: String
    public var isHiFi: Bool
    public var isFavorite: Bool
    public var lyrics: String?
    public let format: String
    public let bitrate: Int?
    public let trackNumber: Int
    public var isHiRes: Bool
    public let sampleRate: Int?
    public let bitDepth: Int?
    
    public init(
        id: Int64 = Int64(UUID().hashValue),
        albumId: Int64 = 0,
        title: String,
        artist: String,
        album: String,
        duration: TimeInterval,
        url: URL,
        path: String = "",
        dateAdded: Date = Date(),
        artworkData: Data? = nil,
        artworkURL: URL? = nil,
        genre: String? = nil,
        folderName: String = "Music",
        isHiFi: Bool = false,
        isFavorite: Bool = false,
        lyrics: String? = nil,
        format: String = "MP3",
        bitrate: Int? = nil,
        trackNumber: Int = 0,
        isHiRes: Bool = false,
        sampleRate: Int? = nil,
        bitDepth: Int? = nil
    ) {
        self.id = id
        self.albumId = albumId
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.url = url
        self.path = path.isEmpty ? url.path : path
        self.dateAdded = dateAdded
        self.artworkData = artworkData
        self.artworkURL = artworkURL
        self.genre = genre
        self.folderName = folderName
        self.isHiFi = isHiFi
        self.isFavorite = isFavorite
        self.lyrics = lyrics
        self.format = format
        self.bitrate = bitrate
        self.trackNumber = trackNumber
        self.isHiRes = isHiRes
        self.sampleRate = sampleRate
        self.bitDepth = bitDepth
    }
    
    public var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
