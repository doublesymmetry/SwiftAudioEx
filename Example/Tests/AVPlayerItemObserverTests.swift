import Quick
import Nimble
import AVFoundation

@testable import SwiftAudioEx

class AVPlayerItemObserverTests: QuickSpec {
    
    override func spec() {
        
        describe("An AVPlayerItemObserver") {
            var observer: AVPlayerItemObserver!
            beforeEach {
                observer = AVPlayerItemObserver()
            }
            describe("observed item") {
                context("when observing") {
                    var item: AVPlayerItem!
                    beforeEach {
                        item = AVPlayerItem(url: URL(fileURLWithPath: Source.path))
                        observer.startObserving(item: item)
                    }
                    
                    it("should exist") {
                        await expect(observer.observingItem).toEventuallyNot(beNil())
                    }
                }
            }
            
            describe("observing status") {
                it("should not be observing") {
                    await expect(observer.isObserving).toEventuallyNot(beTrue())
                }
                context("when observing") {
                    var item: AVPlayerItem!
                    beforeEach {
                        item = AVPlayerItem(url: URL(fileURLWithPath: Source.path))
                        observer.startObserving(item: item)
                    }
                    it("should be observing") {
                        await expect(observer.isObserving).toEventually(beTrue())
                    }
                }
            }
        }
    }
}

class AVPlayerItemObserverDelegateHolder: AVPlayerItemObserverDelegate {
    func item(didUpdatePlaybackLikelyToKeepUp playbackLikelyToKeepUp: Bool) {

    }
    
    var receivedMetadata: ((_ metadata: [AVTimedMetadataGroup]) -> Void)?
    
    func item(didReceiveMetadata metadata: [AVTimedMetadataGroup]) {
        receivedMetadata?(metadata)
    }

    
    var updateDuration: ((_ duration: Double) -> Void)?
    
    func item(didUpdateDuration duration: Double) {
        updateDuration?(duration)
    }
}
