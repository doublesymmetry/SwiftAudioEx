//
//  AVPlayerWrapperProtocol.swift
//  SwiftAudio
//
//  Created by Jørgen Henrichsen on 26/10/2018.
//

import Foundation
import AVFoundation


protocol AVPlayerWrapperProtocol: AnyObject {
        
    var currentItem: AVPlayerItem? { get }
    
    var playbackActive: Bool { get }
    
    var currentTime: TimeInterval { get }
    
    var duration: TimeInterval { get }
    
    var bufferedPosition: TimeInterval { get }
    
    var reasonForWaitingToPlay: AVPlayer.WaitingReason? { get }
    
    var playbackError: AudioPlayerError.PlaybackError? { get }
    
    var rate: Float { get set }
    
    var delegate: AVPlayerWrapperDelegate? { get set }
    
    var bufferDuration: TimeInterval { get set }
    
    var timeEventFrequency: TimeEventFrequency { get set }
    
    var volume: Float { get set }
    
    var isMuted: Bool { get set }
    
    var automaticallyWaitsToMinimizeStalling: Bool { get set }
    
    func getPlayWhenReady() -> Bool

    func setPlayWhenReady(_ playWhenReady: Bool) async
    
    func getState() -> AVPlayerWrapperState

    func setState(state: AVPlayerWrapperState) async

    func play() async
    
    func pause() async
    
    func togglePlaying() async
    
    func stop() async
    
    func seek(to seconds: TimeInterval) async

    func seek(by offset: TimeInterval) async

    func load(from url: URL, playWhenReady: Bool, options: [String: Any]?) async
    
    func load(from url: URL, playWhenReady: Bool, initialTime: TimeInterval?, options: [String: Any]?) async
    
    func load(from url: String, type: SourceType, playWhenReady: Bool, initialTime: TimeInterval?, options: [String: Any]?) async
    
    func unload() async
    
    func reload(startFromCurrentTime: Bool) async
}
