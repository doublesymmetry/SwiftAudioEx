//
//  PlayerListener.swift
//  SwiftAudio
//
//  Created by Brandon Sneed on 3/31/24.
//

import Foundation
import SwiftAudioEx

class PlayerListener {
    var state: PlayerState
    let controller = AudioController.shared
    
    init(state: PlayerState) {
        self.state = state
        
        controller.player.event.playWhenReadyChange.addListener(self, handlePlayWhenReadyChange)
        controller.player.event.stateChange.addListener(self, handleAudioPlayerStateChange)
        controller.player.event.playbackEnd.addListener(self, handleAudioPlayerPlaybackEnd(data:))
        controller.player.event.secondElapse.addListener(self, handleAudioPlayerSecondElapsed)
        controller.player.event.seek.addListener(self, handleAudioPlayerDidSeek)
        controller.player.event.updateDuration.addListener(self, handleAudioPlayerUpdateDuration)
        controller.player.event.didRecreateAVPlayer.addListener(self, handleAVPlayerRecreated)
        render()
    }
    
    func render() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            state.playing = (controller.player.playerState == .playing)
            state.position = controller.player.currentTime
            state.maxTime = controller.player.duration
            state.artist = controller.player.currentItem?.getArtist() ?? ""
            state.title = controller.player.currentItem?.getTitle() ?? ""
            state.elapsedTime = controller.player.currentTime.secondsToString()
            state.remainingTime = (controller.player.duration - controller.player.currentTime).secondsToString()
            if let item = controller.player.currentItem as? DefaultAudioItem {
                state.artwork = item.artwork
            } else {
                state.artwork = nil
            }
        }
    }
    
    func renderTimes() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            state.position = controller.player.currentTime
            state.maxTime = controller.player.duration
            state.elapsedTime = controller.player.currentTime.secondsToString()
            state.remainingTime = (controller.player.duration - controller.player.currentTime).secondsToString()
            print(state.elapsedTime)
        }
    }
    
    // MARK: - AudioPlayer Event Handlers
    
    func handleAudioPlayerStateChange(data: AudioPlayer.StateChangeEventData) {
        print("state=\(data)")
        self.render()
    }
    
    func handlePlayWhenReadyChange(data: AudioPlayer.PlayWhenReadyChangeData) {
        print("playWhenReady=\(data)")
        self.render()
    }
    
    func handleAudioPlayerPlaybackEnd(data: AudioPlayer.PlaybackEndEventData) {
        print("playEndReason=\(data)")
    }
    
    func handleAudioPlayerSecondElapsed(data: AudioPlayer.SecondElapseEventData) {
        if !state.isScrubbing {
            self.renderTimes()
        }
    }
    
    func handleAudioPlayerDidSeek(data: AudioPlayer.SeekEventData) {
        // .. don't need this
    }
    
    func handleAudioPlayerUpdateDuration(data: AudioPlayer.UpdateDurationEventData) {
        if !state.isScrubbing {
            self.renderTimes()
        }
    }
    
    func handleAVPlayerRecreated() {
        // .. don't need this
    }
}
