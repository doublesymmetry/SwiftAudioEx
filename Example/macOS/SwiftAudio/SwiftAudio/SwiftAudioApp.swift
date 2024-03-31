//
//  SwiftAudioApp.swift
//  SwiftAudio
//
//  Created by Brandon Sneed on 3/30/24.
//

import SwiftUI

@main
struct SwiftAudioApp: App {
    let state: PlayerState
    let listener: PlayerListener
    
    var body: some Scene {
        WindowGroup {
            PlayerView(state: state, listener: listener)
        }
    }
    
    init() {
        let state = PlayerState()
        self.state = state
        self.listener = PlayerListener(state: state)
    }
}
