//
//  File.swift
//  
//
//  Created by Brandon Sneed on 4/1/24.
//

import Foundation
import CoreAudio
@testable import SwiftAudioEx

class DummyAudioTap: AudioTap {
    static var outputs = [String]()
    
    let tapIndex: Int
    
    init(tapIndex: Int) {
        self.tapIndex = tapIndex
    }
    
    override func initialize() { 
        Self.outputs.append("audioTap \(tapIndex): initialize")
    }
    
    override func finalize() {
        Self.outputs.append("audioTap \(tapIndex): finalize")
    }
    
    override func prepare(description: AudioStreamBasicDescription) {
        Self.outputs.append("audioTap \(tapIndex): prepare")
    }
    
    override func unprepare() {
        Self.outputs.append("audioTap \(tapIndex): unprepare")
    }
    
    override func process(numberOfFrames: Int, buffer: UnsafeMutableAudioBufferListPointer) {
        Self.outputs.append("audioTap \(tapIndex): process")
    }
}
