//
//  PlayerViewModel.swift
//  SwiftAudio
//
//  Created by David Chavez on 4/12/24.
//

import SwiftAudioEx

#if os(macOS)
import AppKit
public typealias NativeImage = NSImage
#elseif os(iOS)
import UIKit
public typealias NativeImage = UIImage
#endif

extension PlayerView {
    final class ViewModel: ObservableObject {
        // MARK: - Observables

        @Published var playing: Bool = false
        @Published var position: Double = 0
        @Published var artwork: NativeImage? = nil
        @Published var title: String = ""
        @Published var artist: String = ""
        @Published var maxTime: TimeInterval = 100
        @Published var isScrubbing: Bool = false
        @Published var elapsedTime: String = "00:00"
        @Published var remainingTime: String = "00:00"

        @Published var playWhenReady: Bool = false
        @Published var playbackState: AudioPlayerState = .idle

        // MARK: - Properties

        let controller = AudioController.shared

        // MARK: - Initializer

        init() {
            controller.player.event.playWhenReadyChange.addListener(self, handlePlayWhenReadyChange)
            controller.player.event.stateChange.addListener(self, handleAudioPlayerStateChange)
            controller.player.event.playbackEnd.addListener(self, handleAudioPlayerPlaybackEnd(data:))
            controller.player.event.secondElapse.addListener(self, handleAudioPlayerSecondElapsed)
            controller.player.event.seek.addListener(self, handleAudioPlayerDidSeek)
            controller.player.event.updateDuration.addListener(self, handleAudioPlayerUpdateDuration)
            controller.player.event.didRecreateAVPlayer.addListener(self, handleAVPlayerRecreated)
        }

        // MARK: - Updates

        private func render() {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                playing = (controller.player.playerState == .playing)
                playbackState = controller.player.playerState
                playWhenReady = controller.player.playWhenReady
                position = controller.player.currentTime
                maxTime = controller.player.duration
                artist = controller.player.currentItem?.getArtist() ?? ""
                title = controller.player.currentItem?.getTitle() ?? ""
                elapsedTime = controller.player.currentTime.secondsToString()
                remainingTime = (controller.player.duration - controller.player.currentTime).secondsToString()
                if let item = controller.player.currentItem as? DefaultAudioItem {
                    artwork = item.artwork
                } else {
                    artwork = nil
                }
            }
        }

        private func renderTimes() {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                position = controller.player.currentTime
                maxTime = controller.player.duration
                elapsedTime = controller.player.currentTime.secondsToString()
                remainingTime = (controller.player.duration - controller.player.currentTime).secondsToString()
                print(elapsedTime)
            }
        }

        // MARK: - AudioPlayer Event Handlers

        func handleAudioPlayerStateChange(data: AudioPlayer.StateChangeEventData) {
            print("state=\(data)")
            render()
        }

        func handlePlayWhenReadyChange(data: AudioPlayer.PlayWhenReadyChangeData) {
            print("playWhenReady=\(data)")
            render()
        }

        func handleAudioPlayerPlaybackEnd(data: AudioPlayer.PlaybackEndEventData) {
            print("playEndReason=\(data)")
        }

        func handleAudioPlayerSecondElapsed(data: AudioPlayer.SecondElapseEventData) {
            if !isScrubbing {
                renderTimes()
            }
        }

        func handleAudioPlayerDidSeek(data: AudioPlayer.SeekEventData) {
            // .. don't need this
        }

        func handleAudioPlayerUpdateDuration(data: AudioPlayer.UpdateDurationEventData) {
            if !isScrubbing {
                renderTimes()
            }
        }

        func handleAVPlayerRecreated() {
            // .. don't need this
        }
    }
}
