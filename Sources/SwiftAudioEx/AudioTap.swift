//
//  AudioTap.swift
//
//
//  Created by Brandon Sneed on 3/31/24.
//

import Foundation
import AVFoundation

public protocol AudioTap {
    func initialize()
    func finalize()
    func prepare(description: AudioStreamBasicDescription)
    func unprepare()
    func process(numberOfFrames: Int, buffer: UnsafeMutableAudioBufferListPointer)
}

extension AVPlayerWrapper {
    internal func attachTap(_ tap: AudioTap?, to item: AVPlayerItem) {
        guard let tap else { return }
        guard let track = item.asset.tracks(withMediaType: .audio).first else {
            return
        }
        
        let audioMix = AVMutableAudioMix()
        let params = AVMutableAudioMixInputParameters(track: track)
        var callbacks = MTAudioProcessingTapCallbacks(version: kMTAudioProcessingTapCallbacksVersion_0, clientInfo: nil)
        { tapRef, _, tapStorageOut in
            // initialize
            print("tap initialized")
        } finalize: { tapRef in
            // clean up
            print("tap finalized")
        } prepare: { tapRef, maxFrames, processingFormat in
            // allocate memory for sound processing
        } unprepare: { tapRef in
            // deallocate memory for sound processing
        } process: { tapRef, numberFrames, flags, bufferListInOut, numberFramesOut, flagsOut in
            guard noErr == MTAudioProcessingTapGetSourceAudio(tapRef, numberFrames, bufferListInOut, flagsOut, nil, numberFramesOut) else {
                return
            }
            
            // retrieve AudioBuffer using UnsafeMutableAudioBufferListPointer
            for buffer in UnsafeMutableAudioBufferListPointer(bufferListInOut) {
                // process audio samples here
                //memset(buffer.mData, 0, Int(buffer.mDataByteSize))
            }
            print("tap processed")
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

