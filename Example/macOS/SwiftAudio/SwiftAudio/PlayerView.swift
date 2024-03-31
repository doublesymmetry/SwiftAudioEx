//
//  PlayerView.swift
//  SwiftAudio
//
//  Created by Brandon Sneed on 3/30/24.
//

import SwiftUI
import SwiftAudioEx

struct PlayerView: View {
    @ObservedObject var state: PlayerState
    
    let controller = AudioController.shared
    let listener: PlayerListener
    
    var body: some View {
        VStack {
            Spacer()
            HStack(alignment: .center) {
                Spacer()
                Button("Queue") {
                    // open the queue
                }
            }
            
            if let image = state.artwork {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 500, height: 500)
            } else {
                AsyncImage(url: nil)
                    .frame(width: 500, height: 500)
            }
            
            Text(state.title)
                .bold()
            Text(state.artist)
            if state.maxTime > 0 {
                Slider(value: $state.position, in: 0...state.maxTime) { editing in
                    state.isScrubbing = editing
                    print("scrubbing = \(state.isScrubbing)")
                    if state.isScrubbing == false {
                        controller.player.seek(to: state.position)
                    }
                }
                HStack {
                    Text(state.elapsedTime)
                    Spacer()
                    Text(state.remainingTime)
                }
            } else {
                Text("Live Streaming")
                Spacer()
            }
            
            HStack {
                Button("Prev") {
                    controller.player.next()
                }
                
                Button(state.playing ? "Pause" : "Play") {
                    if state.playing {
                        controller.player.pause()
                    } else {
                        controller.player.play()
                    }
                }.bold()
                
                Button("Next") {
                    controller.player.next()
                }
            }
            
            Spacer()
            Spacer()
            Spacer()
        }
        .padding()
    }
    
    init(state: PlayerState, listener: PlayerListener) {
        self.state = state
        self.listener = listener
    }
}

