//
//  AVPlayerWrapper.swift
//  SwiftAudio
//
//  Created by Jørgen Henrichsen on 06/03/2018.
//  Copyright © 2018 Jørgen Henrichsen. All rights reserved.
//

import Foundation
import AVFoundation
import MediaPlayer

public enum PlaybackEndedReason: String {
    case playedUntilEnd
    case playerStopped
    case skippedToNext
    case skippedToPrevious
    case jumpedToIndex
    case cleared
    case failed
}

@available(iOS 13.0, *)
class AVPlayerWrapper: AVPlayerWrapperProtocol {
    // MARK: - Properties
    
    fileprivate var avPlayer = AVPlayer()
    private let playerObserver = AVPlayerObserver()
    internal let playerTimeObserver: AVPlayerTimeObserver
    private let playerItemNotificationObserver = AVPlayerItemNotificationObserver()
    private let playerItemObserver = AVPlayerItemObserver()
    fileprivate var timeToSeekToAfterLoading: TimeInterval?
    fileprivate var asset: AVAsset? = nil
    fileprivate var item: AVPlayerItem? = nil
    fileprivate var url: URL? = nil
    fileprivate var urlOptions: [String: Any]? = nil
    fileprivate let stateQueue = DispatchQueue(
        label: "AVPlayerWrapper.stateQueue",
        attributes: .concurrent
    )

    public init() {
        playerTimeObserver = AVPlayerTimeObserver(periodicObserverTimeInterval: timeEventFrequency.getTime())

        playerObserver.delegate = self
        playerTimeObserver.delegate = self
        playerItemNotificationObserver.delegate = self
        playerItemObserver.delegate = self

        setupAVPlayer();
    }
    
    // MARK: - AVPlayerWrapperProtocol

    fileprivate(set) var playbackError: AudioPlayerError.PlaybackError? = nil
    
    var _state: AVPlayerWrapperState = AVPlayerWrapperState.idle

    public func getState() -> AVPlayerWrapperState {
        var state: AVPlayerWrapperState!
        stateQueue.sync {
            state = _state
        }

        return state
    }
    
    public func setState(state: AVPlayerWrapperState) async {
        let currentState = _state
        if (currentState != state) {
            self._state = state
            await self.delegate?.AVWrapper(didChangeState: state)
        }
    }
    
    fileprivate(set) var lastPlayerTimeControlStatus: AVPlayer.TimeControlStatus = AVPlayer.TimeControlStatus.paused

    /**
     Whether AVPlayer should start playing automatically when the item is ready.
     */
    private var _playWhenReady: Bool = false

    public func getPlayWhenReady() -> Bool {
        return _playWhenReady
    }

    public func setPlayWhenReady(_ playWhenReady: Bool) async {
        let changed = self._playWhenReady != playWhenReady
        self._playWhenReady = playWhenReady
        let state = getState()
        if (playWhenReady == true && (state == .failed || state == .stopped)) {
            await reload(startFromCurrentTime: state == .failed)
        }

        applyAVPlayerRate()
        
        if changed {
            await delegate?.AVWrapper(didChangePlayWhenReady: playWhenReady)
        }
    }

    public func setPlayWhenReadyWithoutReloading(_ playWhenReady: Bool) async {
        let changed = self._playWhenReady != playWhenReady
        self._playWhenReady = playWhenReady

        applyAVPlayerRate()
        
        if changed {
            await delegate?.AVWrapper(didChangePlayWhenReady: playWhenReady)
        }
    }

    
    var currentItem: AVPlayerItem? {
        avPlayer.currentItem
    }

    var playbackActive: Bool {
        switch getState() {
        case .idle, .stopped, .ended, .failed:
            return false
        default: return true
        }
    }
    
    var currentTime: TimeInterval {
        let seconds = avPlayer.currentTime().seconds
        return seconds.isNaN ? 0 : seconds
    }
    
    var duration: TimeInterval {
        if let seconds = currentItem?.asset.duration.seconds, !seconds.isNaN {
            return seconds
        }
        else if let seconds = currentItem?.duration.seconds, !seconds.isNaN {
            return seconds
        }
        else if let seconds = currentItem?.seekableTimeRanges.last?.timeRangeValue.duration.seconds,
                !seconds.isNaN {
            return seconds
        }
        return 0.0
    }
    
    var bufferedPosition: TimeInterval {
        currentItem?.loadedTimeRanges.last?.timeRangeValue.end.seconds ?? 0
    }

    var reasonForWaitingToPlay: AVPlayer.WaitingReason? {
        avPlayer.reasonForWaitingToPlay
    }

    private var _rate: Float = 1.0;
    var rate: Float {
        get { _rate }
        set {
            _rate = newValue
            applyAVPlayerRate()
        }
    }

    weak var delegate: AVPlayerWrapperDelegate? = nil
    
    var bufferDuration: TimeInterval = 0

    var timeEventFrequency: TimeEventFrequency = .everySecond {
        didSet {
            playerTimeObserver.periodicObserverTimeInterval = timeEventFrequency.getTime()
        }
    }
    
    var volume: Float {
        get { avPlayer.volume }
        set { avPlayer.volume = newValue }
    }
    
    var isMuted: Bool {
        get { avPlayer.isMuted }
        set { avPlayer.isMuted = newValue }
    }

    var automaticallyWaitsToMinimizeStalling: Bool {
        get { avPlayer.automaticallyWaitsToMinimizeStalling }
        set { avPlayer.automaticallyWaitsToMinimizeStalling = newValue }
    }
    
    func play() async {
        await setPlayWhenReady(true)
    }
    
    func pause() async {
        await setPlayWhenReady(false)
    }
    
    func togglePlaying() async {
        switch avPlayer.timeControlStatus {
        case .playing, .waitingToPlayAtSpecifiedRate:
            await pause()
        case .paused:
            await play()
        @unknown default:
            fatalError("Unknown AVPlayer.timeControlStatus")
        }
    }
    
    func stop() async {
        await setState(state: .stopped)
        clearCurrentItem()
        await setPlayWhenReady(false)
    }
    
    func seek(to seconds: TimeInterval) async {
       // if the player is loading then we need to defer seeking until it's ready.
        if (avPlayer.currentItem == nil) {
         timeToSeekToAfterLoading = seconds
       } else {
           let time = CMTimeMakeWithSeconds(seconds, preferredTimescale: 1000)
           let finished = await withCheckedContinuation { continuation in
               avPlayer.seek(to: time, toleranceBefore: CMTime.zero, toleranceAfter: CMTime.zero) { (finished) in
                   continuation.resume(returning: finished)
               }
           }
           await self.delegate?.AVWrapper(seekTo: Double(seconds), didFinish: finished)
       }
     }

    func seek(by seconds: TimeInterval) async {
        if let currentItem = avPlayer.currentItem {
            let time = CMTimeMakeWithSeconds(currentItem.currentTime().seconds + seconds, preferredTimescale: 1000)
            await withCheckedContinuation { continuation in
                avPlayer.seek(to: time, toleranceBefore: CMTime.zero, toleranceAfter: CMTime.zero) {_ in
                    continuation.resume()
                }
            }
        } else {
            if let timeToSeekToAfterLoading = timeToSeekToAfterLoading {
                self.timeToSeekToAfterLoading = timeToSeekToAfterLoading + seconds
            } else {
                timeToSeekToAfterLoading = seconds
            }
        }
    }
    
    private func playbackFailed(error: AudioPlayerError.PlaybackError) async {
        self.playbackError = error
        await setState(state: .failed)
        await self.delegate?.AVWrapper(failedWithError: error)
    }
    
    func load() async {
        let state = getState()
        if (state == .failed) {
            await recreateAVPlayer()
        } else {
            clearCurrentItem()
        }
        if let url = url {
            let keys = ["playable"]
            let pendingAsset = AVURLAsset(url: url, options: urlOptions)
            asset = pendingAsset
            await setState(state: .loading)
            await withCheckedContinuation { continuation in
                pendingAsset.loadValuesAsynchronously(forKeys: keys, completionHandler: {
                    continuation.resume()
                })
            }
            if (pendingAsset != self.asset) { return; }
            
            for key in keys {
                var error: NSError?
                let keyStatus = pendingAsset.statusOfValue(forKey: key, error: &error)
                switch keyStatus {
                case .failed:
                    await self.playbackFailed(error: AudioPlayerError.PlaybackError.failedToLoadKeyValue)
                    return
                case .cancelled, .loading, .unknown:
                    return
                case .loaded:
                    break
                default: break
                }
            }
            
            if (!pendingAsset.isPlayable) {
                await self.playbackFailed(error: AudioPlayerError.PlaybackError.itemWasUnplayable)
                return;
            }
            
            let item = AVPlayerItem(
                asset: pendingAsset,
                automaticallyLoadedAssetKeys: keys
            )
            self.item = item;
            item.preferredForwardBufferDuration = self.bufferDuration
            self.avPlayer.replaceCurrentItem(with: item)
            self.startObservingAVPlayer(item: item)
            self.applyAVPlayerRate()
            if pendingAsset.availableChapterLocales.count > 0 {
                for locale in pendingAsset.availableChapterLocales {
                    let chapters = pendingAsset.chapterMetadataGroups(withTitleLocale: locale, containingItemsWithCommonKeys: nil)
                    await self.delegate?.AVWrapper(didReceiveMetadata: chapters)
                }
            } else {
                for format in pendingAsset.availableMetadataFormats {
                    let timeRange = CMTimeRange(start: CMTime(seconds: 0, preferredTimescale: 1000), end: pendingAsset.duration)
                    let group = AVTimedMetadataGroup(items: pendingAsset.metadata(forFormat: format), timeRange: timeRange)
                    await self.delegate?.AVWrapper(didReceiveMetadata: [group])
                }
            }
            
            if let initialTime = self.timeToSeekToAfterLoading {
                self.timeToSeekToAfterLoading = nil
                await self.seek(to: initialTime)
            }
        }
    }
    
    func load(from url: URL, playWhenReady: Bool, options: [String: Any]? = nil) async {
        self.url = url
        self.urlOptions = options
        await setPlayWhenReadyWithoutReloading(playWhenReady)
        await self.load()
    }
    
    func load(
        from url: URL,
        playWhenReady: Bool,
        initialTime: TimeInterval? = nil,
        options: [String : Any]? = nil
    ) async {
        await self.load(from: url, playWhenReady: playWhenReady, options: options)
        if let initialTime = initialTime {
            await self.seek(to: initialTime)
        }
    }

    func load(
        from url: String,
        type: SourceType = .stream,
        playWhenReady: Bool = false,
        initialTime: TimeInterval? = nil,
        options: [String : Any]? = nil
    ) async {
        if let itemUrl = type == .file
            ? URL(fileURLWithPath: url)
            : URL(string: url)
        {
            await self.load(from: itemUrl, playWhenReady: playWhenReady, options: options)
            if let initialTime = initialTime {
                await self.seek(to: initialTime)
            }
        } else {
            clearCurrentItem()
            await playbackFailed(error: AudioPlayerError.PlaybackError.invalidSourceUrl(url))
        }
    }

    func unload() async {
        clearCurrentItem()
        await setState(state: .idle)
    }

    func reload(startFromCurrentTime: Bool) async {
        var time : Double? = nil
        if (startFromCurrentTime) {
            if let currentItem = currentItem {
                if (!currentItem.duration.isIndefinite) {
                    time = currentItem.currentTime().seconds
                }
            }
        }
        await load()
        if let time = time {
            await seek(to: time)
        }
    }
    
    // MARK: - Util

    private func clearCurrentItem() {
        guard let asset = asset else { return }
        stopObservingAVPlayerItem()
        
        asset.cancelLoading()
        self.asset = nil
        
        avPlayer.replaceCurrentItem(with: nil)
    }
    
    private func startObservingAVPlayer(item: AVPlayerItem) {
        playerItemObserver.startObserving(item: item)
        playerItemNotificationObserver.startObserving(item: item)
    }

    private func stopObservingAVPlayerItem() {
        playerItemObserver.stopObservingCurrentItem()
        playerItemNotificationObserver.stopObservingCurrentItem()
    }
    
    private func recreateAVPlayer() async {
        playbackError = nil
        playerTimeObserver.unregisterForBoundaryTimeEvents()
        playerTimeObserver.unregisterForPeriodicEvents()
        playerObserver.stopObserving()
        stopObservingAVPlayerItem()
        clearCurrentItem()

        avPlayer = AVPlayer();
        setupAVPlayer()

        await delegate?.AVWrapperDidRecreateAVPlayer()
    }
    
    private func setupAVPlayer() {
        // disabled since we're not making use of video playback
        avPlayer.allowsExternalPlayback = false;

        playerObserver.player = avPlayer
        playerObserver.startObserving()

        playerTimeObserver.player = avPlayer
        playerTimeObserver.registerForBoundaryTimeEvents()
        playerTimeObserver.registerForPeriodicTimeEvents()

        applyAVPlayerRate()
    }
    
    private func applyAVPlayerRate() {
        avPlayer.rate = getPlayWhenReady() ? _rate : 0
    }
}

@available(iOS 13.0, *)
extension AVPlayerWrapper: AVPlayerObserverDelegate {
    
    // MARK: - AVPlayerObserverDelegate
    
    func player(didChangeTimeControlStatus status: AVPlayer.TimeControlStatus) async {
        switch status {
        case .paused:
            let state = getState()
            if self.asset == nil && state != .stopped && state != .failed {
                await setState(state: .idle)
            } else if (state != .failed && state != .stopped && state != .loading) {
                // Playback may have become paused externally for example due to a bluetooth device disconnecting:
                if (self.getPlayWhenReady()) {
                    // Only if we are not on the boundaries of the track, otherwise itemDidPlayToEndTime will handle it instead.
                    if (self.currentTime > 0 && self.currentTime < self.duration) {
                        await setPlayWhenReady(false)
                    }
                } else {
                    await setState(state: .paused)
                }
            }
        case .waitingToPlayAtSpecifiedRate:
            let state = getState()
            if self.asset != nil && state != .failed {
                await setState(state: .buffering)
            }
        case .playing:
            await setState(state: .playing)
        @unknown default:
            break
        }
    }
    
    func player(statusDidChange status: AVPlayer.Status) async {
        if (status == .failed) {
            let error = item!.error as NSError?
            await playbackFailed(error: error?.code == URLError.notConnectedToInternet.rawValue
                 ? AudioPlayerError.PlaybackError.notConnectedToInternet
                 : AudioPlayerError.PlaybackError.playbackFailed
            )
        }
    }
}

@available(iOS 13.0, *)
extension AVPlayerWrapper: AVPlayerTimeObserverDelegate {
    
    // MARK: - AVPlayerTimeObserverDelegate
    
    func audioDidStart() async {
        await setState(state: .playing)
    }
    
    func timeEvent(time: CMTime) async {
        await delegate?.AVWrapper(secondsElapsed: time.seconds)
    }
    
}

@available(iOS 13.0, *)
extension AVPlayerWrapper: AVPlayerItemNotificationObserverDelegate {
    // MARK: - AVPlayerItemNotificationObserverDelegate

    func itemFailedToPlayToEndTime() async {
        await playbackFailed(error: AudioPlayerError.PlaybackError.playbackFailed)
        await delegate?.AVWrapperItemFailedToPlayToEndTime()
    }
    
    func itemPlaybackStalled() async {
        await delegate?.AVWrapperItemPlaybackStalled()
    }
    
    func itemDidPlayToEndTime() async {
        await delegate?.AVWrapperItemDidPlayToEndTime()
    }
    
}

@available(iOS 13.0, *)
extension AVPlayerWrapper: AVPlayerItemObserverDelegate {
    // MARK: - AVPlayerItemObserverDelegate

    func item(didUpdatePlaybackLikelyToKeepUp playbackLikelyToKeepUp: Bool) async {
        if (playbackLikelyToKeepUp && getState() != .playing) {
            await setState(state: .ready)
        }
    }
        
    func item(didUpdateDuration duration: Double) async {
        await delegate?.AVWrapper(didUpdateDuration: duration)
    }
    
    func item(didReceiveMetadata metadata: [AVTimedMetadataGroup]) async {
        await delegate?.AVWrapper(didReceiveMetadata: metadata)
    }
}
