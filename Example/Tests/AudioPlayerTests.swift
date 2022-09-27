import Quick
import Nimble
import AVFoundation
import XCTest

@testable import SwiftAudioEx

class AudioPlayerTests: XCTestCase {
    
    var audioPlayer: AudioPlayer!
    var listener: AudioPlayerEventListener!
    
    override func setUp() {
        super.setUp()
        audioPlayer = AudioPlayer()
        audioPlayer.volume = 0.0
        listener = AudioPlayerEventListener(audioPlayer: audioPlayer)
    }
    
    override func tearDown() {
        audioPlayer = nil
        listener = nil
        super.tearDown()
    }

    // MARK: - Load
    func test_AudioPlayer__load__load_source_without_playWhenReady__should_never_mutate_playWhenReady_to_false() {
        audioPlayer.playWhenReady = true
        audioPlayer.load(item: Source.getAudioItem())
        XCTAssertTrue(audioPlayer.playWhenReady)
    }

    func test_AudioPlayer__load__load_source_without_playWhenReady__should_never_mutate_playWhenReady_to_true() {
        audioPlayer.playWhenReady = false
        audioPlayer.load(item: Source.getAudioItem())
        XCTAssertFalse(audioPlayer.playWhenReady)
    }
    
    func test_AudioPlayer__load__load_source_with_playWhenReady_equals_true__should_mutate_playWhenReady() {
        audioPlayer.playWhenReady = true
        XCTAssertTrue(audioPlayer.playWhenReady)
        audioPlayer.load(item: Source.getAudioItem(), playWhenReady: false)
        XCTAssertFalse(audioPlayer.playWhenReady)
    }

    func test_AudioPlayer__load__load_source_with_playWhenReady_equals_false__should_mutate_playWhenReady() {
        audioPlayer.playWhenReady = false
        XCTAssertFalse(audioPlayer.playWhenReady)
        audioPlayer.load(item: Source.getAudioItem(), playWhenReady: true)
        XCTAssertTrue(audioPlayer.playWhenReady)
    }

    func test_AudioPlayer__load__should_seek_when_audio_item_sets_initial_time() {
        let seekCompletionExpectation = XCTestExpectation()
        audioPlayer.playWhenReady = false
        XCTAssertFalse(audioPlayer.playWhenReady)
        audioPlayer.load(item: FiveSecondSourceWithInitialTimeOfFourSeconds.getAudioItem())
        listener.onSeekCompletion = { [weak audioPlayer] in
            XCTAssert((audioPlayer?.currentTime ?? 0) >= 4)
            seekCompletionExpectation.fulfill()
        }
        wait(for: [seekCompletionExpectation], timeout: 20.0)
    }
    
    // MARK: - Duration
    func test_AudioPlayer__duration_should_set_duration_after_loading() {
        let durationExpectation = XCTestExpectation()
        listener.onUpdateDuration = { duration in
            XCTAssertEqual(5, duration)
            durationExpectation.fulfill()
        }
        audioPlayer.load(item: FiveSecondSource.getAudioItem())
        XCTAssertEqual(0, audioPlayer.duration)
        wait(for: [durationExpectation], timeout: 20.0)
        XCTAssertEqual(5, audioPlayer.duration)
    }

    func test_AudioPlayer__duration_should_reset_duration_after_loading_again() {
        var durationExpectation = XCTestExpectation()
        listener.onUpdateDuration = { duration in
            XCTAssertEqual(5, duration)
            durationExpectation.fulfill()
        }
        audioPlayer.load(item: FiveSecondSource.getAudioItem())
        XCTAssertEqual(0, audioPlayer.duration)
        wait(for: [durationExpectation], timeout: 20.0)
        durationExpectation = XCTestExpectation()
        XCTAssertEqual(5, audioPlayer.duration)
        audioPlayer.load(item: FiveSecondSource.getAudioItem())
        XCTAssertEqual(0, audioPlayer.duration)
        wait(for: [durationExpectation], timeout: 20.0)
    }

    func test_AudioPlayer__duration_should_reset_duration_after_reset() {
        var durationExpectation = XCTestExpectation()
        listener.onUpdateDuration = { duration in
            XCTAssertEqual(5, duration)
            durationExpectation.fulfill()
        }
        audioPlayer.load(item: FiveSecondSource.getAudioItem())
        XCTAssertEqual(0, audioPlayer.duration)
        wait(for: [durationExpectation], timeout: 20.0)
        durationExpectation = XCTestExpectation()
        XCTAssertEqual(5, audioPlayer.duration)
        audioPlayer.reset()
        XCTAssertEqual(0, audioPlayer.duration)
    }
    
    // MARK: - Failure

    func test_AudioPlayer__failure__load_non_malformed_url__should_emit_fail_event() {
        let didFailExpectation = XCTestExpectation()
        var didReceiveFail = false;

        listener.onReceiveFail = { error in
            didReceiveFail = true;
        }

        listener.onStateChange = { state in
            switch state {
            case .failed: didFailExpectation.fulfill()
            default: break
            }
        }

        let item = DefaultAudioItem(
            audioUrl: "", // malformed url
            artist: "Artist",
            title: "Title",
            albumTitle: "AlbumTitle",
            sourceType: .stream
        );
        audioPlayer.load(item: item, playWhenReady: true)
        eventually {
            XCTAssertNotNil(self.audioPlayer.playbackError)
            XCTAssertEqual(self.audioPlayer.playerState, .failed)
            XCTAssertEqual(didReceiveFail, true)
        }
        wait(for: [didFailExpectation], timeout: 20.0)
    }

    func test_AudioPlayer__failure__load_non_existing_resource__should_emit_fail_event() {
        let didFailExpectation = XCTestExpectation()
        var didReceiveFail = false;

        listener.onReceiveFail = { error in
            didReceiveFail = true;
        }

        listener.onStateChange = { state in
            switch state {
            case .failed: didFailExpectation.fulfill()
            default: break
            }
        }
 
        let nonExistingUrl = "https://\(String.random(length: 100)).com/\(String.random(length: 100)).mp3";
        let item = DefaultAudioItem(audioUrl: nonExistingUrl, artist: "Artist", title: "Title", albumTitle: "AlbumTitle", sourceType: .stream);
        audioPlayer.load(item: item, playWhenReady: true)
        eventually {
            XCTAssertNotNil(self.audioPlayer.playbackError)
            XCTAssertEqual(self.audioPlayer.playerState, .failed)
            XCTAssertEqual(didReceiveFail, true)
        }
        wait(for: [didFailExpectation], timeout: 20.0)
    }

    func test_AudioPlayer__failure__load_resource_should_succeeed_after_previous_failure() {
        var didReceiveFail = false;
        listener.onReceiveFail = { error in
            didReceiveFail = true;
        }
        let nonExistingUrl = "https://\(String.random(length: 100)).com/\(String.random(length: 100)).mp3";
        let item = DefaultAudioItem(audioUrl: nonExistingUrl, artist: "Artist", title: "Title", albumTitle: "AlbumTitle", sourceType: .stream);
        audioPlayer.load(item: item, playWhenReady: true)
        eventually {
            XCTAssertEqual(didReceiveFail, true)
            XCTAssertEqual(self.audioPlayer.playerState, .failed)
        }
        let didLoadExpectation = XCTestExpectation()
        listener.onStateChange = { state in
            switch state {
            case .ready: didLoadExpectation.fulfill()
            default: break
            }
        }

        audioPlayer.load(item: Source.getAudioItem(), playWhenReady: false)
        wait(for: [didLoadExpectation], timeout: 20.0)
        XCTAssertNil(self.audioPlayer.playbackError)

    }
    
    // MARK: - State
    
    func test_AudioPlayer__state__should_be_idle() {
        XCTAssert(audioPlayer.playerState == AudioPlayerState.idle)
    }
    
    func test_AudioPlayer__state__load_source__should_be_loading() {
        audioPlayer.load(item: Source.getAudioItem(), playWhenReady: false)
        XCTAssertEqual(audioPlayer.playerState, AudioPlayerState.loading)
    }
    
    func test_AudioPlayer__state__load_source__should_be_ready() {
        let expectation = XCTestExpectation()
        listener.onStateChange = { state in
            switch state {
            case .ready: expectation.fulfill()
            default: break
            }
        }
        audioPlayer.load(item: Source.getAudioItem(), playWhenReady: false)
        wait(for: [expectation], timeout: 20.0)
    }
    
    func test_AudioPlayer__state__load_source_playWhenReady__should_be_playing() {
        let expectation = XCTestExpectation()
        listener.onStateChange = { state in
            switch state {
            case .playing: expectation.fulfill()
            default: break
            }
        }
        audioPlayer.load(item: Source.getAudioItem(), playWhenReady: true)
        wait(for: [expectation], timeout: 20.0)
    }

    func test_AudioPlayer__state__play_source__should_emit_events_in_reliable_order() {
        var events = [audioPlayer.playerState.rawValue == "idle" ? "idle" : "not_idle"]
        listener.onStateChange = { state in
            switch state {
                case .loading: events.append("loading")
                case .ready: events.append("ready")
                // Leaving out bufferring events because they can show up at any point
                case .buffering: break
                case .playing: events.append("playing")
                case .paused: events.append("paused")
                case .idle: events.append("idle")
                case .failed: events.append("failed")
            }
        }
        audioPlayer.load(item: Source.getAudioItem(), playWhenReady: true)
        var expectedEvents = ["idle", "loading", "ready", "playing"];
        eventually {
            XCTAssertEqual(events, expectedEvents)
        }
        audioPlayer.pause()
        expectedEvents.append("paused");
        eventually {
            XCTAssertEqual(events, expectedEvents)
        }
        expectedEvents.append("playing");
        audioPlayer.play()
        eventually {
            XCTAssertEqual(events, expectedEvents)
        }
        audioPlayer.reset()
        expectedEvents.append("idle");
        eventually {
            XCTAssertEqual(events, expectedEvents)
        }
    }

    func test_AudioPlayer__state__play_source__should_emit_events_in_reliable_order_at_end_call_stop() {
        var events = [audioPlayer.playerState.rawValue == "idle" ? "idle" : "not_idle"]
        listener.onStateChange = { state in
            switch state {
                case .loading: events.append("loading")
                case .ready: events.append("ready")
                // Leaving out bufferring events because they can show up at any point
                case .buffering: break
                case .playing: events.append("playing")
                case .paused: events.append("paused")
                case .idle: events.append("idle")
                case .failed: events.append("failed")
            }
        }
        audioPlayer.load(item: Source.getAudioItem(), playWhenReady: true)
        var expectedEvents = ["idle", "loading", "ready", "playing"];
        eventually {
            XCTAssertEqual(events, expectedEvents)
        }
        audioPlayer.pause()
        expectedEvents.append("paused");
        eventually {
            XCTAssertEqual(events, expectedEvents)
        }
        expectedEvents.append(contentsOf: ["playing"]);
        audioPlayer.play()
        eventually {
            XCTAssertEqual(events, expectedEvents)
        }
        audioPlayer.stop()
        expectedEvents.append(contentsOf: ["idle"]);
        eventually {
            XCTAssertEqual(events, expectedEvents)
        }
    }
    
    func test_AudioPlayer__state__play_source__should_emit_events_in_reliable_order_also_after_loading_after_reset() {
        var events = [audioPlayer.playerState.rawValue == "idle" ? "idle" : "not_idle"]
        listener.onStateChange = { state in
            switch state {
                case .loading: events.append("loading")
                case .ready: events.append("ready")
                // Leaving out bufferring events because they are not expected to show up in consistent order
                case .buffering: break
                case .playing: events.append("playing")
                case .paused: events.append("paused")
                case .idle: events.append("idle")
                case .failed: events.append("failed")
            }
        }
        audioPlayer.load(item: Source.getAudioItem(), playWhenReady: true)
        var expectedEvents = ["idle", "loading", "ready", "playing"];
        eventually {
            XCTAssertEqual(events, expectedEvents)
        }
        audioPlayer.reset()
        expectedEvents.append(contentsOf: ["idle"]);
        eventually {
            XCTAssertEqual(events, expectedEvents)
        }
        audioPlayer.load(item: Source.getAudioItem())
        expectedEvents.append(contentsOf: ["loading", "ready", "playing"]);
        eventually {
            XCTAssertEqual(events, expectedEvents)
        }
    }
    
    func test_AudioPlayer__state__play_source__should_be_playing() {
        let expectation = XCTestExpectation()
        listener.onStateChange = { state in
            switch state {
            case .ready: self.audioPlayer.play()
            case .playing: expectation.fulfill()
            default: break
            }
        }
        audioPlayer.load(item: Source.getAudioItem(), playWhenReady: false)
        wait(for: [expectation], timeout: 20.0)
    }
    
    func test_AudioPlayer__state__pausing_source__should_be_paused() {
        let expectation = XCTestExpectation()
        listener.onStateChange = { [weak audioPlayer] state in
            switch state {
            case .playing: audioPlayer?.pause()
            case .paused: expectation.fulfill()
            default: break
            }
        }
        audioPlayer.load(item: Source.getAudioItem(), playWhenReady: true)
        wait(for: [expectation], timeout: 20.0)
    }

    func test_AudioPlayer__state__when_setting_playWhenReady_to_false__should_be_paused() {
        let expectation = XCTestExpectation()
        listener.onStateChange = { [weak audioPlayer] state in
            switch state {
            case .playing:
                audioPlayer?.playWhenReady = false
            case .paused: expectation.fulfill()
            default: break
            }
        }
        audioPlayer.load(item: Source.getAudioItem(), playWhenReady: true)
        wait(for: [expectation], timeout: 20.0)
    }

    func test_AudioPlayer__state__when_setting_playWhenReady_to_true_after_pause__should_be_playing() {
        let wasPausedExpectation = XCTestExpectation()
        listener.onStateChange = { [weak audioPlayer] state in
            switch state {
            case .playing:
                audioPlayer?.playWhenReady = false
            case .paused: wasPausedExpectation.fulfill()
            default: break
            }
        }
        audioPlayer.load(item: Source.getAudioItem(), playWhenReady: true)
        wait(for: [wasPausedExpectation], timeout: 20.0)
        let startedPlayingExpectation = XCTestExpectation()
        listener.onStateChange = { state in
            switch state {
                case .playing:
                    startedPlayingExpectation.fulfill()
                default: break
            }
        }
        audioPlayer.playWhenReady = true
        wait(for: [startedPlayingExpectation], timeout: 20.0)
    }
    
    func test_AudioPlayer__state__stopping_source__should_be_idle() {
        let expectation = XCTestExpectation()
        var hasBeenPlaying: Bool = false
        listener.onStateChange = { [weak audioPlayer] state in
            switch state {
            case .playing:
                hasBeenPlaying = true
                audioPlayer?.stop()
            case .idle:
                if hasBeenPlaying {
                    expectation.fulfill()
                }
            default: break
            }
        }
        audioPlayer.load(item: Source.getAudioItem(), playWhenReady: true)
        wait(for: [expectation], timeout: 20.0)
    }
    
    // MARK: - Current time
    
    func test_AudioPlayer__currentTime__should_be_0() {
        XCTAssert(audioPlayer.currentTime == 0.0)
    }
    
// Commented out -- Keeps failing in CI at Bitrise, but succeeds locally, even with Bitrise CLI.
//    func test_AudioPlayer__currentTime__playing_source__shold_be_greater_than_0() {
//        let expectation = XCTestExpectation()
//        audioPlayer.timeEventFrequency = .everyQuarterSecond
//        listener.secondsElapse = { _ in
//            if self.audioPlayer.currentTime > 0.0 {
//                expectation.fulfill()
//            }
//        }
//        audioPlayer.load(item: LongSource.getAudioItem(), playWhenReady: true)
//        wait(for: [expectation], timeout: 20.0)
//    }
    
    // MARK: - Buffer
    func test_AudioPlayer__buffer__automaticallyWaitsToMinimizeStalling_should_be_true() {
        XCTAssert(audioPlayer.automaticallyWaitsToMinimizeStalling == true)
    }

    func test_AudioPlayer__buffer__bufferDuration_should_be_zero() {
        XCTAssert(audioPlayer.bufferDuration == 0)
    }

    func test_AudioPlayer__buffer__setting_bufferDuration_disables_automaticallyWaitsToMinimizeStalling() {
        audioPlayer.bufferDuration = 1;
        XCTAssert(audioPlayer.bufferDuration == 1)
        XCTAssert(audioPlayer.automaticallyWaitsToMinimizeStalling == false)
    }

    func test_AudioPlayer__buffer__setting_bufferDuration_back_to_zero_enables_automaticallyWaitsToMinimizeStalling() {
        audioPlayer.bufferDuration = 1;
        audioPlayer.bufferDuration = 0;
        XCTAssert(audioPlayer.bufferDuration == 0)
        XCTAssert(audioPlayer.automaticallyWaitsToMinimizeStalling == true)
    }

    func test_AudioPlayer__buffer__enabling_automaticallyWaitsToMinimizeStalling_sets_bufferDuration_to_zero() {
        audioPlayer.bufferDuration = 1;
        XCTAssert(audioPlayer.automaticallyWaitsToMinimizeStalling == false)
        audioPlayer.automaticallyWaitsToMinimizeStalling = true
        XCTAssert(audioPlayer.bufferDuration == 0)
    }
    
    // MARK: - Seek
    
    func test_AudioPlayer__seek_seeking_should_work_before_loading_completed() {
        var start: Date? = nil;
        var end: Date? = nil;
        let playedUntilEndExpectation = XCTestExpectation()
        let seekedExpectation = XCTestExpectation()
        seekedExpectation.expectedFulfillmentCount = 1

        listener.onStateChange = { state in
            switch state {
            case .playing:
                if (start == nil) {
                    start = Date()
                }
            default: break
            }
        }
        listener.onSeekCompletion = {
            seekedExpectation.fulfill()
        }
        listener.onPlaybackEnd = { reason in
            if (reason == .playedUntilEnd) {
                end = Date()
                playedUntilEndExpectation.fulfill()
            }
        }

        audioPlayer.load(item: FiveSecondSource.getAudioItem(), playWhenReady: true)
        audioPlayer.seek(to: 4.75)
        wait(for: [playedUntilEndExpectation], timeout: 20.0)
        XCTAssertNotNil(end)
        XCTAssertNotNil(start)
        if let start = start, let end = end {
            let duration = end.timeIntervalSince(start);
            XCTAssert(duration < 1)
        }
    }

    func test_AudioPlayer__seek_seeking_should_work_after_loading_completed() {
        var start: Date? = nil;
        var end: Date? = nil;
        let playedUntilEndExpectation = XCTestExpectation()
        let readyExpectation = XCTestExpectation()
        listener.onStateChange = { state in
            switch state {
            case .ready:
                readyExpectation.fulfill()
            case .playing:
                if (start == nil) {
                    start = Date()
                }
            default: break
            }
        }
        listener.onPlaybackEnd = { reason in
            if (reason == .playedUntilEnd) {
                end = Date()
                playedUntilEndExpectation.fulfill()
            }
        }

        audioPlayer.load(item: FiveSecondSource.getAudioItem(), playWhenReady: true)
        wait(for: [readyExpectation], timeout: 20.0)
        audioPlayer.seek(to: 4.75)
        wait(for: [playedUntilEndExpectation], timeout: 20.0)
        XCTAssertNotNil(end)
        XCTAssertNotNil(start)
        if let start = start, let end = end {
            let duration = end.timeIntervalSince(start);
            XCTAssert(duration < 1)
        }
    }
    
    // MARK: - Rate
    
    func test_AudioPlayer__rate__should_be_1() {
        XCTAssert(audioPlayer.rate == 1.0)
    }
    
    func test_AudioPlayer__rate__playing_source__should_be_1() {
        let expectation = XCTestExpectation()
        listener.onStateChange = { [weak audioPlayer] state in
            guard let audioPlayer = audioPlayer else { return }
            switch state {
            case .playing:
                if audioPlayer.rate == 1.0 {
                    expectation.fulfill()
                }
            default: break
            }
        }
        audioPlayer.load(item: Source.getAudioItem(), playWhenReady: true)
        wait(for: [expectation], timeout: 20.0)
    }

    func test_AudioPlayer__rate__setting_rate_should_speed_up_playback() {
        var start: Date? = nil;
        var end: Date? = nil;
        let playedUntilEndExpectation = XCTestExpectation()
        listener.onStateChange = { state in
            switch state {
            case .playing:
                if (start == nil) {
                    start = Date()
                }
            default: break
            }
        }
        listener.onPlaybackEnd = { reason in
            if (reason == .playedUntilEnd) {
                end = Date()
                playedUntilEndExpectation.fulfill()
            }
        }
        audioPlayer.load(item: FiveSecondSource.getAudioItem(), playWhenReady: true)
        audioPlayer.rate = 10
        wait(for: [playedUntilEndExpectation], timeout: 20.0)
        XCTAssertNotNil(end)
        XCTAssertNotNil(start)
        if let start = start, let end = end {
            let duration = end.timeIntervalSince(start);
            XCTAssert(duration <= 1)
        }
    }
    
    func test_AudioPlayer__rate__setting_rate_to_lower_than_1_should_slow_down_playback() {
        var start: Date? = nil;
        var end: Date? = nil;
        let playedUntilEndExpectation = XCTestExpectation()
        listener.onStateChange = { state in
            switch state {
            case .playing:
                if (start == nil) {
                    start = Date()
                }
            default: break
            }
        }
        listener.onPlaybackEnd = { reason in
            if (reason == .playedUntilEnd) {
                end = Date()
                playedUntilEndExpectation.fulfill()
            }
        }

        audioPlayer.load(item: FiveSecondSource.getAudioItem(), playWhenReady: true)
        audioPlayer.seek(to: 4.75)
        audioPlayer.rate = 0.25
        wait(for: [playedUntilEndExpectation], timeout: 20.0)
        XCTAssertNotNil(end)
        XCTAssertNotNil(start)
        if let start = start, let end = end {
            let duration = end.timeIntervalSince(start);
            XCTAssert(duration >= 1)
        }
    }
    
    // MARK: - Current item
    
    func test_AudioPlayer__currentItem__should_be_nil() {
        XCTAssertNil(audioPlayer.currentItem)
    }
    
    func test_AudioPlayer__currentItem__loading_source__should_not_be_nil() {
        let expectation = XCTestExpectation()
        listener.onStateChange = { [weak audioPlayer] state in
            guard let audioPlayer = audioPlayer else { return }
            switch state {
            case .ready:
                if audioPlayer.currentItem != nil {
                    expectation.fulfill()
                }
            default: break
            }
        }
        audioPlayer.load(item: Source.getAudioItem(), playWhenReady: false)
        wait(for: [expectation], timeout: 20.0)
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

// https://gist.github.com/dduan/5507c1e6db78b6ee38d56896764e288c
extension XCTestCase {

    /// Simple helper for asynchronous testing.
    /// Usage in XCTestCase method:
    ///   func testSomething() {
    ///       doAsyncThings()
    ///       eventually {
    ///           /* XCTAssert goes here... */
    ///       }
    ///   }
    /// Closure won't execute until timeout is met. You need to pass in an
    /// timeout long enough for your asynchronous process to finish, if it's
    /// expected to take more than the default 0.01 second.
    ///
    /// - Parameters:
    ///   - timeout: amout of time in seconds to wait before executing the
    ///              closure.
    ///   - closure: a closure to execute when `timeout` seconds has passed
    func eventually(timeout: TimeInterval = 0.5, closure: @escaping () -> Void) {
        let expectation = self.expectation(description: "")
        expectation.fulfillAfter(timeout)
        self.waitForExpectations(timeout: 60) { _ in
            closure()
        }
    }
}

extension XCTestExpectation {

    /// Call `fulfill()` after some time.
    ///
    /// - Parameter time: amout of time after which `fulfill()` will be called.
    func fulfillAfter(_ time: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + time) {
            self.fulfill()
        }
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
