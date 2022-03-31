import Quick
import Nimble
import AVFoundation

@testable import SwiftAudioEx

class AudioSessionControllerTests: QuickSpec {
    
    override func spec() {
        
        describe("An AudioSessionController") {
            let audioSessionController: AudioSessionController = AudioSessionController(audioSession: NonFailingAudioSession())
            
            it("should be inactive") {
                expect(audioSessionController.audioSessionIsActive).to(beFalse())
            }
            
            context("when session is activated") {
                beforeEach {
                    try? audioSessionController.activateSession()
                }
                
                it("should be active") {
                    expect(audioSessionController.audioSessionIsActive).to(beTrue())
                }
                
                context("when deactivating session") {
                    beforeEach {
                        try? audioSessionController.deactivateSession()
                    }
                    
                    it("should be inactive") {
                        expect(audioSessionController.audioSessionIsActive).to(beFalse())
                    }
                }
            }
            
            describe("its isObservingForInterruptions") {
                it("should be true") {
                    expect(audioSessionController.isObservingForInterruptions).to(beTrue())
                }
                
                context("when isObservingForInterruptions is set to false") {
                    beforeEach {
                        audioSessionController.isObservingForInterruptions = false
                    }
                    
                    it("should be false") {
                        expect(audioSessionController.isObservingForInterruptions).to(beFalse())
                    }
                }
            }
            
            describe("its delegate") {
                context("when a ended interruption arrives") {
                    var delegate: AudioSessionControllerDelegateImplementation!
                    beforeEach {
                        let notification = Notification(name: AVAudioSession.interruptionNotification, object: nil, userInfo: [
                            AVAudioSessionInterruptionTypeKey: UInt(0),
                            AVAudioSessionInterruptionOptionKey: UInt(1),
                            ])
                        delegate = AudioSessionControllerDelegateImplementation()
                        audioSessionController.delegate = delegate
                        audioSessionController.handleInterruption(notification: notification)
                    }
                    
                    it("should eventually be updated with the interruption type") {
                        expect(delegate.interruptionType).toEventually(equal(InterruptionType.ended(shouldResume: true)))
                    }
                    
                }
                context("when a begin interruption arrives") {
                    var delegate: AudioSessionControllerDelegateImplementation!
                    beforeEach {
                        let notification = Notification(name: AVAudioSession.interruptionNotification, object: nil, userInfo: [
                            AVAudioSessionInterruptionTypeKey: UInt(1),
                            ])
                        delegate = AudioSessionControllerDelegateImplementation()
                        audioSessionController.delegate = delegate
                        audioSessionController.handleInterruption(notification: notification)
                    }
                    
                    it("should eventually be updated with the interruption type") {
                        expect(delegate.interruptionType).toEventually(equal(InterruptionType.began))
                    }
                    
                }
            }
        }
        
        describe("An AudioSessionController with a failing AudioSession") {
            var audioSessionController: AudioSessionController!
            beforeEach {
                audioSessionController = AudioSessionController(audioSession: FailingAudioSession())
            }
            
            context("when activated") {
                beforeEach {
                    try? audioSessionController.activateSession()
                }
                
                it("should be inactive") {
                    expect(audioSessionController.audioSessionIsActive).to(beFalse())
                }
            }
        }
    }
}

class AudioSessionControllerDelegateImplementation: AudioSessionControllerDelegate {
    var interruptionType: InterruptionType? = nil
    
    func handleInterruption(type: InterruptionType) {
        self.interruptionType = type
    }
}
