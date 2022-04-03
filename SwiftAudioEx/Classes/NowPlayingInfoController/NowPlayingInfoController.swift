//
//  MediaInfoController.swift
//  SwiftAudio
//
//  Created by Jørgen Henrichsen on 15/03/2018.
//

import Foundation
import MediaPlayer

public class NowPlayingInfoController: NowPlayingInfoControllerProtocol {
    private let concurrentInfoQueue: DispatchQueueType

    private(set) var infoCenter: NowPlayingInfoCenter
    private(set) var info: [String: Any] = [:]
    
    public required init() {
        concurrentInfoQueue = DispatchQueue(label: "com.doublesymmetry.nowPlayingInfoQueue", attributes: .concurrent)
        infoCenter = MPNowPlayingInfoCenter.default()
    }

    /// Used for testing purposes.
    public required init(dispatchQueue: DispatchQueueType, infoCenter: NowPlayingInfoCenter) {
        concurrentInfoQueue = dispatchQueue
        self.infoCenter = infoCenter
    }
    
    public required init(infoCenter: NowPlayingInfoCenter) {
        concurrentInfoQueue = DispatchQueue(label: "com.doublesymmetry.nowPlayingInfoQueue", attributes: .concurrent)
        self.infoCenter = infoCenter
    }
    
    public func set(keyValues: [NowPlayingInfoKeyValue]) {
        concurrentInfoQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }

            keyValues.forEach { (keyValue) in
                self.info[keyValue.getKey()] = keyValue.getValue()
            }

            self.infoCenter.nowPlayingInfo = self.info
        }
    }
    
    public func set(keyValue: NowPlayingInfoKeyValue) {
        concurrentInfoQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }

            self.info[keyValue.getKey()] = keyValue.getValue()
            self.infoCenter.nowPlayingInfo = self.info
        }
    }
    
    public func clear() {
        concurrentInfoQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }

            self.info = [:]
            self.infoCenter.nowPlayingInfo = self.info
        }
    }
    
}
