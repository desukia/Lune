//
//  LuneAiEngine.swift
//  Lune
//
//  Complete port of LuneAiEngine.kt to Swift:
//  - 100% on-device, private, zero-network algorithmic intelligence
//  - Habit learning, Markov transition probabilities, time-of-day affinity
//  - Heuristic audio profiling (energy, acoustic, focus, live/acoustic)
//  - Harmonic Smart Shuffle & Discovery Queue interleaving
//  - 8 Personalized AI Mixes
//

import SwiftUI
import Combine

@MainActor
public final class LuneAiEngine: ObservableObject {
    public static let shared = LuneAiEngine()
    
    private let storage = AiTelemetryStorage.shared
    
    @Published public var aiMixes: [AiMix] = []
    
    private var lastStartedSongId: Int64? = nil
    private var lastStartedTimeMs: Int64 = 0
    private var previousPlayedSongId: Int64? = nil
    
    private init() {}
    
    // MARK: - Telemetry & Habit Learning
    
    public func onSongStarted(_ song: Song) {
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let timeOfDay = TimeOfDay.current()
        let isWeekend = DayType.current() == .weekend
        
        // Markov transition
        if let prevId = previousPlayedSongId, prevId != song.id, (now - lastStartedTimeMs > 40_000) {
            storage.recordInteraction(songId: prevId) { prev in
                prev.recordTransition(to: song.id)
            }
        }
        
        let isReplay = (lastStartedSongId == song.id) && (now - lastStartedTimeMs < 35_000)
        previousPlayedSongId = lastStartedSongId
        lastStartedSongId = song.id
        lastStartedTimeMs = now
        
        storage.recordInteraction(songId: song.id) { interaction in
            interaction.playCount += 1
            interaction.lastPlayedTimestamp = now
            if isReplay { interaction.repeatCount += 1 }
            if isWeekend { interaction.weekendPlays += 1 } else { interaction.weekdayPlays += 1 }
            
            switch timeOfDay {
            case .morning: interaction.morningPlays += 1
            case .afternoon: interaction.afternoonPlays += 1
            case .evening: interaction.eveningPlays += 1
            case .night: interaction.nightPlays += 1
            }
            if interaction.consecutiveSkips > 0 {
                interaction.consecutiveSkips = 0
            }
        }
    }
    
    public func onSongCompleted(_ song: Song) {
        storage.recordInteraction(songId: song.id) { interaction in
            interaction.fullCompletions += 1
            interaction.consecutiveSkips = 0
        }
    }
    
    public func onSongSkipped(_ song: Song, playedSeconds: TimeInterval, totalDurationSeconds: TimeInterval) {
        let isFastSkip = playedSeconds < 20 || (totalDurationSeconds > 0 && (playedSeconds / totalDurationSeconds) < 0.15)
        if isFastSkip {
            storage.recordInteraction(songId: song.id) { interaction in
                interaction.fastSkips += 1
                interaction.consecutiveSkips += 1
            }
        }
    }
    
    public func onSongFavoriteToggled(_ song: Song, isFavorite: Bool) {
        storage.recordInteraction(songId: song.id) { interaction in
            interaction.isFavorite = isFavorite
        }
    }
    
    public func onSongAddedToPlaylist(songId: Int64) {
        storage.recordInteraction(songId: songId) { interaction in
            interaction.playlistAddCount += 1
        }
    }
    
    public func getSongAffinity(songId: Int64) -> Float {
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let time = TimeOfDay.current()
        let isWeekend = DayType.current() == .weekend
        return storage.getInteraction(songId: songId).calculateDynamicScore(now: now, currentTime: time, isWeekend: isWeekend)
    }
    
    // MARK: - Musical Profiling & Heuristics
    
    public struct AudioProfile {
        public let energyScore: Float
        public let acousticScore: Float
        public let isLiveOrAcoustic: Bool
        public let isFocusFriendly: Bool
    }
    
    public func profileSong(_ song: Song) -> AudioProfile {
        let titleLower = song.title.lowercased()
        let genreLower = (song.genre ?? "").lowercased()
        
        var energy: Float = 0.50
        var acoustic: Float = 0.30
        var isLive = false
        
        if titleLower.contains("acoustic") || titleLower.contains("acústic") ||
           titleLower.contains("unplugged") || titleLower.contains("piano version") ||
           genreLower.contains("acoustic") || genreLower.contains("folk") {
            acoustic += 0.50
            energy -= 0.25
            isLive = true
        }
        
        if titleLower.contains("live") || titleLower.contains("en vivo") ||
           titleLower.contains("en directo") || titleLower.contains("session") {
            isLive = true
        }
        
        if titleLower.contains("remix") || titleLower.contains("extended") ||
           titleLower.contains("club") || titleLower.contains("speed up") ||
           genreLower.contains("rock") || genreLower.contains("metal") ||
           genreLower.contains("dance") || genreLower.contains("edm") ||
           genreLower.contains("electronic") || genreLower.contains("trap") ||
           genreLower.contains("hardcore") {
            energy += 0.35
            acoustic -= 0.20
        }
        
        if titleLower.contains("lofi") || titleLower.contains("lo-fi") ||
           titleLower.contains("slowed") || titleLower.contains("ambient") ||
           titleLower.contains("instrumental") || genreLower.contains("ambient") ||
           genreLower.contains("classical") || genreLower.contains("jazz") ||
           genreLower.contains("chill") {
            energy -= 0.30
            acoustic += 0.25
        }
        
        if song.duration > 300 {
            energy -= 0.08
        } else if song.duration >= 120 && song.duration <= 210 {
            energy += 0.08
        }
        
        energy = max(0.05, min(0.98, energy))
        acoustic = max(0.05, min(0.98, acoustic))
        let isFocus = acoustic > 0.40 || (energy >= 0.20 && energy <= 0.55) || titleLower.contains("instrumental") || titleLower.contains("lo-fi")
        
        return AudioProfile(
            energyScore: energy,
            acousticScore: acoustic,
            isLiveOrAcoustic: isLive,
            isFocusFriendly: isFocus
        )
    }
    
    public func computeSongSimilarity(_ a: Song, _ b: Song) -> Float {
        if a.id == b.id { return 1.0 }
        var sim: Float = 0.0
        
        // Same artist bonus
        if a.artist.caseInsensitiveCompare(b.artist) == .orderedSame {
            sim += 0.42
        }
        
        // Compatible genre bonus
        if let gA = a.genre?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines),
           let gB = b.genre?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines),
           !gA.isEmpty && !gB.isEmpty {
            if gA == gB {
                sim += 0.35
            } else if isCompatibleGenre(gA, gB) {
                sim += 0.22
            }
        }
        
        // Audio profile harmonic distance
        let profA = profileSong(a)
        let profB = profileSong(b)
        let energyDelta = abs(profA.energyScore - profB.energyScore)
        let acousticDelta = abs(profA.acousticScore - profB.acousticScore)
        let profileHarmony = 1.0 - ((energyDelta * 0.60) + (acousticDelta * 0.40))
        sim += max(0, min(0.23, profileHarmony * 0.23))
        
        // Markov transition bonus
        let transition = storage.getInteraction(songId: a.id).getTransitionProbability(to: b.id)
        if transition > 0 {
            sim += max(0, min(0.20, transition * 0.20))
        }
        
        return max(0, min(1.0, sim))
    }
    
    private func isCompatibleGenre(_ g1: String, _ g2: String) -> Bool {
        let rockFamily: Set<String> = ["rock", "alternative", "indie", "metal", "punk", "grunge", "hard rock"]
        let popFamily: Set<String> = ["pop", "dance", "electropop", "synthpop", "indie pop", "disco"]
        let elecFamily: Set<String> = ["electronic", "edm", "house", "techno", "synthwave", "ambient", "trance"]
        let urbanFamily: Set<String> = ["hip hop", "rap", "trap", "r&b", "soul", "reggaeton", "urban"]
        let chillFamily: Set<String> = ["acoustic", "folk", "classical", "instrumental", "ambient", "lo-fi", "chill", "jazz"]
        
        return (rockFamily.contains(g1) && rockFamily.contains(g2)) ||
               (popFamily.contains(g1) && popFamily.contains(g2)) ||
               (elecFamily.contains(g1) && elecFamily.contains(g2)) ||
               (urbanFamily.contains(g1) && urbanFamily.contains(g2)) ||
               (chillFamily.contains(g1) && chillFamily.contains(g2))
    }
    
    // MARK: - Smart Shuffle
    
    public func generateSmartShuffle(_ songs: [Song], startingSong: Song? = nil) -> [Song] {
        guard songs.count > 2 else { return songs }
        var remaining = songs
        var result: [Song] = []
        
        let seed: Song
        if let starting = startingSong, let found = remaining.first(where: { $0.id == starting.id }) {
            seed = found
        } else {
            seed = remaining.max(by: { getSongAffinity(songId: $0.id) < getSongAffinity(songId: $1.id) }) ?? remaining[0]
        }
        
        result.append(seed)
        remaining.removeAll { $0.id == seed.id }
        
        var current = seed
        while !remaining.isEmpty {
            let scored = remaining.map { candidate -> (Song, Float) in
                let similarity = computeSongSimilarity(current, candidate)
                let affinity = getSongAffinity(songId: candidate.id)
                let sameArtistPenalty: Float = candidate.artist.caseInsensitiveCompare(current.artist) == .orderedSame ? -0.35 : 0
                let noise = Float.random(in: 0...0.08)
                let finalScore = (similarity * 0.48) + (min(0.44, affinity / 45.0)) + sameArtistPenalty + noise
                return (candidate, finalScore)
            }.sorted { $0.1 > $1.1 }
            
            let topSliceCount = min(3, scored.count)
            let chosen = scored.prefix(topSliceCount).randomElement()?.0 ?? scored[0].0
            result.append(chosen)
            remaining.removeAll { $0.id == chosen.id }
            current = chosen
        }
        return result
    }
    
    // MARK: - Discovery Queue
    
    public func generateDiscoveryQueue(_ allSongs: [Song], seedSong: Song? = nil) -> [Song] {
        guard !allSongs.isEmpty else { return [] }
        let familiar = allSongs.filter { getSongAffinity(songId: $0.id) >= 12.0 }
        let unexplored = allSongs.filter {
            let interaction = storage.getInteraction(songId: $0.id)
            return interaction.playCount <= 1 && !interaction.isFavorite
        }
        
        if unexplored.isEmpty {
            return generateSmartShuffle(allSongs, startingSong: seedSong)
        }
        
        let seed = seedSong ?? familiar.max(by: { getSongAffinity(songId: $0.id) < getSongAffinity(songId: $1.id) }) ?? allSongs[0]
        var result: [Song] = [seed]
        
        let rankedUnexplored = unexplored.map { candidate -> (Song, Float) in
            let maxSim = familiar.map { computeSongSimilarity($0, candidate) }.max() ?? 0.3
            return (candidate, maxSim)
        }.sorted { $0.1 > $1.1 }
        
        var familiarPool = familiar.filter { $0.id != seed.id }
        var unexploredPool = rankedUnexplored.map { $0.0 }
        
        var flip = 0
        while !familiarPool.isEmpty || !unexploredPool.isEmpty {
            if flip % 3 == 2 && !unexploredPool.isEmpty {
                result.append(unexploredPool.removeFirst())
            } else if !familiarPool.isEmpty {
                let last = result.last!
                let nextFam = familiarPool.max(by: { computeSongSimilarity(last, $0) < computeSongSimilarity(last, $1) }) ?? familiarPool[0]
                familiarPool.removeAll { $0.id == nextFam.id }
                result.append(nextFam)
            } else if !unexploredPool.isEmpty {
                result.append(unexploredPool.removeFirst())
            }
            flip += 1
        }
        return result
    }
    
    // MARK: - Smart Next Prediction
    
    public func predictNextSong(current: Song, history: [Song], pool: [Song]) -> Song? {
        let eligible = pool.filter { candidate in
            candidate.id != current.id && !history.contains(where: { $0.id == candidate.id })
        }
        guard !eligible.isEmpty else {
            return pool.filter { $0.id != current.id }.randomElement()
        }
        let recentArtists = Set(history.suffix(3).map { $0.artist.lowercased() })
        
        return eligible.max { a, b in
            let scoreA = scoreCandidate(a, current: current, recentArtists: recentArtists)
            let scoreB = scoreCandidate(b, current: current, recentArtists: recentArtists)
            return scoreA < scoreB
        }
    }
    
    private func scoreCandidate(_ candidate: Song, current: Song, recentArtists: Set<String>) -> Float {
        let similarity = computeSongSimilarity(current, candidate)
        let affinity = getSongAffinity(songId: candidate.id)
        let artistPenalty: Float = recentArtists.contains(candidate.artist.lowercased()) ? -0.45 : 0
        let markov = storage.getInteraction(songId: current.id).getTransitionProbability(to: candidate.id) * 0.30
        return (similarity * 0.45) + (min(0.40, affinity / 40.0)) + artistPenalty + markov
    }
    
    // MARK: - 8 Deep AI Mix Generation
    
    public func refreshMixes(allSongs: [Song]) {
        guard !allSongs.isEmpty else { return }
        
        var generated: [AiMix] = []
        let currentTime = TimeOfDay.current()
        let dayType = DayType.current()
        let isWeekend = dayType == .weekend
        
        // 1. Daily AI Flow
        let daily = allSongs.sorted { getSongAffinity(songId: $0.id) > getSongAffinity(songId: $1.id) }.prefix(32)
        if daily.count >= 3 {
            generated.append(
                AiMix(
                    id: "ai_daily_flow",
                    title: "Daily Flow",
                    subtitle: "Essential tracks with harmonic flow",
                    category: .dailyFlow,
                    songs: generateSmartShuffle(Array(daily)),
                    gradientColors: [Color(hex: 0x6366F1), Color(hex: 0x8B5CF6), Color(hex: 0xEC4899)],
                    iconName: "sparkles",
                    description: "Blends your real-time affinity with Markov transitions."
                )
            )
        }
        
        // 2. Discovery Mode
        let discovery = generateDiscoveryQueue(allSongs).prefix(28)
        if discovery.count >= 3 {
            generated.append(
                AiMix(
                    id: "ai_discovery_flow",
                    title: "Discovery Mode",
                    subtitle: "Favorites blended with unheard gems",
                    category: .discovery,
                    songs: Array(discovery),
                    gradientColors: [Color(hex: 0x0D9488), Color(hex: 0x059669), Color(hex: 0x10B981)],
                    iconName: "safari",
                    description: "Explore hidden songs mathematically kindred to your tastes."
                )
            )
        }
        
        // 3. Energy Boost
        let energyTracks = allSongs.filter { profileSong($0).energyScore > 0.62 || ($0.duration < 230 && getSongAffinity(songId: $0.id) > 8.0) }
            .sorted { getSongAffinity(songId: $0.id) > getSongAffinity(songId: $1.id) }
            .prefix(25)
        if energyTracks.count >= 3 {
            generated.append(
                AiMix(
                    id: "ai_energy_boost",
                    title: "Energy Boost",
                    subtitle: "High tempo beats to motivate and workout",
                    category: .energy,
                    songs: generateSmartShuffle(Array(energyTracks)),
                    gradientColors: [Color(hex: 0xF97316), Color(hex: 0xEF4444), Color(hex: 0xEC4899)],
                    iconName: "bolt.fill",
                    description: "Vibrant tempos and dynamic momentum from your collection."
                )
            )
        }
        
        // 4. Chill & Relax
        let chillTracks = allSongs.filter { profileSong($0).energyScore < 0.45 || profileSong($0).isFocusFriendly }
            .sorted { getSongAffinity(songId: $0.id) > getSongAffinity(songId: $1.id) }
            .prefix(25)
        if chillTracks.count >= 3 {
            generated.append(
                AiMix(
                    id: "ai_chill_flow",
                    title: "Chill & Relax",
                    subtitle: "Smooth textures to unwind and focus",
                    category: .chill,
                    songs: generateSmartShuffle(Array(chillTracks)),
                    gradientColors: [Color(hex: 0x06B6D4), Color(hex: 0x3B82F6), Color(hex: 0x6366F1)],
                    iconName: "leaf.fill",
                    description: "Mellow acoustic melodies for calm and concentration."
                )
            )
        }
        
        // 5. Time of Day Context
        let timeName: String
        let timeSub: String
        let timeColors: [Color]
        if isWeekend {
            timeName = "Weekend Mix"
            timeSub = "Enjoy your weekend soundtrack"
            timeColors = [Color(hex: 0xEC4899), Color(hex: 0x8B5CF6), Color(hex: 0x3B82F6)]
        } else {
            switch currentTime {
            case .morning:
                timeName = "Morning Mix"
                timeSub = "Start your day with the best selection"
                timeColors = [Color(hex: 0xF59E0B), Color(hex: 0x10B981), Color(hex: 0x06B6D4)]
            case .afternoon:
                timeName = "Afternoon Mix"
                timeSub = "Perfect soundtrack for your workday"
                timeColors = [Color(hex: 0x3B82F6), Color(hex: 0x8B5CF6), Color(hex: 0x06B6D4)]
            case .evening:
                timeName = "Evening Mix"
                timeSub = "Warm sunset tunes to unwind"
                timeColors = [Color(hex: 0xF97316), Color(hex: 0x8B5CF6), Color(hex: 0x4F46E5)]
            case .night:
                timeName = "Night Mix"
                timeSub = "Immersive ambient sounds for the night"
                timeColors = [Color(hex: 0x1E1B4B), Color(hex: 0x312E81), Color(hex: 0x4C1D95)]
            }
        }
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let timeSongs = allSongs.sorted {
            storage.getInteraction(songId: $0.id).calculateDynamicScore(now: now, currentTime: currentTime, isWeekend: isWeekend) >
            storage.getInteraction(songId: $1.id).calculateDynamicScore(now: now, currentTime: currentTime, isWeekend: isWeekend)
        }.prefix(25)
        
        if timeSongs.count >= 3 {
            generated.append(
                AiMix(
                    id: "ai_time_mix",
                    title: timeName,
                    subtitle: timeSub,
                    category: .timeOfDay,
                    songs: generateSmartShuffle(Array(timeSongs)),
                    gradientColors: timeColors,
                    iconName: currentTime == .night ? "moon.stars.fill" : "sun.max.fill",
                    description: "Adapts to your current temporal habits."
                )
            )
        }
        
        // 6. Forgotten Gems
        let twoWeeksAgo = now - (14 * 86400000)
        let forgotten = allSongs.filter { song in
            let interaction = storage.getInteraction(songId: song.id)
            return (interaction.isFavorite || interaction.playCount >= 2) &&
                   (interaction.lastPlayedTimestamp <= twoWeeksAgo)
        }.shuffled().prefix(22)
        if forgotten.count >= 3 {
            generated.append(
                AiMix(
                    id: "ai_forgotten_gems",
                    title: "Forgotten Gems",
                    subtitle: "Beloved tracks you haven't played in a while",
                    category: .forgottenGems,
                    songs: Array(forgotten),
                    gradientColors: [Color(hex: 0x10B981), Color(hex: 0x059669), Color(hex: 0x047857)],
                    iconName: "clock.arrow.circlepath",
                    description: "High affinity tracks waiting to be rediscovered."
                )
            )
        }
        
        // 7. Acoustic & Live Sessions
        let acousticLive = allSongs.filter { profileSong($0).isLiveOrAcoustic }
        if acousticLive.count >= 3 {
            generated.append(
                AiMix(
                    id: "ai_acoustic_live",
                    title: "Acoustic & Live",
                    subtitle: "Unplugged sessions and intimate concerts",
                    category: .acousticLive,
                    songs: generateSmartShuffle(acousticLive),
                    gradientColors: [Color(hex: 0xD97706), Color(hex: 0xB45309), Color(hex: 0x78350F)],
                    iconName: "mic.fill",
                    description: "Intelligent acoustic and live recording detection."
                )
            )
        }
        
        // 8. Top Artist Spotlight
        let artistsGrouped = Dictionary(grouping: allSongs, by: { $0.artist })
            .filter { !$0.key.isEmpty && $0.value.count >= 2 }
        if let top = artistsGrouped.max(by: { a, b in
            a.value.map { getSongAffinity(songId: $0.id) }.reduce(0, +) <
            b.value.map { getSongAffinity(songId: $0.id) }.reduce(0, +)
        }) {
            let artistSongs = top.value
            let kindred = allSongs.filter { $0.artist != top.key && computeSongSimilarity(artistSongs[0], $0) > 0.40 }
            let spotlight = Array((artistSongs + kindred.prefix(12)).prefix(25))
            if spotlight.count >= 3 {
                generated.append(
                    AiMix(
                        id: "ai_artist_\(top.key.hashValue)",
                        title: "Radio: \(top.key)",
                        subtitle: "Best of \(top.key) & kindred artists",
                        category: .artistSpotlight,
                        songs: generateSmartShuffle(spotlight),
                        gradientColors: [Color(hex: 0xE11D48), Color(hex: 0xBE123C), Color(hex: 0x881337)],
                        iconName: "person.crop.circle.fill",
                        description: "Continuous mix around your top artist."
                    )
                )
            }
        }
        
        self.aiMixes = generated
    }
}
