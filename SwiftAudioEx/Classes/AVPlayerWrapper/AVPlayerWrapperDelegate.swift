//
//  AVPlayerWrapperDelegate.swift
//  SwiftAudio
//
//  Created by Jørgen Henrichsen on 26/10/2018.
//

import Foundation
import MediaPlayer


protocol AVPlayerWrapperDelegate: AnyObject {
    func AVWrapper(didChangeState state: AVPlayerWrapperState) async
    func AVWrapper(secondsElapsed seconds: Double) async
    func AVWrapper(failedWithError error: Error?) async
    func AVWrapper(seekTo seconds: Double, didFinish: Bool) async
    func AVWrapper(didUpdateDuration duration: Double) async
    func AVWrapper(didReceiveMetadata metadata: [AVTimedMetadataGroup]) async
    func AVWrapper(didChangePlayWhenReady playWhenReady: Bool) async
    func AVWrapperItemDidPlayToEndTime() async
    func AVWrapperItemFailedToPlayToEndTime() async
    func AVWrapperItemPlaybackStalled() async
    func AVWrapperDidRecreateAVPlayer() async
}
