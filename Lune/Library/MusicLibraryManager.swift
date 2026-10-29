//
//  MusicLibraryManager.swift
//  Lune
//
//  Local offline music library manager:
//  - Scans system music library (MPMediaQuery) and local app sandbox Documents
//  - Deep AVAsset metadata extraction (title, artist, album, genre, lyrics, artwork, hi-res, bitrate)
//  - Sideloaded / Files app audio importer
//

import Foundation
import MediaPlayer
import AVFoundation
import SwiftUI
import Combine

@MainActor
public final class MusicLibraryManager: ObservableObject {
    public static let shared = MusicLibraryManager()
    
    @Published public var allSongs: [Song] = []
    @Published public var albums: [Album] = []
    @Published public var artists: [Artist] = []
    @Published public var genres: [String] = []
    @Published public var folders: [String: [Song]] = [:]
    @Published public var isLoading: Bool = false
    @Published public var searchQuery: String = ""
    
    public var favoriteSongs: [Song] {
        allSongs.filter { $0.isFavorite }
    }
    
    public var playlists: [Playlist] {
        DataStore.shared.getAllPlaylists()
    }
    
    private let musicFolderURL: URL
    
    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.musicFolderURL = docs.appendingPathComponent("Music", isDirectory: true)
        try? FileManager.default.createDirectory(at: musicFolderURL, withIntermediateDirectories: true)
    }
    
    // MARK: - Library Scanning
    
    public func scanLibrary() async {
        isLoading = true
        var collectedSongs: [Song] = []
        
        // 1. Scan Documents/Music local folder
        let localSongs = await scanLocalDirectory(musicFolderURL)
        collectedSongs.append(contentsOf: localSongs)
        
        // 2. Scan MPMediaQuery if authorized
        let mediaAuth = MPMediaLibrary.authorizationStatus()
        if mediaAuth == .authorized {
            let systemSongs = await scanSystemMediaLibrary()
            collectedSongs.append(contentsOf: systemSongs)
        }
        
        // Deduplicate by URL or unique key
        let unique = Array(Dictionary(grouping: collectedSongs, by: { $0.url.absoluteString }).compactMap { $0.value.first })
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        
        self.allSongs = unique
        self.rebuildCollections(from: unique)
        self.isLoading = false
        
        // Refresh AI Mixes with the updated songs
        LuneAiEngine.shared.refreshMixes(allSongs: unique)
    }
    
    private func scanLocalDirectory(_ dir: URL) async -> [Song] {
        var songs: [Song] = []
        let supportedExtensions = ["mp3", "m4a", "flac", "wav", "aac", "alac", "aif", "aiff"]
        
        let enumerator = FileManager.default.enumerator(
            at: dir,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        )
        
        while let fileURL = enumerator?.nextObject() as? URL {
            let ext = fileURL.pathExtension.lowercased()
            if supportedExtensions.contains(ext) {
                if let song = await parseAudioFile(at: fileURL) {
                    songs.append(song)
                }
            }
        }
        return songs
    }
    
    private func scanSystemMediaLibrary() async -> [Song] {
        var songs: [Song] = []
        let query = MPMediaQuery.songs()
        guard let items = query.items else { return [] }
        
        for item in items {
            guard let url = item.assetURL else { continue }
            let id = Int64(item.persistentID)
            let title = item.title ?? "Unknown Title"
            let artist = item.artist ?? "Unknown Artist"
            let album = item.albumTitle ?? "Unknown Album"
            let genre = item.genre
            let duration = item.playbackDuration
            let artwork = item.artwork?.image(at: CGSize(width: 512, height: 512))?.jpegData(compressionQuality: 0.85)
            
            let song = Song(
                id: id,
                albumId: Int64(item.albumPersistentID),
                title: title,
                artist: artist,
                album: album,
                duration: duration,
                url: url,
                path: url.path,
                artworkData: artwork,
                genre: genre,
                folderName: "Apple Music",
                isHiFi: false,
                isFavorite: DataStore.shared.isFavorite(songId: id),
                lyrics: item.lyrics,
                format: "M4A",
                trackNumber: item.albumTrackNumber
            )
            songs.append(song)
        }
        return songs
    }
    
    private func parseAudioFile(at url: URL) async -> Song? {
        let asset = AVURLAsset(url: url)
        guard let durationCM = try? await asset.load(.duration) else { return nil }
        let duration = CMTimeGetSeconds(durationCM)
        guard duration > 0 else { return nil }
        
        var title = url.deletingPathExtension().lastPathComponent
        var artist = "Unknown Artist"
        var album = "Unknown Album"
        var genre: String? = nil
        var artworkData: Data? = nil
        let lyrics: String? = nil
        let trackNumber = 0
        var isHiRes = false
        var sampleRate: Int? = nil
        var bitDepth: Int? = nil
        
        if let metadata = try? await asset.load(.metadata) {
            for item in metadata {
                guard let key = item.commonKey?.rawValue ?? item.key?.description else { continue }
                if let val = try? await item.load(.stringValue) {
                    switch key {
                    case AVMetadataKey.commonKeyTitle.rawValue: title = val
                    case AVMetadataKey.commonKeyArtist.rawValue: artist = val
                    case AVMetadataKey.commonKeyAlbumName.rawValue: album = val
                    case AVMetadataKey.commonKeyType.rawValue: genre = val
                    default: break
                    }
                }
                if key == AVMetadataKey.commonKeyArtwork.rawValue, let data = try? await item.load(.dataValue) {
                    artworkData = data
                }
            }
        }
        
        // Audio format and Hi-Res detection
        if let tracks = try? await asset.loadTracks(withMediaType: .audio), let track = tracks.first {
            if let descriptions = try? await track.load(.formatDescriptions) {
                for desc in descriptions {
                    if let basic = CMAudioFormatDescriptionGetStreamBasicDescription(desc)?.pointee {
                        sampleRate = Int(basic.mSampleRate)
                        bitDepth = Int(basic.mBitsPerChannel)
                        if (basic.mSampleRate >= 96000) || (basic.mBitsPerChannel >= 24) {
                            isHiRes = true
                        }
                    }
                }
            }
        }
        
        let folder = url.deletingLastPathComponent().lastPathComponent
        let format = url.pathExtension.uppercased()
        let isHiFi = isHiRes || format == "FLAC" || format == "ALAC" || format == "WAV"
        let songId = Int64(abs(url.absoluteString.hashValue))
        let albumId = Int64(abs(album.hashValue))
        
        return Song(
            id: songId,
            albumId: albumId,
            title: title,
            artist: artist,
            album: album,
            duration: duration,
            url: url,
            path: url.path,
            artworkData: artworkData,
            genre: genre,
            folderName: folder.isEmpty ? "Music" : folder,
            isHiFi: isHiFi,
            isFavorite: DataStore.shared.isFavorite(songId: songId),
            lyrics: lyrics,
            format: format,
            trackNumber: trackNumber,
            isHiRes: isHiRes,
            sampleRate: sampleRate,
            bitDepth: bitDepth
        )
    }
    
    // MARK: - File Importer
    
    public func importAudioFiles(from urls: [URL]) async {
        for url in urls {
            let shouldStop = url.startAccessingSecurityScopedResource()
            defer { if shouldStop { url.stopAccessingSecurityScopedResource() } }
            
            let destURL = musicFolderURL.appendingPathComponent(url.lastPathComponent)
            try? FileManager.default.removeItem(at: destURL)
            try? FileManager.default.copyItem(at: url, to: destURL)
        }
        await scanLibrary()
    }
    
    // MARK: - Collections Rebuilding
    
    private func rebuildCollections(from songs: [Song]) {
        // Albums
        let albumGroups = Dictionary(grouping: songs, by: { "\($0.album)_\($0.artist)" })
        self.albums = albumGroups.map { _, sList in
            let sample = sList.first!
            return Album(
                id: sample.albumId,
                name: sample.album,
                artist: sample.artist,
                artworkData: sList.compactMap({ $0.artworkData }).first,
                songCount: sList.count
            )
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        
        // Artists
        let artistGroups = Dictionary(grouping: songs, by: { $0.artist })
        self.artists = artistGroups.map { name, sList in
            let albumsCount = Set(sList.map { $0.album }).count
            return Artist(
                name: name,
                songCount: sList.count,
                albumCount: albumsCount,
                artworkData: sList.compactMap({ $0.artworkData }).first
            )
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        
        // Genres
        let gSet = Set(songs.compactMap { $0.genre?.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })
        self.genres = Array(gSet).sorted()
        
        // Folders
        self.folders = Dictionary(grouping: songs, by: { $0.folderName })
    }
    
    public func toggleFavorite(for song: Song) {
        let currentFav = allSongs.first(where: { $0.id == song.id })?.isFavorite ?? (AudioPlayerManager.shared.currentSong?.id == song.id ? (AudioPlayerManager.shared.currentSong?.isFavorite ?? song.isFavorite) : song.isFavorite)
        let newFav = !currentFav
        DataStore.shared.setFavorite(songId: song.id, isFavorite: newFav)
        
        if let idx = allSongs.firstIndex(where: { $0.id == song.id }) {
            allSongs[idx].isFavorite = newFav
            LuneAiEngine.shared.onSongFavoriteToggled(allSongs[idx], isFavorite: newFav)
        }
        
        // Immediately sync with AudioPlayerManager currentSong so NowPlayingView & MiniPlayer update
        if AudioPlayerManager.shared.currentSong?.id == song.id {
            AudioPlayerManager.shared.currentSong?.isFavorite = newFav
        }
        
        // Sync with AudioPlayerManager queue
        for qIdx in AudioPlayerManager.shared.queue.indices {
            if AudioPlayerManager.shared.queue[qIdx].id == song.id {
                AudioPlayerManager.shared.queue[qIdx].isFavorite = newFav
            }
        }
    }
    
    public func updateLyrics(for songId: Int64, lyrics: String) {
        if let idx = allSongs.firstIndex(where: { $0.id == songId }) {
            allSongs[idx].lyrics = lyrics
        }
        if AudioPlayerManager.shared.currentSong?.id == songId {
            AudioPlayerManager.shared.currentSong?.lyrics = lyrics
        }
    }
}
