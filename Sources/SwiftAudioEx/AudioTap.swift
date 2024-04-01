//
//  AudioTap.swift
//
//
//  Created by Brandon Sneed on 3/31/24.
//

import Foundation
import AVFoundation

/**
 Subclass this and set the AudioPlayer's `audioTap` property to start receiving the
 audio stream.
 */
open class AudioTap {
    // Called at tap initialization for a given player item. Use this to setup anything you might need.
    open func initialize() { print("audioTap: initialize") }
    // Called at teardown of the internal tap.  Use this to reset any memory buffers you have created, etc.
    open func finalize() { print("audioTap: finalize") }
    // Called just before playback so you can perform setup based on the stream description.
    open func prepare(description: AudioStreamBasicDescription) { print("audioTap: prepare") }
    // Called just before finalize.
    open func unprepare() { print("audioTap: unprepare") }
    /**
     Called periodically during audio stream playback.
     
     Example:
     
     ```
     func process(numberOfFrames: Int, buffer: UnsafeMutableAudioBufferListPointer) {
         for channel in buffer {
             // process audio samples here
             //memset(channel.mData, 0, Int(channel.mDataByteSize))
         }
     }
     ```
    */
    open func process(numberOfFrames: Int, buffer: UnsafeMutableAudioBufferListPointer) { print("audioTap: process") }
}

extension AVPlayerWrapper {
    internal func attachTap(_ tap: AudioTap?, to item: AVPlayerItem) {
        guard let tap else { return }
        guard let track = item.asset.tracks(withMediaType: .audio).first else {
            return
        }
        
        let audioMix = AVMutableAudioMix()
        let params = AVMutableAudioMixInputParameters(track: track)
        
        // we need to retain this pointer so it doesn't disappear out from under us.
        // we'll then let it go after we finalize.  If the tap changed upstream, we
        // aren't going to pick up the new one until after this player item goes away.
        let client = UnsafeMutableRawPointer(Unmanaged.passRetained(tap).toOpaque())
        
        var callbacks = MTAudioProcessingTapCallbacks(version: kMTAudioProcessingTapCallbacksVersion_0, clientInfo: client)
        { tapRef, clientInfo, tapStorageOut in
            // initial tap setup
            guard let clientInfo else { return }
            tapStorageOut.pointee = clientInfo
            let audioTap = Unmanaged<AudioTap>.fromOpaque(clientInfo).takeUnretainedValue()
            audioTap.initialize()
        } finalize: { tapRef in
            // clean up
            let audioTap = Unmanaged<AudioTap>.fromOpaque(MTAudioProcessingTapGetStorage(tapRef)).takeUnretainedValue()
            audioTap.finalize()
            // we're done, we can let go of the pointer we retained.
            Unmanaged.passUnretained(audioTap).release()
        } prepare: { tapRef, maxFrames, processingFormat in
            // allocate memory for sound processing
            let audioTap = Unmanaged<AudioTap>.fromOpaque(MTAudioProcessingTapGetStorage(tapRef)).takeUnretainedValue()
            audioTap.prepare(description: processingFormat.pointee)
        } unprepare: { tapRef in
            // deallocate memory for sound processing
            let audioTap = Unmanaged<AudioTap>.fromOpaque(MTAudioProcessingTapGetStorage(tapRef)).takeUnretainedValue()
            audioTap.unprepare()
        } process: { tapRef, numberFrames, flags, bufferListInOut, numberFramesOut, flagsOut in
            guard noErr == MTAudioProcessingTapGetSourceAudio(tapRef, numberFrames, bufferListInOut, flagsOut, nil, numberFramesOut) else {
                return
            }
            
            // process sound data
            let audioTap = Unmanaged<AudioTap>.fromOpaque(MTAudioProcessingTapGetStorage(tapRef)).takeUnretainedValue()
            audioTap.process(numberOfFrames: numberFrames, buffer: UnsafeMutableAudioBufferListPointer(bufferListInOut))
        }
        
        var tapRef: Unmanaged<MTAudioProcessingTap>?
        let error = MTAudioProcessingTapCreate(kCFAllocatorDefault, &callbacks, kMTAudioProcessingTapCreationFlag_PreEffects, &tapRef)
        assert(error == noErr)
        
        params.audioTapProcessor = tapRef?.takeUnretainedValue()
        tapRef?.release()
        
        audioMix.inputParameters = [params]
        item.audioMix = audioMix
    }
}

