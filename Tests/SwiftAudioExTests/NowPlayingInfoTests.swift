import XCTest
import MediaPlayer
@testable import SwiftAudioEx

class NowPlayingInfoTests: XCTestCase {

    var audioPlayer: AudioPlayer!
    var nowPlayingController: NowPlayingInfoController_Mock!

    override func setUp() {
        super.setUp()
        nowPlayingController = NowPlayingInfoController_Mock()
        audioPlayer = AudioPlayer(nowPlayingInfoController: nowPlayingController)
        audioPlayer.automaticallyUpdateNowPlayingInfo = true
        audioPlayer.volume = 0
    }

    override func tearDown() {
        audioPlayer = nil
        nowPlayingController = nil
        super.tearDown()
    }

    func testNowPlayingInfoControllerMetadataUpdate() {
        let item = Source.getAudioItem()
        audioPlayer.load(item: item, playWhenReady: false)

        XCTAssertEqual(nowPlayingController.getTitle(), item.getTitle())
        XCTAssertEqual(nowPlayingController.getArtist(), item.getArtist())
        XCTAssertEqual(nowPlayingController.getAlbumTitle(), item.getAlbumTitle())
        XCTAssertNotNil(nowPlayingController.getArtwork())
    }

    func testNowPlayingInfoControllerPlaybackValuesUpdate() {
        let item = LongSource.getAudioItem()
        
        // State has become somewhat async to prevent a deadlock,
        // so this isn't instantaneous anymore and needs a teensy bit of time.
        audioPlayer.load(item: item, playWhenReady: true)
        
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 1))

        XCTAssertNotNil(nowPlayingController.getRate())
        XCTAssertNotNil(nowPlayingController.getDuration())
        XCTAssertNotNil(nowPlayingController.getCurrentTime())
    }
}
