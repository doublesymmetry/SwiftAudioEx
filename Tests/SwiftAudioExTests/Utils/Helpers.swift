import Foundation
import XCTest

@testable import SwiftAudioEx

extension XCTestCase {
    var defaultTimeout: TimeInterval {
        if ProcessInfo.processInfo.environment["CI"] != nil {
            return 10
        } else {
            return 5
        }
    }

    func waitForSeek(_ audioPlayer: AudioPlayer, to time: Double) {
        let seekEventListener = QueuedAudioPlayer.SeekEventListener()
        audioPlayer.event.seek.addListener(seekEventListener, seekEventListener.handleEvent)
        audioPlayer.seek(to: time)
        
        waitEqual(seekEventListener.eventResult.0, time, accuracy: 0.1, timeout: defaultTimeout)
        waitEqual(seekEventListener.eventResult.1, true, timeout: defaultTimeout)
    }
    
    func waitEqual<T: Equatable>(_ expression1: @autoclosure @escaping () -> T, _ expression2: @autoclosure @escaping () -> T, timeout: TimeInterval) {
        let expectation = XCTestExpectation(description: "Value should eventually equal expected value")

        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if expression1() == expression2() {
                expectation.fulfill()
                timer.invalidate()
            }
        }
        
        RunLoop.current.add(timer, forMode: .default)
        wait(for: [expectation], timeout: timeout)

        timer.invalidate()
    }
    
    func waitEqual<T: Equatable>(_ expression1: @autoclosure @escaping () -> T, _ expression2: @autoclosure @escaping () -> T, accuracy: T, timeout: TimeInterval) where T: FloatingPoint {
        let expectation = XCTestExpectation(description: "Value should eventually equal expected value with accuracy")
        
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if abs(expression1() - expression2()) < accuracy {
                expectation.fulfill()
                timer.invalidate()
            }
        }

        RunLoop.current.add(timer, forMode: .default)
        wait(for: [expectation], timeout: timeout)

        timer.invalidate()
    }
    
    func waitEqual<T1: Equatable, T2: Equatable>(_ expression1: @autoclosure @escaping () -> (T1, T2), _ expression2: @autoclosure @escaping () -> (T1, T2), timeout: TimeInterval) {
        let expectation = XCTestExpectation(description: "Values should eventually be equal")
        
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if expression1() == expression2() {
                expectation.fulfill()
                timer.invalidate()
            }
        }

        RunLoop.current.add(timer, forMode: .default)
        wait(for: [expectation], timeout: timeout)

        timer.invalidate()
    }


    func waitTrue(_ expression: @autoclosure @escaping () -> Bool, timeout: TimeInterval) {
        let expectation = XCTestExpectation(description: "Expression should eventually be true")

        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if expression() {
                expectation.fulfill()
                timer.invalidate()
            }
        }

        RunLoop.current.add(timer, forMode: .default)
        wait(for: [expectation], timeout: timeout)

        timer.invalidate()
    }
}
