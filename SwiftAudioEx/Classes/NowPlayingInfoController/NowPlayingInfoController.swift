//
//  MediaInfoController.swift
//  SwiftAudio
//
//  Created by Jørgen Henrichsen on 15/03/2018.
//

import Foundation
import MediaPlayer

public class NowPlayingInfoController: NowPlayingInfoControllerProtocol {
    private var concurrentInfoQueue: DispatchQueueType = DispatchQueue(
        label: "com.doublesymmetry.nowPlayingInfoQueue",
        attributes: .concurrent
    )

    private(set) var infoCenter: NowPlayingInfoCenter
    private(set) var info: [String: Any] = [:]
    
    public required init() {
        infoCenter = MPNowPlayingInfoCenter.default()
    }

    /// Used for testing purposes.
    public required init(dispatchQueue: DispatchQueueType, infoCenter: NowPlayingInfoCenter) {
        concurrentInfoQueue = dispatchQueue
        self.infoCenter = infoCenter
    }
    
    public required init(infoCenter: NowPlayingInfoCenter = MPNowPlayingInfoCenter.default()) {
        self.infoCenter = infoCenter
    }
    
    public func set(keyValues: [NowPlayingInfoKeyValue]) {
        keyValues.forEach {
            (keyValue) in info[keyValue.getKey()] = keyValue.getValue()
        }
        update()
    }

    public func setWithoutUpdate(keyValues: [NowPlayingInfoKeyValue]) {
        keyValues.forEach {
            (keyValue) in info[keyValue.getKey()] = keyValue.getValue()
        }
    }
    
    public func set(keyValue: NowPlayingInfoKeyValue) {
        self.info[keyValue.getKey()] = keyValue.getValue()
        update()
    }
   
    private func update() {
        // Make a copy to avoid `EXC_BAD_ACCESS`
        let info = self.info
        concurrentInfoQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.infoCenter.nowPlayingInfo = info
        }
    }
    
    public func clear() {
        self.info = [:]
        concurrentInfoQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.infoCenter.nowPlayingInfo = nil
        }
    }
    
}
