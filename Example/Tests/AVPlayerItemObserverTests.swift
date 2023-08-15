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
                        expect(observer.observingItem).toEventuallyNot(beNil())
                    }
                }
            }
            
            describe("observing status") {
                it("should not be observing") {
                    expect(observer.isObserving).toEventuallyNot(beTrue())
                }
                context("when observing") {
                    var item: AVPlayerItem!
                    beforeEach {
                        item = AVPlayerItem(url: URL(fileURLWithPath: Source.path))
                        observer.startObserving(item: item)
                    }
                    it("should be observing") {
                        expect(observer.isObserving).toEventually(beTrue())
                    }
                }
            }
        }
    }
}

class AVPlayerItemObserverDelegateHolder: AVPlayerItemObserverDelegate {
    func item(didUpdatePlaybackLikelyToKeepUp playbackLikelyToKeepUp: Bool) {

    }
    
    var receivedCommonMetadata: ((_ metadata: [AVMetadataItem]) -> Void)?
    
    func item(didReceiveCommonMetadata metadata: [AVMetadataItem]) {
        receivedCommonMetadata?(metadata)
    }
    
    
    var receivedTimedMetadata: ((_ metadata: [AVTimedMetadataGroup]) -> Void)?
    
    func item(didReceiveTimedMetadata metadata: [AVTimedMetadataGroup]) {
        receivedTimedMetadata?(metadata)
    }
    
    
    var receivedChapterMetadata: ((_ metadata: [AVTimedMetadataGroup]) -> Void)?
    
    func item(didReceiveChapterMetadata metadata: [AVTimedMetadataGroup]) {
        receivedChapterMetadata?(metadata)
    }
    
    
    var updateDuration: ((_ duration: Double) -> Void)?
    
    func item(didUpdateDuration duration: Double) {
        updateDuration?(duration)
    }
}
