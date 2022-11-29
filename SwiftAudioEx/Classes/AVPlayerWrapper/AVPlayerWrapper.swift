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

    fileprivate var initialTime: TimeInterval?
    fileprivate var pendingAsset: AVAsset? = nil

    /// True when the track was paused for the purpose of switching tracks
    fileprivate var pausedForLoad: Bool = false

    // We need to track this ourselves, in addition to avPlayer having its rate,
    // because any call to avPlayer.play() resets its playback rate to 0!
    fileprivate var playRate: Float = 1.0

    public init() {
        playerTimeObserver = AVPlayerTimeObserver(periodicObserverTimeInterval: timeEventFrequency.getTime())
        playerTimeObserver.player = avPlayer

        playerObserver.player = avPlayer
        playerObserver.delegate = self
        playerTimeObserver.delegate = self
        playerItemNotificationObserver.delegate = self
        playerItemObserver.delegate = self

        // disabled since we're not making use of video playback
        avPlayer.allowsExternalPlayback = false;

        playerTimeObserver.registerForPeriodicTimeEvents()
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
                        }
                        else if currentItem != nil && pausedForLoad != true {
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
     True if the last call to load(from:playWhenReady) had playWhenReady=true.
     */
    fileprivate(set) var playWhenReady: Bool = true

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

    var rate: Float {
        get { playRate }
        set {
          playRate = newValue
          avPlayer.rate = newValue
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

        // You might be tempted to avPlayer.play() here, but that essentially
        // sets the rate to 1.0 (https://stackoverflow.com/questions/8688872/).
        // What you really want to do is to restore the previous play rate.
        // Bug tracked in #36.
        avPlayer.rate = playRate
    }

    func pause() {
        playWhenReady = false
        avPlayer.pause()
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
        pause()
        reset(soft: false)
    }

    func seek(to seconds: TimeInterval) {
       // if the player is loading then we need to defer seeking until it's ready.
       if (state == AVPlayerWrapperState.loading) {
         initialTime = seconds
       } else {
         avPlayer.seek(to: CMTimeMakeWithSeconds(seconds, preferredTimescale: 1000)) { (finished) in
             if let _ = self.initialTime {
                 self.initialTime = nil
                 if self.playWhenReady {
                     self.play()
                 }
             }
             self.delegate?.AVWrapper(seekTo: Int(seconds), didFinish: finished)
         }
       }
     }



    func load(from url: URL, playWhenReady: Bool, options: [String: Any]? = nil) {
        reset(soft: true)
        self.playWhenReady = playWhenReady

        if currentItem?.status == .failed {
            recreateAVPlayer()
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
                        // Register for events
                        self.playerTimeObserver.registerForBoundaryTimeEvents()
                        self.playerObserver.startObserving()
                        self.playerItemNotificationObserver.startObserving(item: item)
                        self.playerItemObserver.startObserving(item: item)

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
                        break

                    case .failed:
                        self.reset(soft: false)
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
        self.initialTime = initialTime

        pausedForLoad = true
        pause()

        self.load(from: url, playWhenReady: playWhenReady, options: options)
    }

    // MARK: - Util

    private func reset(soft: Bool) {
        playerItemObserver.stopObservingCurrentItem()
        playerTimeObserver.unregisterForBoundaryTimeEvents()
        playerItemNotificationObserver.stopObservingCurrentItem()

        pendingAsset?.cancelLoading()
        pendingAsset = nil

        if !soft {
            avPlayer.replaceCurrentItem(with: nil)
        }
    }

    /// Will recreate the AVPlayer instance. Used when the current one fails.
    private func recreateAVPlayer() {
        let player = AVPlayer()
        playerObserver.player = player
        playerTimeObserver.player = player
        playerTimeObserver.registerForPeriodicTimeEvents()
        avPlayer = player
        delegate?.AVWrapperDidRecreateAVPlayer()
    }

}

extension AVPlayerWrapper: AVPlayerObserverDelegate {

    // MARK: - AVPlayerObserverDelegate

    func player(didChangeTimeControlStatus status: AVPlayer.TimeControlStatus) {
        lastPlayerTimeControlStatus = status;
    }

    func player(statusDidChange status: AVPlayer.Status) {
        switch status {
        case .readyToPlay:
            state = .ready
            pausedForLoad = false
            if playWhenReady && (initialTime ?? 0) == 0 {
                play()
            }
            else if let initialTime = initialTime {
                seek(to: initialTime)
            }
            break

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

    // MARK: - AVPlayerItemObserverDelegate

    func item(didUpdateDuration duration: Double) {
        delegate?.AVWrapper(didUpdateDuration: duration)
    }

    func item(didReceiveMetadata metadata: [AVTimedMetadataGroup]) {
        delegate?.AVWrapper(didReceiveMetadata: metadata)
    }

}
