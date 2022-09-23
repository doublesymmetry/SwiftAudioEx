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
}

class AVPlayerWrapper: AVPlayerWrapperProtocol {
    struct Constants {
        static let assetPlayableKey = "playable"
    }
    
    // MARK: - Properties
    
    fileprivate var avPlayer = AVPlayer()
    private let playerObserver = AVPlayerObserver()
    internal let playerTimeObserver: AVPlayerTimeObserver
    private let playerItemNotificationObserver = AVPlayerItemNotificationObserver()
    private let playerItemObserver = AVPlayerItemObserver()
    fileprivate var timeToSeekToAfterLoading: TimeInterval?
    fileprivate var pendingAsset: AVAsset? = nil
    
    public init() {
        playerTimeObserver = AVPlayerTimeObserver(periodicObserverTimeInterval: timeEventFrequency.getTime())

        playerObserver.delegate = self
        playerTimeObserver.delegate = self
        playerItemNotificationObserver.delegate = self
        playerItemObserver.delegate = self

        setupAVPlayer();
    }
    
    // MARK: - AVPlayerWrapperProtocol

    fileprivate(set) var state: AVPlayerWrapperState = AVPlayerWrapperState.idle {
        didSet {
            if oldValue != state {
                delegate?.AVWrapper(didChangeState: state)
            }
        }
    }

    fileprivate(set) var lastPlayerTimeControlStatus: AVPlayer.TimeControlStatus = AVPlayer.TimeControlStatus.paused {
        didSet {
            if oldValue != lastPlayerTimeControlStatus {
                switch lastPlayerTimeControlStatus {
                    case .paused:
                        if pendingAsset == nil {
                            state = .idle
                        } else if (playWhenReady == false) {
                            state = .paused
                        }
                    case .waitingToPlayAtSpecifiedRate:
                        if pendingAsset != nil {
                            state = .buffering
                        }
                    case .playing:
                        state = .playing
                    @unknown default:
                        break
                }
            }
        }
    }

    /**
     Whether AVPlayer should start playing automatically when the item is ready.
     */
    public var playWhenReady: Bool = false {
        didSet {
            if oldValue != playWhenReady {
                applyAVPlayerRate()
                delegate?.AVWrapper(didChangePlayWhenReady: playWhenReady)
            }
        }
    }
    
    var currentItem: AVPlayerItem? {
        avPlayer.currentItem
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
    
    func play() {
        playWhenReady = true
    }
    
    func pause() {
        playWhenReady = false
    }
    
    func togglePlaying() {
        switch avPlayer.timeControlStatus {
        case .playing, .waitingToPlayAtSpecifiedRate:
            pause()
        case .paused:
            play()
        @unknown default:
            fatalError("Unknown AVPlayer.timeControlStatus")
        }
    }
    
    func stop() {
        reset()
    }
    
    func seek(to seconds: TimeInterval) {
       // if the player is loading then we need to defer seeking until it's ready.
        if (avPlayer.currentItem == nil) {
         timeToSeekToAfterLoading = seconds
       } else {
         avPlayer.seek(to: CMTimeMakeWithSeconds(seconds, preferredTimescale: 1000)) { (finished) in
             self.delegate?.AVWrapper(seekTo: Double(seconds), didFinish: finished)
         }
       }
     }
    
    func load(from url: URL, playWhenReady: Bool, options: [String: Any]? = nil) {
        self.playWhenReady = playWhenReady

        if currentItem?.status == .failed {
            recreateAVPlayer()
        } else {
            reset()
        }
        
        pendingAsset = AVURLAsset(url: url, options: options)
        if let pendingAsset = pendingAsset {
            state = .loading
            pendingAsset.loadValuesAsynchronously(forKeys: [Constants.assetPlayableKey], completionHandler: { [weak self] in
                guard let self = self else { return }
                
                var error: NSError? = nil
                let status = pendingAsset.statusOfValue(forKey: Constants.assetPlayableKey, error: &error)
                
                DispatchQueue.main.async {
                    if (pendingAsset != self.pendingAsset) { return; }
                    switch status {
                    case .loaded:
                        let item = AVPlayerItem(
                            asset: pendingAsset,
                            automaticallyLoadedAssetKeys: [Constants.assetPlayableKey]
                        )
                        item.preferredForwardBufferDuration = self.bufferDuration
                        self.avPlayer.replaceCurrentItem(with: item)
                        self.startObservingAVPlayer(item: item)
                        
                        if pendingAsset.availableChapterLocales.count > 0 {
                            for locale in pendingAsset.availableChapterLocales {
                                let chapters = pendingAsset.chapterMetadataGroups(withTitleLocale: locale, containingItemsWithCommonKeys: nil)
                                self.delegate?.AVWrapper(didReceiveMetadata: chapters)
                            }
                        } else {
                            for format in pendingAsset.availableMetadataFormats {
                                let timeRange = CMTimeRange(start: CMTime(seconds: 0, preferredTimescale: 1000), end: pendingAsset.duration)
                                let group = AVTimedMetadataGroup(items: pendingAsset.metadata(forFormat: format), timeRange: timeRange)
                                self.delegate?.AVWrapper(didReceiveMetadata: [group])
                            }
                        }

                        if let initialTime = self.timeToSeekToAfterLoading {
                            self.timeToSeekToAfterLoading = nil
                            self.seek(to: initialTime)
                        }

                        break
                        
                    case .failed:
                        self.reset()
                        self.delegate?.AVWrapper(failedWithError: error)
                        break
                        
                    case .cancelled:
                        break
                        
                    default:
                        break
                    }
                }
            })
        }
    }
    
    func load(from url: URL, playWhenReady: Bool, initialTime: TimeInterval? = nil, options: [String : Any]? = nil) {
        self.playWhenReady = playWhenReady
        self.load(from: url, playWhenReady: playWhenReady, options: options)
        if let initialTime = initialTime {
            self.seek(to: initialTime)
        }
    }
    
    // MARK: - Util
    
    func reset() {
        stopObservingAVPlayer()
        
        pendingAsset?.cancelLoading()
        pendingAsset = nil
        
        avPlayer.replaceCurrentItem(with: nil)
        state = .idle
    }
    
    private func startObservingAVPlayer(item: AVPlayerItem) {
        playerObserver.startObserving()

        playerTimeObserver.registerForBoundaryTimeEvents()
        playerItemObserver.startObserving(item: item)
        playerItemNotificationObserver.startObserving(item: item)
    }

    private func stopObservingAVPlayer() {
        playerObserver.stopObserving()

        playerTimeObserver.unregisterForBoundaryTimeEvents()
        playerItemObserver.stopObservingCurrentItem()
        playerItemNotificationObserver.stopObservingCurrentItem()
    }
    
    private func recreateAVPlayer() {
        stopObservingAVPlayer()
        avPlayer = AVPlayer();
        setupAVPlayer()
        delegate?.AVWrapperDidRecreateAVPlayer()
    }
    
    private func setupAVPlayer() {
        // disabled since we're not making use of video playback
        avPlayer.allowsExternalPlayback = false;

        playerObserver.player = avPlayer
        playerTimeObserver.player = avPlayer
        playerTimeObserver.registerForPeriodicTimeEvents()
        applyAVPlayerRate()
    }
    
    private func applyAVPlayerRate() {
        avPlayer.rate = playWhenReady ? _rate : 0
    }
}

extension AVPlayerWrapper: AVPlayerObserverDelegate {
    
    // MARK: - AVPlayerObserverDelegate
    
    func player(didChangeTimeControlStatus status: AVPlayer.TimeControlStatus) {
        lastPlayerTimeControlStatus = status;
    }
    
    func player(statusDidChange status: AVPlayer.Status) {
        switch status {
            case .failed:
                delegate?.AVWrapper(failedWithError: avPlayer.error)
                break
                
            case .unknown:
                break

            @unknown default:
                break
        }
    }
}

extension AVPlayerWrapper: AVPlayerTimeObserverDelegate {
    
    // MARK: - AVPlayerTimeObserverDelegate
    
    func audioDidStart() {
        state = .playing
    }
    
    func timeEvent(time: CMTime) {
        delegate?.AVWrapper(secondsElapsed: time.seconds)
    }
    
}

extension AVPlayerWrapper: AVPlayerItemNotificationObserverDelegate {
    
    // MARK: - AVPlayerItemNotificationObserverDelegate
    
    func itemDidPlayToEndTime() {
        delegate?.AVWrapperItemDidPlayToEndTime()
    }
    
}

extension AVPlayerWrapper: AVPlayerItemObserverDelegate {
    func item(didUpdatePlaybackLikelyToKeepUp playbackLikelyToKeepUp: Bool) {
        if (playbackLikelyToKeepUp) {
            state = .ready
        }
    }
    
    // MARK: - AVPlayerItemObserverDelegate
    
    func item(didUpdateDuration duration: Double) {
        delegate?.AVWrapper(didUpdateDuration: duration)
    }
    
    func item(didReceiveMetadata metadata: [AVTimedMetadataGroup]) {
        delegate?.AVWrapper(didReceiveMetadata: metadata)
    }
    
}
