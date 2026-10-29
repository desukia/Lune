//
//  AiModels.swift
//  Lune
//
//  Data models for on-device AI Engine telemetry and personalized mixes.
//  100% offline, privacy-first heuristic algorithms.
//

import SwiftUI

public enum TimeOfDay: String, CaseIterable, Codable, Sendable {
    case morning = "Morning"
    case afternoon = "Afternoon"
    case evening = "Evening"
    case night = "Night"
    
    public static func current() -> TimeOfDay {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5...11: return .morning
        case 12...17: return .afternoon
        case 18...22: return .evening
        default: return .night
        }
    }
}

public enum DayType: String, CaseIterable, Codable, Sendable {
    case weekday = "Weekday"
    case weekend = "Weekend"
    
    public static func current() -> DayType {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return (weekday == 1 || weekday == 7) ? .weekend : .weekday
    }
}

public enum MixCategory: String, CaseIterable, Codable, Sendable {
    case dailyFlow = "DAILY_FLOW"
    case energy = "ENERGY"
    case chill = "CHILL"
    case discovery = "DISCOVERY"
    case focus = "FOCUS"
    case acousticLive = "ACOUSTIC_LIVE"
    case forgottenGems = "FORGOTTEN_GEMS"
    case timeOfDay = "TIME_OF_DAY"
    case artistSpotlight = "ARTIST_SPOTLIGHT"
    case genreDiscovery = "GENRE_DISCOVERY"
}

public struct SongInteraction: Identifiable, Codable, Sendable {
    public var id: Int64 { songId }
    public let songId: Int64
    public var playCount: Int = 0
    public var fullCompletions: Int = 0
    public var fastSkips: Int = 0
    public var repeatCount: Int = 0
    public var lastPlayedTimestamp: Int64 = 0
    public var morningPlays: Int = 0
    public var afternoonPlays: Int = 0
    public var eveningPlays: Int = 0
    public var nightPlays: Int = 0
    public var weekdayPlays: Int = 0
    public var weekendPlays: Int = 0
    public var isFavorite: Bool = false
    public var playlistAddCount: Int = 0
    public var consecutiveSkips: Int = 0
    public var nextSongTransitions: [String: Int] = [:]
    
    public init(songId: Int64) {
        self.songId = songId
    }
    
    public func calculateAffinityScore() -> Float {
        var score: Float = 10.0
        score += Float(playCount) * 1.5
        score += Float(fullCompletions) * 3.5
        score += Float(repeatCount) * 4.5
        score -= Float(fastSkips) * 2.5
        score -= Float(consecutiveSkips) * 3.0
        if isFavorite { score += 9.0 }
        score += Float(playlistAddCount) * 3.5
        return max(0.5, score)
    }
    
    public func calculateDynamicScore(now: Int64, currentTime: TimeOfDay, isWeekend: Bool) -> Float {
        let baseScore = calculateAffinityScore()
        let timeFactor = 1.0 + (getTimeAffinity(timeOfDay: currentTime) * 0.40)
        
        let totalDays = max(1, weekdayPlays + weekendPlays)
        let dayFactor: Float
        if isWeekend {
            dayFactor = 1.0 + ((Float(weekendPlays) / Float(totalDays)) * 0.25)
        } else {
            dayFactor = 1.0 + ((Float(weekdayPlays) / Float(totalDays)) * 0.25)
        }
        
        // Fatigue attenuation
        let timeSinceLast = now - lastPlayedTimestamp
        let fatigueMultiplier: Float
        if lastPlayedTimestamp <= 0 {
            fatigueMultiplier = 1.0
        } else if timeSinceLast < 30 * 60 * 1000 {
            fatigueMultiplier = 0.20
        } else if timeSinceLast < 2 * 3600 * 1000 {
            fatigueMultiplier = 0.50
        } else if timeSinceLast < 6 * 3600 * 1000 {
            fatigueMultiplier = 0.80
        } else {
            fatigueMultiplier = 1.0
        }
        
        // Novelty bonus (played between 2 and 14 days ago)
        let noveltyBonus: Float = (timeSinceLast >= 2 * 86400000 && timeSinceLast <= 14 * 86400000) ? 1.18 : 1.0
        
        return max(0.1, baseScore * timeFactor * dayFactor * fatigueMultiplier * noveltyBonus)
    }
    
    public func getTimeAffinity(timeOfDay: TimeOfDay) -> Float {
        let total = max(1, morningPlays + afternoonPlays + eveningPlays + nightPlays)
        let target: Int
        switch timeOfDay {
        case .morning: target = morningPlays
        case .afternoon: target = afternoonPlays
        case .evening: target = eveningPlays
        case .night: target = nightPlays
        }
        return Float(target) / Float(total)
    }
    
    public mutating func recordTransition(to nextSongId: Int64) {
        let key = String(nextSongId)
        nextSongTransitions[key, default: 0] += 1
    }
    
    public func getTransitionProbability(to nextSongId: Int64) -> Float {
        guard !nextSongTransitions.isEmpty else { return 0 }
        let key = String(nextSongId)
        let count = nextSongTransitions[key] ?? 0
        let total = max(1, nextSongTransitions.values.reduce(0, +))
        return Float(count) / Float(total)
    }
}

public struct AiMix: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let category: MixCategory
    public var songs: [Song]
    public let gradientColors: [Color]
    public let iconName: String
    public let description: String
    
    public init(
        id: String,
        title: String,
        subtitle: String,
        category: MixCategory,
        songs: [Song],
        gradientColors: [Color],
        iconName: String = "sparkles",
        description: String = ""
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.category = category
        self.songs = songs
        self.gradientColors = gradientColors
        self.iconName = iconName
        self.description = description
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: AiMix, rhs: AiMix) -> Bool {
        lhs.id == rhs.id
    }
}
