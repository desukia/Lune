//
//  LyricsManager.swift
//  Lune
//
//  Synced LRC parser, karaoke-style timing engine, and fast non-blocking online lyrics service
//  supporting Vagalume API (eugabrielsilva/vagalume) and LRCLIB synchronized lyrics.
//

import Foundation

public struct LyricLine: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var timestamp: TimeInterval // -1 for unsynced
    public var text: String
    
    public init(id: UUID = UUID(), timestamp: TimeInterval, text: String) {
        self.id = id
        self.timestamp = timestamp
        self.text = text
    }
}

@MainActor
public final class LyricsManager: ObservableObject {
    public static let shared = LyricsManager()
    
    @Published public var lines: [LyricLine] = []
    @Published public var isLoading: Bool = false
    @Published public var isSynced: Bool = false
    @Published public var currentSongId: Int64? = nil
    @Published public var errorMessage: String? = nil
    
    private var cache: [Int64: (lines: [LyricLine], isSynced: Bool)] = [:]
    
    private init() {}
    
    // MARK: - Parse LRC Format
    
    public func parseLrc(_ lrcContent: String) -> [LyricLine] {
        var result: [LyricLine] = []
        let rawLines = lrcContent.components(separatedBy: .newlines)
        
        let pattern = "\\[(\\d{2}):(\\d{2})\\.(\\d{2,3})\\](.*)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }
        
        for raw in rawLines {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            
            let nsString = trimmed as NSString
            let matches = regex.matches(in: trimmed, options: [], range: NSRange(location: 0, length: nsString.length))
            
            if let match = matches.first, match.numberOfRanges == 5 {
                let minStr = nsString.substring(with: match.range(at: 1))
                let secStr = nsString.substring(with: match.range(at: 2))
                let msStr = nsString.substring(with: match.range(at: 3))
                let text = nsString.substring(with: match.range(at: 4)).trimmingCharacters(in: .whitespaces)
                
                let mins = Double(minStr) ?? 0
                let secs = Double(secStr) ?? 0
                let ms = Double(msStr) ?? 0
                let msDivisor: Double = msStr.count == 3 ? 1000.0 : 100.0
                let totalSecs = (mins * 60.0) + secs + (ms / msDivisor)
                
                result.append(LyricLine(timestamp: totalSecs, text: text))
            } else if !trimmed.hasPrefix("[") {
                result.append(LyricLine(timestamp: -1, text: trimmed))
            }
        }
        
        return result.sorted { $0.timestamp < $1.timestamp }
    }
    
    // MARK: - Active Line Finder
    
    public func findActiveLineIndex(lines: [LyricLine], currentTime: TimeInterval) -> Int? {
        guard !lines.isEmpty else { return nil }
        let timed = lines.filter { $0.timestamp >= 0 }
        guard !timed.isEmpty else { return nil }
        
        for i in (0..<timed.count).reversed() {
            if currentTime >= timed[i].timestamp {
                return lines.firstIndex(where: { $0.id == timed[i].id }) ?? 0
            }
        }
        return 0
    }
    
    // MARK: - Export LRC
    
    public func exportLrc(lines: [LyricLine]) -> String {
        var output = ""
        for line in lines {
            if line.timestamp >= 0 {
                let mins = Int(line.timestamp) / 60
                let secs = Int(line.timestamp) % 60
                let ms = Int((line.timestamp.truncatingRemainder(dividingBy: 1)) * 100)
                output += String(format: "[%02d:%02d.%02d]%@\n", mins, secs, ms, line.text)
            } else {
                output += "\(line.text)\n"
            }
        }
        return output
    }
    
    // MARK: - Fetch Lyrics for Song (Concurrent & Non-Blocking)
    
    public func fetchLyrics(for song: Song) async {
        currentSongId = song.id
        
        // 1. Check in-memory cache
        if let cached = cache[song.id] {
            self.lines = cached.lines
            self.isSynced = cached.isSynced
            self.isLoading = false
            return
        }
        
        // 2. Check embedded lyrics
        if let embedded = song.lyrics, !embedded.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let parsed = parseLrc(embedded)
            if !parsed.isEmpty {
                let hasTimestamps = parsed.contains(where: { $0.timestamp >= 0 })
                self.cache[song.id] = (parsed, hasTimestamps)
                self.lines = parsed
                self.isSynced = hasTimestamps
                self.isLoading = false
                return
            }
        }
        
        self.isLoading = true
        self.errorMessage = nil
        
        let cleanTitle = sanitizeQuery(song.title)
        let cleanArtist = sanitizeQuery(song.artist)
        let duration = song.duration
        
        // 3. Fetch LRCLIB and Vagalume concurrently in parallel
        async let lrcTask = fetchFromLrcLib(title: cleanTitle, artist: cleanArtist, duration: duration)
        async let vagalumeTask = fetchFromVagalume(title: cleanTitle, artist: cleanArtist)
        
        let (lrclibResult, vagalumeText) = await (lrcTask, vagalumeTask)
        
        // If song changed while fetching, discard
        guard self.currentSongId == song.id else { return }
        
        // Prioritize Synced Lyrics from LRCLIB
        if let lrclib = lrclibResult, let synced = lrclib.synced, !synced.isEmpty {
            let parsed = parseLrc(synced)
            if !parsed.isEmpty {
                self.cache[song.id] = (parsed, true)
                self.lines = parsed
                self.isSynced = true
                self.isLoading = false
                MusicLibraryManager.shared.updateLyrics(for: song.id, lyrics: synced)
                return
            }
        }
        
        // Next: Plain Lyrics from Vagalume (eugabrielsilva/vagalume)
        if let vagText = vagalumeText, !vagText.isEmpty {
            let parsed = formatPlainLyrics(vagText, duration: duration)
            if !parsed.isEmpty {
                let synced = duration > 0
                self.cache[song.id] = (parsed, synced)
                self.lines = parsed
                self.isSynced = synced
                self.isLoading = false
                MusicLibraryManager.shared.updateLyrics(for: song.id, lyrics: vagText)
                return
            }
        }
        
        // Fallback: Plain lyrics from LRCLIB
        if let lrclib = lrclibResult, let plain = lrclib.plain, !plain.isEmpty {
            let parsed = formatPlainLyrics(plain, duration: duration)
            let synced = duration > 0
            self.cache[song.id] = (parsed, synced)
            self.lines = parsed
            self.isSynced = synced
            self.isLoading = false
            MusicLibraryManager.shared.updateLyrics(for: song.id, lyrics: plain)
            return
        }
        
        self.lines = []
        self.isSynced = false
        self.isLoading = false
        self.errorMessage = "No lyrics found"
    }
    
    // MARK: - Vagalume API Client (eugabrielsilva/vagalume port)
    
    private func fetchFromVagalume(title: String, artist: String) async -> String? {
        // Direct search: /search.php?art={artist}&mus={title}&extra=relart
        if let direct = await searchVagalumeDirect(artist: artist, title: title) {
            return direct
        }
        
        // Excerpt search (as in eugabrielsilva/vagalume index.js)
        let query = "\(artist) \(title)"
        if let excerpt = await searchVagalumeExcerpt(query: query) {
            return excerpt
        }
        
        return nil
    }
    
    private func searchVagalumeDirect(artist: String, title: String) async -> String? {
        guard let encodedArt = artist.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let encodedMus = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.vagalume.com.br/search.php?art=\(encodedArt)&mus=\(encodedMus)&extra=relart") else {
            return nil
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 3.5
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            return nil
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let musList = json["mus"] as? [[String: Any]],
              let first = musList.first,
              let text = first["text"] as? String, !text.isEmpty else {
            return nil
        }
        
        return text
    }
    
    private func searchVagalumeExcerpt(query: String) async -> String? {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let searchUrl = URL(string: "https://api.vagalume.com.br/search.excerpt?q=\(encoded)&limit=1") else {
            return nil
        }
        
        var request = URLRequest(url: searchUrl)
        request.timeoutInterval = 3.5
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        guard let (searchData, searchResp) = try? await URLSession.shared.data(for: request),
              let searchHttp = searchResp as? HTTPURLResponse, searchHttp.statusCode == 200,
              let searchJson = try? JSONSerialization.jsonObject(with: searchData) as? [String: Any],
              let respDict = searchJson["response"] as? [String: Any],
              let docs = respDict["docs"] as? [[String: Any]],
              let firstDoc = docs.first,
              let musId = firstDoc["id"] as? String else {
            return nil
        }
        
        // Fetch music details by musid
        guard let musUrl = URL(string: "https://api.vagalume.com.br/search.php?musid=\(musId)") else {
            return nil
        }
        
        var musReq = URLRequest(url: musUrl)
        musReq.timeoutInterval = 3.5
        musReq.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        musReq.setValue("application/json", forHTTPHeaderField: "Accept")
        
        guard let (musData, musResp) = try? await URLSession.shared.data(for: musReq),
              let musHttp = musResp as? HTTPURLResponse, musHttp.statusCode == 200,
              let musJson = try? JSONSerialization.jsonObject(with: musData) as? [String: Any],
              let musList = musJson["mus"] as? [[String: Any]],
              let firstMus = musList.first,
              let text = firstMus["text"] as? String, !text.isEmpty else {
            return nil
        }
        
        return text
    }
    
    // MARK: - LRCLIB Client (Time-Synced Karaoke Provider)
    
    private struct LrcLibResponse: Decodable {
        let syncedLyrics: String?
        let plainLyrics: String?
    }
    
    private func fetchFromLrcLib(title: String, artist: String, duration: TimeInterval) async -> (synced: String?, plain: String?)? {
        guard let encodedArt = artist.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let encodedTrack = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        
        var urlString = "https://lrclib.net/api/get?artist_name=\(encodedArt)&track_name=\(encodedTrack)"
        if duration > 0 {
            urlString += "&duration=\(Int(duration))"
        }
        
        guard let url = URL(string: urlString) else { return nil }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 3.5
        request.setValue("LuneMusic/1.0 (https://github.com/desukia/Lune)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let decoded = try? JSONDecoder().decode(LrcLibResponse.self, from: data) else {
            return nil
        }
        
        return (decoded.syncedLyrics, decoded.plainLyrics)
    }
    
    // MARK: - Helpers
    
    private func formatPlainLyrics(_ text: String, duration: TimeInterval) -> [LyricLine] {
        let raw = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        guard !raw.isEmpty else { return [] }
        
        if duration > 10 {
            let startDelay: TimeInterval = 4.0
            let availableTime = max(5.0, duration - startDelay - 6.0)
            let step = availableTime / Double(raw.count)
            
            return raw.enumerated().map { index, lineText in
                let time = startDelay + (Double(index) * step)
                return LyricLine(timestamp: time, text: lineText)
            }
        } else {
            return raw.map { LyricLine(timestamp: -1, text: $0) }
        }
    }
    
    private func sanitizeQuery(_ query: String) -> String {
        var clean = query
        let patterns = [
            "\\(Official.*\\)",
            "\\[Official.*\\]",
            "\\(Audio\\)",
            "\\[Audio\\]",
            "\\(Lyric.*\\)",
            "\\[Lyric.*\\]",
            "\\(Video\\)",
            "\\(Remaster.*\\)",
            "\\[Remaster.*\\]",
            "\\(Live.*\\)",
            "- Live",
            "feat\\..*",
            "ft\\..*"
        ]
        
        for pat in patterns {
            if let regex = try? NSRegularExpression(pattern: pat, options: .caseInsensitive) {
                clean = regex.stringByReplacingMatches(
                    in: clean,
                    options: [],
                    range: NSRange(location: 0, length: (clean as NSString).length),
                    withTemplate: ""
                )
            }
        }
        
        return clean.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
