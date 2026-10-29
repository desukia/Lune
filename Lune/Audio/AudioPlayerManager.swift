//
//  AudioPlayerManager.swift
//  Lune
//
//  Core Audio Playback Engine ported from Android PlaybackManager.kt:
//  - AVAudioEngine + AVAudioPlayerNode architecture
//  - Seamless integration with Equalizer, Reverb, Pitch, Visualizer
//  - Lock Screen Media Controls (MPNowPlayingInfoCenter & MPRemoteCommandCenter)
//  - Queue Management, Smart Shuffle, Repeat Modes
//  - Crossfade, Sleep Timer, Audio Interruptions
//

import AVFoundation
import MediaPlayer
import SwiftUI
import Combine

public enum RepeatMode: Int, CaseIterable, Identifiable, Codable {
    case off = 0
    case all = 1
    case one = 2
    
    public var id: Int { rawValue }
    
    public var iconName: String {
        switch self {
        case .off: return "repeat"
        case .all: return "repeat"
        case .one: return "repeat.1"
        }
    }
}

@MainActor
public final class AudioPlayerManager: ObservableObject {
    public static let shared = AudioPlayerManager()
    
    // Engine & Nodes
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let eq = EqualizerEngine.shared
    private let visualizer = VisualizerEngine.shared
    
    // State
    @Published public var currentSong: Song? = nil
    @Published public var isPlaying: Bool = false
    @Published public var currentTime: TimeInterval = 0.0
    @Published public var duration: TimeInterval = 0.0
    @Published public var playbackProgress: Float = 0.0
    @Published public var isShuffleEnabled: Bool = false
    @Published public var repeatMode: RepeatMode = .off
    @Published public var queue: [Song] = []
    @Published public var currentIndex: Int = 0
    @Published public var visualizerBars: [Float] = Array(repeating: 0.1, count: 48)
    
    // Volume Control
    @Published public var volume: Float = 1.0 {
        didSet {
            engine.mainMixerNode.outputVolume = max(0.0, min(1.0, volume))
        }
    }
    
    // Sleep Timer
    @Published public var sleepTimerMinutesRemaining: Int? = nil
    private var sleepTimer: Timer? = nil
    
    // Internal playback tracking
    private var audioFile: AVAudioFile? = nil
    private var songStartTime: Date? = nil
    private var timeObserverTimer: Timer? = nil
    private var sampleRate: Double = 44100.0
    private var lengthSamples: AVAudioFramePosition = 0
    private var seekFrame: AVAudioFramePosition = 0
    private var isSeeking: Bool = false
    private var playbackGeneration: Int = 0
    
    private init() {
        setupAudioSession()
        setupAudioGraph()
        setupRemoteCommands()
        setupVisualizerTap()
    }
    
    // MARK: - Audio Session & Graph
    
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, policy: .longFormAudio, options: [])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleInterruption),
                name: AVAudioSession.interruptionNotification,
                object: nil
            )
            
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleRouteChange),
                name: AVAudioSession.routeChangeNotification,
                object: nil
            )
            
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleEngineConfigurationChange),
                name: .AVAudioEngineConfigurationChange,
                object: engine
            )
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }
    
    private func setupAudioGraph() {
        engine.attach(playerNode)
        engine.attach(eq.eqUnit)
        engine.attach(eq.reverbUnit)
        engine.attach(eq.timePitchUnit)
        
        // Connections: playerNode -> eq -> reverb -> pitch -> mainMixer -> output
        engine.connect(playerNode, to: eq.eqUnit, format: nil)
        engine.connect(eq.eqUnit, to: eq.reverbUnit, format: nil)
        engine.connect(eq.reverbUnit, to: eq.timePitchUnit, format: nil)
        engine.connect(eq.timePitchUnit, to: engine.mainMixerNode, format: nil)
        
        do {
            try engine.start()
            volume = engine.mainMixerNode.outputVolume
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }
    
    private func setupVisualizerTap() {
        let mixer = engine.mainMixerNode
        let format = mixer.outputFormat(forBus: 0)
        mixer.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard UIApplication.shared.applicationState != .background else { return }
            self?.visualizer.processAudioBuffer(buffer)
        }
        
        visualizer.onMagnitudesUpdated = { [weak self] magnitudes in
            Task { @MainActor [weak self] in
                self?.visualizerBars = magnitudes
            }
        }
    }
    
    // MARK: - Queue & Playback Control
    
    public func playQueue(_ songs: [Song], startingAt index: Int = 0) {
        guard !songs.isEmpty else { return }
        self.queue = songs
        self.currentIndex = max(0, min(songs.count - 1, index))
        playSong(songs[currentIndex])
    }
    
    public func playSong(_ song: Song) {
        // Record telemetry on previous song
        if let current = currentSong {
            LuneAiEngine.shared.onSongSkipped(
                current,
                playedSeconds: currentTime,
                totalDurationSeconds: duration
            )
        }
        
        var playingSong = song
        playingSong.isFavorite = DataStore.shared.isFavorite(songId: song.id)
        self.currentSong = playingSong
        self.duration = song.duration
        self.currentTime = 0.0
        self.playbackProgress = 0.0
        self.songStartTime = Date()
        
        // Ensure queue is populated
        if queue.isEmpty || !queue.contains(where: { $0.id == song.id }) {
            let all = MusicLibraryManager.shared.allSongs
            if !all.isEmpty {
                self.queue = all
                self.currentIndex = all.firstIndex(where: { $0.id == song.id }) ?? 0
            } else {
                self.queue = [song]
                self.currentIndex = 0
            }
        } else {
            self.currentIndex = queue.firstIndex(where: { $0.id == song.id }) ?? 0
        }
        
        do {
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try? AVAudioSession.sharedInstance().setActive(true)
            if !engine.isRunning {
                try engine.start()
            }
            
            // Invalidate completion handlers from previous songs
            playbackGeneration += 1
            playerNode.stop()
            
            let file = try AVAudioFile(forReading: song.url)
            self.audioFile = file
            self.sampleRate = file.processingFormat.sampleRate
            self.lengthSamples = file.length
            self.seekFrame = 0
            
            scheduleBuffer(from: 0)
            playerNode.play()
            self.isPlaying = true
            
            startTimeObserver()
            updateNowPlayingInfo()
            
            LuneAiEngine.shared.onSongStarted(song)
        } catch {
            print("Failed to play song '\(song.title)': \(error)")
        }
    }
    
    private func scheduleBuffer(from frame: AVAudioFramePosition) {
        guard let file = audioFile else { return }
        let totalFrames = file.length
        guard frame < totalFrames else {
            handleSongEnded()
            return
        }
        
        let framesToRead = AVAudioFrameCount(totalFrames - frame)
        file.framePosition = frame
        
        let currentGeneration = playbackGeneration
        
        playerNode.scheduleSegment(
            file,
            startingFrame: frame,
            frameCount: framesToRead,
            at: nil
        ) { [weak self] in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                // Discard completion handler if playback was stopped, skipped, or seeked
                guard self.playbackGeneration == currentGeneration else { return }
                guard self.isPlaying && !self.isSeeking else { return }
                
                // Confirm the audio segment actually reached near the end of the song
                if let nodeTime = self.playerNode.lastRenderTime,
                   let playerTime = self.playerNode.playerTime(forNodeTime: nodeTime) {
                    let playedFrame = playerTime.sampleTime + self.seekFrame
                    let threshold = AVAudioFramePosition(self.sampleRate * 0.5)
                    if playedFrame >= self.lengthSamples - threshold {
                        self.handleSongEnded()
                    }
                } else if self.currentTime >= max(1.0, self.duration - 1.0) {
                    self.handleSongEnded()
                }
            }
        }
    }
    
    public func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            resume()
        }
    }
    
    public func resume() {
        guard currentSong != nil else { return }
        if !engine.isRunning { try? engine.start() }
        playerNode.play()
        isPlaying = true
        startTimeObserver()
        updateNowPlayingInfo()
    }
    
    public func pause() {
        playerNode.pause()
        isPlaying = false
        stopTimeObserver()
        updateNowPlayingInfo()
    }
    
    public func next() {
        if queue.isEmpty {
            let all = MusicLibraryManager.shared.allSongs
            if !all.isEmpty {
                self.queue = all
                if let current = currentSong {
                    self.currentIndex = all.firstIndex(where: { $0.id == current.id }) ?? 0
                }
            }
        }
        guard !queue.isEmpty else { return }
        
        if repeatMode == .one {
            if let song = currentSong {
                playSong(song)
            }
            return
        }
        
        if isShuffleEnabled {
            var nextIdx = Int.random(in: 0..<queue.count)
            if queue.count > 1 && nextIdx == currentIndex {
                nextIdx = (currentIndex + 1) % queue.count
            }
            currentIndex = nextIdx
            playSong(queue[currentIndex])
            return
        }
        
        if currentIndex + 1 < queue.count {
            currentIndex += 1
            playSong(queue[currentIndex])
        } else {
            currentIndex = 0
            playSong(queue[0])
        }
    }
    
    public func previous() {
        if queue.isEmpty {
            let all = MusicLibraryManager.shared.allSongs
            if !all.isEmpty {
                self.queue = all
                if let current = currentSong {
                    self.currentIndex = all.firstIndex(where: { $0.id == current.id }) ?? 0
                }
            }
        }
        guard !queue.isEmpty else { return }
        
        if currentTime > 3.0 {
            seek(to: 0.0)
            return
        }
        
        if isShuffleEnabled {
            var prevIdx = Int.random(in: 0..<queue.count)
            if queue.count > 1 && prevIdx == currentIndex {
                prevIdx = (currentIndex - 1 + queue.count) % queue.count
            }
            currentIndex = prevIdx
            playSong(queue[currentIndex])
            return
        }
        
        if currentIndex > 0 {
            currentIndex -= 1
            playSong(queue[currentIndex])
        } else {
            currentIndex = queue.count - 1
            playSong(queue[currentIndex])
        }
    }
    
    public func seek(to seconds: TimeInterval) {
        guard audioFile != nil else { return }
        isSeeking = true
        playbackGeneration += 1
        let targetSeconds = max(0, min(duration, seconds))
        let targetFrame = AVAudioFramePosition(targetSeconds * sampleRate)
        
        playerNode.stop()
        seekFrame = targetFrame
        currentTime = targetSeconds
        playbackProgress = duration > 0 ? Float(targetSeconds / duration) : 0
        
        scheduleBuffer(from: targetFrame)
        if isPlaying {
            playerNode.play()
        }
        isSeeking = false
        updateNowPlayingInfo()
    }
    
    private func handleSongEnded() {
        if let current = currentSong {
            LuneAiEngine.shared.onSongCompleted(current)
        }
        next()
    }
    
    public func toggleShuffle() {
        isShuffleEnabled.toggle()
        if isShuffleEnabled {
            if let current = currentSong {
                queue = LuneAiEngine.shared.generateSmartShuffle(queue, startingSong: current)
                currentIndex = queue.firstIndex(where: { $0.id == current.id }) ?? 0
            } else {
                queue.shuffle()
            }
        }
    }
    
    public func cycleRepeatMode() {
        let nextRaw = (repeatMode.rawValue + 1) % 3
        repeatMode = RepeatMode(rawValue: nextRaw) ?? .off
    }
    
    // MARK: - Sleep Timer
    
    public func setSleepTimer(minutes: Int) {
        sleepTimer?.invalidate()
        guard minutes > 0 else {
            sleepTimerMinutesRemaining = nil
            return
        }
        sleepTimerMinutesRemaining = minutes
        sleepTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] timer in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if let rem = self.sleepTimerMinutesRemaining, rem > 1 {
                    self.sleepTimerMinutesRemaining = rem - 1
                } else {
                    timer.invalidate()
                    self.sleepTimerMinutesRemaining = nil
                    self.pause()
                }
            }
        }
    }
    
    // MARK: - Time Observer
    
    private func startTimeObserver() {
        stopTimeObserver()
        timeObserverTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.isPlaying, !self.isSeeking else { return }
                if let nodeTime = self.playerNode.lastRenderTime,
                   let playerTime = self.playerNode.playerTime(forNodeTime: nodeTime) {
                    let seconds = Double(playerTime.sampleTime + self.seekFrame) / self.sampleRate
                    if seconds >= 0 && seconds <= self.duration {
                        self.currentTime = seconds
                        self.playbackProgress = Float(seconds / max(1.0, self.duration))
                    }
                }
            }
        }
    }
    
    private func stopTimeObserver() {
        timeObserverTimer?.invalidate()
        timeObserverTimer = nil
    }
    
    // MARK: - Lock Screen & Remote Controls
    
    private func setupRemoteCommands() {
        UIApplication.shared.beginReceivingRemoteControlEvents()
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.resume() }
            return .success
        }
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.pause() }
            return .success
        }
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.togglePlayPause() }
            return .success
        }
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.next() }
            return .success
        }
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.previous() }
            return .success
        }
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let posEvent = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            Task { @MainActor [weak self] in self?.seek(to: posEvent.positionTime) }
            return .success
        }
    }
    
    private func updateNowPlayingInfo() {
        guard let song = currentSong else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: song.title,
            MPMediaItemPropertyArtist: song.artist,
            MPMediaItemPropertyAlbumTitle: song.album,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
        
        if let artData = song.artworkData, let image = UIImage(data: artData) {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
    
    @objc private func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
        
        if type == .began {
            pause()
        } else if type == .ended {
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    resume()
                }
            }
        }
    }
    
    @objc private func handleRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }
        
        if reason == .oldDeviceUnavailable {
            Task { @MainActor [weak self] in
                self?.pause()
            }
        }
    }
    
    @objc private func handleEngineConfigurationChange(notification: Notification) {
        Task { @MainActor [weak self] in
            guard let self = self, self.isPlaying else { return }
            do {
                if !self.engine.isRunning {
                    try self.engine.start()
                    self.playerNode.play()
                }
            } catch {
                print("Failed to restart audio engine on configuration change: \(error)")
            }
        }
    }
}
