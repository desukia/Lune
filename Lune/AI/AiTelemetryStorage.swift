//
//  AiTelemetryStorage.swift
//  Lune
//
//  Thread-safe on-device telemetry storage for user habits and Markov transitions.
//

import Foundation

public final class AiTelemetryStorage: @unchecked Sendable {
    public static let shared = AiTelemetryStorage()
    
    private let lock = NSLock()
    private var cache: [Int64: SongInteraction] = [:]
    private let fileURL: URL
    private var saveWorkItem: DispatchWorkItem?
    private let queue = DispatchQueue(label: "com.demonlab.lune.aistorage", qos: .utility)
    
    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        self.fileURL = appSupport.appendingPathComponent("lune_ai_telemetry.json")
        loadFromDisk()
    }
    
    private func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let loaded = try? JSONDecoder().decode([String: SongInteraction].self, from: data) else {
            return
        }
        lock.lock()
        defer { lock.unlock() }
        for (k, v) in loaded {
            if let id = Int64(k) {
                cache[id] = v
            }
        }
    }
    
    public func getInteraction(songId: Int64) -> SongInteraction {
        lock.lock()
        defer { lock.unlock() }
        if let existing = cache[songId] {
            return existing
        }
        let fresh = SongInteraction(songId: songId)
        cache[songId] = fresh
        return fresh
    }
    
    public func recordInteraction(songId: Int64, mutate: (inout SongInteraction) -> Void) {
        lock.lock()
        var interaction = cache[songId] ?? SongInteraction(songId: songId)
        mutate(&interaction)
        cache[songId] = interaction
        lock.unlock()
        scheduleSave()
    }
    
    private func scheduleSave() {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.saveWorkItem?.cancel()
            let item = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                self.lock.lock()
                var dict: [String: SongInteraction] = [:]
                for (k, v) in self.cache {
                    dict[String(k)] = v
                }
                self.lock.unlock()
                
                if let encoded = try? JSONEncoder().encode(dict) {
                    try? encoded.write(to: self.fileURL, options: .atomic)
                }
            }
            self.saveWorkItem = item
            self.queue.asyncAfter(deadline: .now() + 1.5, execute: item)
        }
    }
    
    public func clearAll() {
        lock.lock()
        cache.removeAll()
        lock.unlock()
        try? FileManager.default.removeItem(at: fileURL)
    }
}
