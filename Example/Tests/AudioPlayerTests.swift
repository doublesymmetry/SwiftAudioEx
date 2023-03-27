import Quick
import Nimble
import Foundation

@testable import SwiftAudioEx

class AudioPlayerTests: QuickSpec {
    override func spec() {
        beforeSuite {
            Nimble.AsyncDefaults.timeout = .seconds(10)
            Nimble.AsyncDefaults.pollInterval = .milliseconds(100)
        }
        describe("AudioPlayer") {
            var audioPlayer: AudioPlayer!
            var listener: AudioPlayerEventListener!
            var playerStateEventListener: QueuedAudioPlayer.PlayerStateEventListener!
            beforeEach {
                audioPlayer = AudioPlayer()
                audioPlayer.volume = 0.0
                listener = AudioPlayerEventListener(audioPlayer: audioPlayer)
                playerStateEventListener = QueuedAudioPlayer.PlayerStateEventListener()
                audioPlayer.event.stateChange.addListener(
                    playerStateEventListener,
                    playerStateEventListener.handleEvent
                )
            }
            
            afterEach {
                audioPlayer = nil
                listener = nil
            }
            
            // MARK: - Load
            context("when loading audio item") {
                it("should never mutate playWhenReady to false") {
                    audioPlayer.playWhenReady = true
                    audioPlayer.load(item: Source.getAudioItem())
                    expect(audioPlayer.playWhenReady).to(beTrue())
                }
                
                it("should never mutate playWhenReady to true") {
                    audioPlayer.playWhenReady = false
                    audioPlayer.load(item: Source.getAudioItem())
                    expect(audioPlayer.playWhenReady).to(beFalse())
                }
                
                it("should mutate playWhenReady when loading with playWhenReady equals true") {
                    audioPlayer.playWhenReady = true
                    expect(audioPlayer.playWhenReady).to(beTrue())
                    audioPlayer.load(item: Source.getAudioItem(), playWhenReady: false)
                    expect(audioPlayer.playWhenReady).to(beFalse())
                }
                
                it("should mutate playWhenReady when loading with playWhenReady equals false") {
                    audioPlayer.playWhenReady = false
                    audioPlayer.load(item: Source.getAudioItem(), playWhenReady: true)
                    expect(audioPlayer.playWhenReady).to(beTrue())
                }
                
                it("should seek when audio item sets initial time") {
                    var seekCompleted = false
                    listener.onSeekCompletion = {
                        seekCompleted = true
                    }
                    audioPlayer.playWhenReady = false
                    expect(audioPlayer.playWhenReady).to(beFalse())
                    audioPlayer.load(item: FiveSecondSourceWithInitialTimeOfFourSeconds.getAudioItem())
                    expect(seekCompleted).toEventually(beTrue())
                    expect(audioPlayer?.currentTime ?? 0).to(beGreaterThanOrEqualTo(4))
                }
            }
            
            // MARK: - Duration
            context("when dealing with duration") {
                it("should set duration eventually after loading") {
                    audioPlayer.load(item: FiveSecondSource.getAudioItem())
                    expect(audioPlayer.duration).toEventually(equal(5))
                }

                it("audioPlayer.event.updateDuration should receive duration after loading") {
                    var receivedUpdateDuration = false
                    listener.onUpdateDuration = { duration in
                        receivedUpdateDuration = true
                        expect(duration).to(equal(5))
                    }
                    audioPlayer.load(item: FiveSecondSource.getAudioItem())
                    expect(receivedUpdateDuration).toEventually(beTrue())
                }
                
                it("should reset duration after loading again") {
                    audioPlayer.load(item: FiveSecondSource.getAudioItem())
                    expect(audioPlayer.duration).to(equal(0))
                    expect(audioPlayer.duration).toEventually(equal(5))
                    audioPlayer.load(item: FiveSecondSource.getAudioItem())
                    expect(audioPlayer.duration).to(equal(0))
                    expect(audioPlayer.duration).toEventually(equal(5))
                }
                
                it("should reset duration after reset") {
                    audioPlayer.load(item: FiveSecondSource.getAudioItem())
                    expect(audioPlayer.duration).to(equal(0))
                    expect(audioPlayer.duration).toEventually(equal(5))
                    audioPlayer.clear()
                    expect(audioPlayer.duration).to(equal(0))
                }
            }

            // MARK: - Failure
            context("when handling failure") {
                it("should emit fail event on load with non-malformed URL") {
                    var didReceiveFail = false
                    listener.onReceiveFail = { error in
                        didReceiveFail = true
                    }
                    
                    let item = DefaultAudioItem(
                        audioUrl: "", // malformed url
                        artist: "Artist",
                        title: "Title",
                        albumTitle: "AlbumTitle",
                        sourceType: .stream
                    )
                    audioPlayer.load(item: item, playWhenReady: true)
                    expect(audioPlayer.playbackError).toNot(beNil())
                    expect(audioPlayer.playerState).to(equal(.failed))
                    expect(didReceiveFail).to(beTrue())
                }
                
                it("should emit fail event on load with non-existing resource") {
                    var didReceiveFail = false
                    listener.onReceiveFail = { error in
                        didReceiveFail = true
                    }
                    
                    let nonExistingUrl = "https://\(String.random(length: 100)).com/\(String.random(length: 100)).mp3"
                    let item = DefaultAudioItem(audioUrl: nonExistingUrl, artist: "Artist", title: "Title", albumTitle: "AlbumTitle", sourceType: .stream)
                    audioPlayer.load(item: item, playWhenReady: true)
                    expect(audioPlayer.playbackError).toEventuallyNot(beNil())
                    expect(audioPlayer.playerState).to(equal(.failed))
                    expect(didReceiveFail).to(beTrue())
                }
                
                context("calling play after failure") {
                    it("should retry loading") {
                        let nonExistingUrl = "https://\(String.random(length: 100)).com/\(String.random(length: 100)).mp3";
                        let item = DefaultAudioItem(
                            audioUrl: nonExistingUrl,
                            artist: "Artist",
                            title: "Title",
                            albumTitle: "AlbumTitle",
                            sourceType: .stream
                        );
                        audioPlayer.load(item: item, playWhenReady: true)
                        expect(playerStateEventListener.statesWithoutBuffering).toEventually(equal([.loading, .failed]))
                        audioPlayer.play()
                        expect(playerStateEventListener.statesWithoutBuffering).toEventually(equal([.loading, .failed, .loading, .failed]))
                    }
                }

                context("setting playWhenReady after failure") {
                    it("should retry loading") {
                        let nonExistingUrl = "https://\(String.random(length: 100)).com/\(String.random(length: 100)).mp3";
                        let item = DefaultAudioItem(
                            audioUrl: nonExistingUrl,
                            artist: "Artist",
                            title: "Title",
                            albumTitle: "AlbumTitle",
                            sourceType: .stream
                        );
                        audioPlayer.load(item: item, playWhenReady: true)
                        expect(playerStateEventListener.statesWithoutBuffering).toEventually(equal([.loading, .failed]))
                        audioPlayer.playWhenReady = true
                        expect(playerStateEventListener.statesWithoutBuffering).toEventually(equal([ .loading, .failed, .loading, .failed]))
                    }
                }

                context("calling reload after failure") {
                    it("should retry loading but fail again with same broken source") {
                        let nonExistingUrl = "https://\(String.random(length: 100)).com/\(String.random(length: 100)).mp3";
                        let item = DefaultAudioItem(
                            audioUrl: nonExistingUrl,
                            artist: "Artist",
                            title: "Title",
                            albumTitle: "AlbumTitle",
                            sourceType: .stream
                        );
                        audioPlayer.load(item: item, playWhenReady: true)
                        expect(playerStateEventListener.statesWithoutBuffering).toEventually(equal([.loading, .failed]))

                        audioPlayer.reload(startFromCurrentTime: true)
                        expect(playerStateEventListener.statesWithoutBuffering).toEventually(equal([.loading, .failed, .loading, .failed]))
                    }
                }

                context("load resource") {
                    it("should succeed after previous failure") {
                        var didReceiveFail = false;
                        listener.onReceiveFail = { error in
                            didReceiveFail = true;
                        }
 
                        let nonExistingUrl = "https://\(String.random(length: 100)).com/\(String.random(length: 100)).mp3";
                        let failItem = DefaultAudioItem(audioUrl: nonExistingUrl, artist: "Artist", title: "Title", albumTitle: "AlbumTitle", sourceType: .stream);
                        audioPlayer.load(item: failItem, playWhenReady: false)
                        expect(didReceiveFail).toEventually(beTrue())
                        expect(audioPlayer.playerState).toEventually(equal(.failed))
                        expect(playerStateEventListener.states).toEventually(equal([.loading, .failed]))

                        audioPlayer.load(item: Source.getAudioItem(), playWhenReady: true)
                        expect(audioPlayer.playbackError).to(beNil())
                        expect(playerStateEventListener.statesWithoutBuffering)
                            .toEventually(equal([.loading, .failed, .loading, .playing]))
                    }

                    it("with playWhenReady=false it should succeed after previous failure") {
                        var didReceiveFail = false;
                        listener.onReceiveFail = { error in
                            didReceiveFail = true;
                        }
                        let nonExistingUrl = "https://\(String.random(length: 100)).com/\(String.random(length: 100)).mp3";
                        let item = DefaultAudioItem(audioUrl: nonExistingUrl, artist: "Artist", title: "Title", albumTitle: "AlbumTitle", sourceType: .stream);
                        audioPlayer.load(item: item, playWhenReady: true)
                        expect(didReceiveFail).toEventually(beTrue())
                        expect(audioPlayer.playerState).toEventually(equal(.failed))

                        audioPlayer.load(item: Source.getAudioItem(), playWhenReady: true)
                        expect(audioPlayer.playbackError).to(beNil())
                    }
                }
            }
            // MARK: - States
            context("states") {
                it("should initially be idle") {
                    expect(audioPlayer.playerState).to(equal(.idle))
                }
                
                it("should be loading after load source") {
                    audioPlayer.load(item: Source.getAudioItem(), playWhenReady: false)
                    expect(audioPlayer.playerState).to(equal(.loading))
                }
                
                it("should become ready after load source") {
                    audioPlayer.load(item: Source.getAudioItem(), playWhenReady: false)
                    expect(audioPlayer.playerState).toEventually(equal(.ready))
                }
                
                it("should be playing after load source with playWhenReady") {
                    audioPlayer.load(item: Source.getAudioItem(), playWhenReady: true)
                    expect(audioPlayer.playerState).toEventually(equal(.playing))
                }
                it("should emit events in reliable order") {
                    audioPlayer.load(item: Source.getAudioItem(), playWhenReady: true)
                    var expectedEvents : [AVPlayerWrapperState] = [.loading, .playing]
                    expect(playerStateEventListener.statesWithoutBuffering).toEventually(equal(expectedEvents))
                    audioPlayer.pause()
                    expectedEvents.append(.paused)
                    expect(playerStateEventListener.statesWithoutBuffering).toEventually(equal(expectedEvents))
                    expectedEvents.append(.playing)
                    audioPlayer.play()
                    expect(playerStateEventListener.statesWithoutBuffering).toEventually(equal(expectedEvents))
                    audioPlayer.clear()
                    expectedEvents.append(.idle)
                    expect(playerStateEventListener.statesWithoutBuffering).toEventually(equal(expectedEvents))
                }
                it("should update playWhenReady after external pause") {
                    audioPlayer.load(item: Source.getAudioItem(), playWhenReady: true)
                    var expectedEvents : [AVPlayerWrapperState] = [.loading, .playing];
                    expect(playerStateEventListener.statesWithoutBuffering).toEventually(equal(expectedEvents))
                    expect(audioPlayer.currentTime).toEventually(beGreaterThan(0.0))

                    // Simulate avplayer becoming paused due to external reason:
                    audioPlayer.wrapper.rate = 0

                    expectedEvents.append(.paused);
                    expect(playerStateEventListener.statesWithoutBuffering).toEventually(equal(expectedEvents))
                    expect(audioPlayer.playWhenReady).to(beFalse())
                }

                it("should emit events in reliable order at end call stop") {
                    audioPlayer.load(item: Source.getAudioItem(), playWhenReady: true)
                    var expectedEvents : [AVPlayerWrapperState] = [.loading, .playing]
                    expect(playerStateEventListener.statesWithoutBuffering).toEventually(equal(expectedEvents))

                    audioPlayer.pause()
                    expectedEvents.append(.paused)
                    expect(playerStateEventListener.statesWithoutBuffering).toEventually(equal(expectedEvents))

                    expectedEvents.append(.playing)
                    audioPlayer.play()
                    expect(playerStateEventListener.statesWithoutBuffering).toEventually(equal(expectedEvents))

                    audioPlayer.stop()
                    expectedEvents.append(.stopped)
                    expect(playerStateEventListener.statesWithoutBuffering).toEventually(equal(expectedEvents))
                }
                
                it("should emit events in reliable order also after loading after reset") {
                    audioPlayer.load(item: Source.getAudioItem(), playWhenReady: true)
                    var expectedEvents : [AVPlayerWrapperState] = [.loading, .playing]
                    expect(playerStateEventListener.statesWithoutBuffering).toEventually(equal(expectedEvents))

                    audioPlayer.clear()
                    expectedEvents.append(.idle)
                    expect(playerStateEventListener.statesWithoutBuffering).toEventually(equal(expectedEvents))

                    audioPlayer.load(item: Source.getAudioItem())
                    expectedEvents.append(contentsOf: [.loading, .playing])
                    expect(playerStateEventListener.statesWithoutBuffering).toEventually(equal(expectedEvents))
                }

                it("should be playing after calling play()") {
                    audioPlayer.load(item: Source.getAudioItem(), playWhenReady: false)
                    expect(audioPlayer.playerState).toEventually(equal(.ready))
                    audioPlayer.play()
                    expect(audioPlayer.playerState).toEventually(equal(.playing))
                }

                it("should be paused after calling pause()") {
                    audioPlayer.load(item: Source.getAudioItem(), playWhenReady: true)
                    expect(audioPlayer.playerState).toEventually(equal(.playing))
                    audioPlayer.pause()
                    expect(audioPlayer.playerState).toEventually(equal(.paused))
                }

                it("should be paused after setting playWhenReady to false") {
                    audioPlayer.load(item: Source.getAudioItem(), playWhenReady: true)
                    expect(audioPlayer.playerState).toEventually(equal(.playing))
                    audioPlayer.playWhenReady = false
                    expect(audioPlayer.playerState).toEventually(equal(.paused))
                }

                it("should be playing after setting playWhenReady to true") {
                    audioPlayer.load(item: Source.getAudioItem(), playWhenReady: false)
                    expect(audioPlayer.playerState).toEventually(equal(.ready))
                    audioPlayer.playWhenReady = true
                    expect(audioPlayer.playerState).toEventually(equal(.playing))
                }

                it("should be stopped after stop") {
                    audioPlayer.load(item: Source.getAudioItem(), playWhenReady: true)
                    expect(audioPlayer.playerState).toEventually(equal(.playing))
                    audioPlayer.stop()
                    expect(audioPlayer.playerState).toEventually(equal(.stopped))
                }
            }
            // MARK: - States
            context("current time") {
                it("should be 0 initially") {
                    expect(audioPlayer.currentTime).to(equal(0.0))
                }

                it("audioPlayer.event.secondElapse should be emitted when playing") {
                    var onSecondsElapseTime = 0.0
                    audioPlayer.timeEventFrequency = .everyQuarterSecond
                    listener.onSecondsElapse = { time in
                        onSecondsElapseTime = time
                    }
                    audioPlayer.load(item: LongSource.getAudioItem(), playWhenReady: true)
                    expect(onSecondsElapseTime).toEventually(beGreaterThan(0))
                }
            }

            // MARK: - Buffer
            context("buffer") {
                it("automaticallyWaitsToMinimizeStalling should be true") {
                    expect(audioPlayer.automaticallyWaitsToMinimizeStalling).to(beTrue())
                }
                it("bufferDuration should be zero") {
                    expect(audioPlayer.bufferDuration).to(equal(0))
                }
                it("setting bufferDuration disables automaticallyWaitsToMinimizeStalling") {
                    audioPlayer.bufferDuration = 1;
                    expect(audioPlayer.bufferDuration).to(equal(1))
                    expect(audioPlayer.automaticallyWaitsToMinimizeStalling).to(beFalse())
                }
                it("enabling automaticallyWaitsToMinimizeStalling sets bufferDuration to zero") {
                    audioPlayer.automaticallyWaitsToMinimizeStalling = true
                    expect(audioPlayer.bufferDuration).to(equal(0))
                }
            }
            
            // MARK: - Seek
            context("Seek") {
                it("Seeking should work before loading is complete") {
                    let player = audioPlayer
                    player!.load(item: FiveSecondSource.getAudioItem(), playWhenReady: true)
                    player!.seek(to: 4.75)
                    expect(audioPlayer.currentTime).toEventually(beGreaterThan(4.75))
                }
                it("Seeking should work after loading is complete") {
                    audioPlayer.load(item: FiveSecondSource.getAudioItem(), playWhenReady: true)
                    audioPlayer.seek(to: 4.75)
                    expect(audioPlayer.currentTime).toEventually(beGreaterThan(4.75))
                }
                it("Seeking should work when paused") {
                    audioPlayer.load(item: FiveSecondSource.getAudioItem(), playWhenReady: false)
                    audioPlayer.seek(to: 4.75)
                    expect(audioPlayer.currentTime).toEventually(equal(4.75))
                }
                it("Seeking can not change currentTime when stopped") {
                    audioPlayer.load(item: FiveSecondSource.getAudioItem(), playWhenReady: false)
                    audioPlayer.stop()
                    audioPlayer.seek(to: 4.75)
                    expect(audioPlayer.currentTime).toNotEventually(equal(4.75))
                    expect(audioPlayer.currentTime).to(equal(0))
                }
            }
            // MARK: - Rate
            context("Rate") {
                it("should be 1 initially") {
                    expect(audioPlayer.rate).to(equal(1))
                }
                it("should speed up playback when setting to more than 1") {
                    var start: Date? = nil;
                    var end: Date? = nil;

                    listener.onPlaybackEnd = { reason in
                        if (reason == .playedUntilEnd) {
                            end = Date()
                        }
                    }

                    listener.onStateChange = { state in
                        switch state {
                        case .playing:
                            if (start == nil) {
                                start = Date()
                            }
                        default: break
                        }
                    }
                    audioPlayer.load(item: FiveSecondSource.getAudioItem(), playWhenReady: true)
                    audioPlayer.rate = 10
                    expect(audioPlayer.playerState).toEventually(equal(.ended))
                    if let start = start, let end = end {
                        let duration = end.timeIntervalSince(start);
                        expect(duration).to(beLessThan(1))
                    }
                }

                it("should slow down playback when setting to less than 1") {
                    var start: Date? = nil;
                    var end: Date? = nil;

                    listener.onPlaybackEnd = { reason in
                        if (reason == .playedUntilEnd) {
                            end = Date()
                        }
                    }

                    audioPlayer.rate = 0.5
                    audioPlayer.load(item: FiveSecondSource.getAudioItem(), playWhenReady: true)
                    listener.onStateChange = { state in
                        switch state {
                        case .playing:
                            if (start == nil) {
                                start = Date()
                            }
                        default: break
                        }
                    }
                    audioPlayer.seek(to: 4.75)
                    expect(audioPlayer.playerState).toEventually(equal(.ended))
                    if let start = start, let end = end {
                        let duration = end.timeIntervalSince(start);
                        expect(duration).to(beLessThanOrEqualTo(1))
                    }
                }
            }
            // MARK: - Current Item
            context("Current Item") {
                it("should be nil initially") {
                    expect(audioPlayer.currentItem).to(beNil())
                }
                it("should not be nil after loading") {
                    audioPlayer.load(item: Source.getAudioItem(), playWhenReady: false)
                    expect(audioPlayer.currentItem?.getSourceUrl()).to(equal(Source.getAudioItem().getSourceUrl()))
                }
            }
        }
    }
}

class PlayerStateEventListener {
    private let lockQueue = DispatchQueue(
        label: "PlayerStateEventListener.lockQueue",
        target: .global()
    )
    var _states: [AudioPlayerState] = []
    var states: [AudioPlayerState] {
        get {
            return lockQueue.sync {
                return _states
            }
        }

        set {
            lockQueue.sync {
                _states = newValue
            }
        }
    }
    private var _statesWithoutBuffering: [AudioPlayerState] = []
    var statesWithoutBuffering: [AudioPlayerState] {
        get {
            return lockQueue.sync {
                return _statesWithoutBuffering
            }
        }

        set {
            lockQueue.sync {
                _statesWithoutBuffering = newValue
            }
        }
    }
    func handleEvent(state: AudioPlayerState) {
        states.append(state)
        if (state != .ready && state != .buffering && (statesWithoutBuffering.isEmpty || statesWithoutBuffering.last != state)) {
            statesWithoutBuffering.append(state)
        }
    }
}

class AudioPlayerEventListener {

    var state: AudioPlayerState?

    var onStateChange: ((_ state: AudioPlayerState) -> Void)?
    var onSecondsElapse: ((_ seconds: TimeInterval) -> Void)?
    var onSeekCompletion: (() -> Void)?
    var onReceiveFail: ((_ error: Error?) -> Void)?
    var onPlaybackEnd: ((_: AudioPlayer.PlaybackEndEventData) -> Void)?
    var onUpdateDuration: ((_: AudioPlayer.UpdateDurationEventData) -> Void)?

    weak var audioPlayer: AudioPlayer?

    init(audioPlayer: AudioPlayer) {
        audioPlayer.event.updateDuration.addListener(self, handleUpdateDuration)
        audioPlayer.event.stateChange.addListener(self, handleStateChange)
        audioPlayer.event.seek.addListener(self, handleSeek)
        audioPlayer.event.secondElapse.addListener(self, handleSecondsElapse)
        audioPlayer.event.fail.addListener(self, handleFail)
        audioPlayer.event.playbackEnd.addListener(self, handlePlaybackEnd)
    }

    deinit {
        audioPlayer?.event.stateChange.removeListener(self)
        audioPlayer?.event.seek.removeListener(self)
        audioPlayer?.event.secondElapse.removeListener(self)
    }

    func handleStateChange(state: AudioPlayerState) {
        self.state = state
        onStateChange?(state)
    }

    func handleSeek(data: AudioPlayer.SeekEventData) {
        onSeekCompletion?()
    }

    func handleSecondsElapse(data: AudioPlayer.SecondElapseEventData) {
        self.onSecondsElapse?(data)
    }

    func handleFail(error: Error?) {
        self.onReceiveFail?(error)
    }

    func handlePlaybackEnd(_ data: AudioPlayer.PlaybackEndEventData) {
        self.onPlaybackEnd?(data)
    }

    func handleUpdateDuration(_ data: AudioPlayer.UpdateDurationEventData) {
        self.onUpdateDuration?(data)
    }
}

extension String {
    static func random(length: Int = 20) -> String {
        let base = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        var randomString: String = ""

        for _ in 0..<length {
            let randomValue = arc4random_uniform(UInt32(base.count))
            randomString += "\(base[base.index(base.startIndex, offsetBy: Int(randomValue))])"
        }
        return randomString
    }
}
