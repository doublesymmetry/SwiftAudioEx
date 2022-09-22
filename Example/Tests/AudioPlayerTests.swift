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
    
    func test_AudioPlayer__state__should_be_idle() {
        XCTAssert(audioPlayer.playerState == AudioPlayerState.idle)
    }
    
    func test_AudioPlayer__state__load_source__should_be_loading() {
        try? audioPlayer.load(item: Source.getAudioItem(), playWhenReady: false)
        XCTAssertEqual(audioPlayer.playerState, AudioPlayerState.loading)
    }
    
    func test_AudioPlayer__state__load_source__should_be_ready() {
        let expectation = XCTestExpectation()
        listener.stateUpdate = { state in
            switch state {
            case .ready: expectation.fulfill()
            default: break
            }
        }
        try? audioPlayer.load(item: Source.getAudioItem(), playWhenReady: false)
        wait(for: [expectation], timeout: 20.0)
    }
    
    func test_AudioPlayer__state__load_source_playWhenReady__should_be_playing() {
        let expectation = XCTestExpectation()
        listener.stateUpdate = { state in
            switch state {
            case .playing: expectation.fulfill()
            default: break
            }
        }
        try? audioPlayer.load(item: Source.getAudioItem(), playWhenReady: true)
        wait(for: [expectation], timeout: 20.0)
    }

    func test_AudioPlayer__state__play_source__should_emit_events_in_reliable_order() {
        var events = [audioPlayer.playerState.rawValue == "idle" ? "idle" : "not_idle"]
        listener.stateUpdate = { state in
            switch state {
                case .loading: events.append("loading")
                case .ready: events.append("ready")
                // Leaving out bufferring events because they can show up at any point
                case .buffering: break
                case .playing: events.append("playing")
                case .paused: events.append("paused")
                case .idle: events.append("idle")
            }
        }
        try? audioPlayer.load(item: Source.getAudioItem(), playWhenReady: true)
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
        listener.stateUpdate = { state in
            switch state {
                case .loading: events.append("loading")
                case .ready: events.append("ready")
                // Leaving out bufferring events because they can show up at any point
                case .buffering: break
                case .playing: events.append("playing")
                case .paused: events.append("paused")
                case .idle: events.append("idle")
            }
        }
        try? audioPlayer.load(item: Source.getAudioItem(), playWhenReady: true)
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
    
    func test_AudioPlayer__state__play_source__should_emit_fail_event_on_load_failure() {
        var didReceiveError = false;
        listener.onReceivedFail = { error in
            didReceiveError = true;
        }
        let nonExistingUrl = "https://\(String.random(length: 100)).com/\(String.random(length: 100)).mp3";
        let item = DefaultAudioItem(audioUrl: nonExistingUrl, artist: "Artist", title: "Title", albumTitle: "AlbumTitle", sourceType: .stream);
        try? audioPlayer.load(item: item, playWhenReady: true)
        eventually {
            XCTAssertEqual(didReceiveError, true)
        }
    }
    
    func test_AudioPlayer__state__play_source__should_emit_events_in_reliable_order_also_after_loading_after_reset() {
        var events = [audioPlayer.playerState.rawValue == "idle" ? "idle" : "not_idle"]
        listener.stateUpdate = { state in
            switch state {
                case .loading: events.append("loading")
                case .ready: events.append("ready")
                // Leaving out bufferring events because they are not expected to show up in consistent order
                case .buffering: break
                case .playing: events.append("playing")
                case .paused: events.append("paused")
                case .idle: events.append("idle")
            }
        }
        try? audioPlayer.load(item: Source.getAudioItem(), playWhenReady: true)
        var expectedEvents = ["idle", "loading", "ready", "playing"];
        eventually {
            XCTAssertEqual(events, expectedEvents)
        }
        audioPlayer.reset()
        expectedEvents.append(contentsOf: ["idle"]);
        eventually {
            XCTAssertEqual(events, expectedEvents)
        }
        try? audioPlayer.load(item: Source.getAudioItem())
        expectedEvents.append(contentsOf: ["loading", "ready", "playing"]);
        eventually {
            XCTAssertEqual(events, expectedEvents)
        }
    }
    
    func test_AudioPlayer__state__play_source__should_be_playing() {
        let expectation = XCTestExpectation()
        listener.stateUpdate = { state in
            switch state {
            case .ready: self.audioPlayer.play()
            case .playing: expectation.fulfill()
            default: break
            }
        }
        try? audioPlayer.load(item: Source.getAudioItem(), playWhenReady: false)
        wait(for: [expectation], timeout: 20.0)
    }
    
    func test_AudioPlayer__state__pausing_source__should_be_paused() {
        let expectation = XCTestExpectation()
        listener.stateUpdate = { [weak audioPlayer] state in
            switch state {
            case .playing: audioPlayer?.pause()
            case .paused: expectation.fulfill()
            default: break
            }
        }
        try? audioPlayer.load(item: Source.getAudioItem(), playWhenReady: true)
        wait(for: [expectation], timeout: 20.0)
    }
    
    func test_AudioPlayer__state__stopping_source__should_be_idle() {
        let expectation = XCTestExpectation()
        var hasBeenPlaying: Bool = false
        listener.stateUpdate = { [weak audioPlayer] state in
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
        try? audioPlayer.load(item: Source.getAudioItem(), playWhenReady: true)
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
//        try? audioPlayer.load(item: LongSource.getAudioItem(), playWhenReady: true)
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
    
    // MARK: - Rate
    
    func test_AudioPlayer__rate__should_be_1() {
        XCTAssert(audioPlayer.rate == 1.0)
    }
    
    func test_AudioPlayer__rate__playing_source__should_be_1() {
        let expectation = XCTestExpectation()
        listener.stateUpdate = { [weak audioPlayer] state in
            guard let audioPlayer = audioPlayer else { return }
            switch state {
            case .playing:
                if audioPlayer.rate == 1.0 {
                    expectation.fulfill()
                }
            default: break
            }
        }
        try? audioPlayer.load(item: Source.getAudioItem(), playWhenReady: true)
        wait(for: [expectation], timeout: 20.0)
    }
    
    // MARK: - Current item
    
    func test_AudioPlayer__currentItem__should_be_nil() {
        XCTAssertNil(audioPlayer.currentItem)
    }
    
    func test_AudioPlayer__currentItem__loading_source__should_not_be_nil() {
        let expectation = XCTestExpectation()
        listener.stateUpdate = { [weak audioPlayer] state in
            guard let audioPlayer = audioPlayer else { return }
            switch state {
            case .ready:
                if audioPlayer.currentItem != nil {
                    expectation.fulfill()
                }
            default: break
            }
        }
        try? audioPlayer.load(item: Source.getAudioItem(), playWhenReady: false)
        wait(for: [expectation], timeout: 20.0)
    }
    
}

class AudioPlayerEventListener {
    
    var state: AudioPlayerState? {
        didSet {
            if let state = state {
                stateUpdate?(state)
            }
        }
    }
    
    var stateUpdate: ((_ state: AudioPlayerState) -> Void)?
    var secondsElapse: ((_ seconds: TimeInterval) -> Void)?
    var seekCompletion: (() -> Void)?
    var onReceivedFail: ((_ error: Error?) -> Void)?
    
    weak var audioPlayer: AudioPlayer?
    
    init(audioPlayer: AudioPlayer) {
        audioPlayer.event.stateChange.addListener(self, handleDidUpdateState)
        audioPlayer.event.seek.addListener(self, handleSeek)
        audioPlayer.event.secondElapse.addListener(self, handleSecondsElapse)
        audioPlayer.event.fail.addListener(self, handleFail)
    }
    
    deinit {
        audioPlayer?.event.stateChange.removeListener(self)
        audioPlayer?.event.seek.removeListener(self)
        audioPlayer?.event.secondElapse.removeListener(self)
    }
    
    func handleDidUpdateState(state: AudioPlayerState) {
        self.state = state
    }
    
    func handleSeek(data: AudioPlayer.SeekEventData) {
        seekCompletion?()
    }
    
    func handleSecondsElapse(data: AudioPlayer.SecondElapseEventData) {
        self.secondsElapse?(data)
    }

    func handleFail(error: Error?) {
        self.onReceivedFail?(error)
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
