//
//  PlayerState.swift
//  SwiftAudio
//
//  Created by Brandon Sneed on 3/30/24.
//

import Foundation
import SwiftAudioEx
import AppKit
import SwiftUI

class PlayerState: ObservableObject {
    @Published var playing: Bool = false
    @Published var position: Double = 0
    @Published var artwork: NSImage? = nil
    @Published var title: String = ""
    @Published var artist: String = ""
    @Published var maxTime: TimeInterval = 100
    @Published var isScrubbing: Bool = false
    @Published var elapsedTime: String = "00:00"
    @Published var remainingTime: String = "00:00"
}


