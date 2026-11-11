//
//  ArtworkCache.swift
//  Lune
//
//  High-performance in-memory cache for decoded UIImages.
//  Prevents decoding raw JPEG/PNG data on the main thread during view re-renders.
//

import UIKit

public final class ArtworkCache: @unchecked Sendable {
    public static let shared = ArtworkCache()
    
    private let cache = NSCache<NSString, UIImage>()
    
    private init() {
        // Cache up to 400 decoded artwork images
        cache.countLimit = 400
        cache.totalCostLimit = 100 * 1024 * 1024 // 100 MB max
    }
    
    public func image(for songId: Int64, data: Data?) -> UIImage? {
        guard let data = data, !data.isEmpty else { return nil }
        let key = NSString(string: "song_\(songId)")
        if let cached = cache.object(forKey: key) {
            return cached
        }
        if let decoded = UIImage(data: data) {
            cache.setObject(decoded, forKey: key, cost: data.count)
            return decoded
        }
        return nil
    }
    
    public func image(for key: String, data: Data?) -> UIImage? {
        guard let data = data, !data.isEmpty else { return nil }
        let nsKey = NSString(string: key)
        if let cached = cache.object(forKey: nsKey) {
            return cached
        }
        if let decoded = UIImage(data: data) {
            cache.setObject(decoded, forKey: nsKey, cost: data.count)
            return decoded
        }
        return nil
    }
    
    public func clear() {
        cache.removeAllObjects()
    }
}
