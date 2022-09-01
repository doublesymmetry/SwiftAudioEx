//
//  QueuedAudioPlayer.swift
//  SwiftAudio
//
//  Created by Jørgen Henrichsen on 24/03/2018.
//

import Foundation
import MediaPlayer

/**
 An audio player that can keep track of a queue of AudioItems.
 */
public class QueuedAudioPlayer: AudioPlayer, QueueManagerDelegate {

    let queueManager: QueueManager = QueueManager<AudioItem>()

    public override init(nowPlayingInfoController: NowPlayingInfoControllerProtocol = NowPlayingInfoController(), remoteCommandController: RemoteCommandController = RemoteCommandController()) {
        super.init(nowPlayingInfoController: nowPlayingInfoController, remoteCommandController: remoteCommandController)
        queueManager.delegate = self
    }

    /// The repeat mode for the queue player.
    public var repeatMode: RepeatMode = .off

    public override var currentItem: AudioItem? {
        queueManager.current
    }

    /**
     The index of the current item.
     */
    public var currentIndex: Int {
        queueManager.currentIndex
    }

     /**
     Stops the player and clears the queue.
     */
    public override func stop() {
        super.stop()
        event.queueIndex.emit(data: (currentIndex, nil))
    }

    override func reset() {
        super.reset()
        queueManager.clearQueue()
    }

    /**
     All items currently in the queue.
     */
    public var items: [AudioItem] {
        queueManager.items
    }

    /**
     The previous items held by the queue.
     */
    public var previousItems: [AudioItem] {
        queueManager.previousItems
    }

    /**
     The upcoming items in the queue.
     */
    public var nextItems: [AudioItem] {
        queueManager.nextItems
    }

    /**
     Will replace the current item with a new one and load it into the player.

     - parameter item: The AudioItem to replace the current item.
     - parameter playWhenReady: Optional, whether to start playback when the item is ready.
     - throws: APError.LoadError
     */
    public override func load(item: AudioItem, playWhenReady: Bool? = nil) throws {
        try super.load(item: item, playWhenReady: playWhenReady ?? willPlayWhenReady)
        queueManager.replaceCurrentItem(with: item)
    }

    /**
     Add a single item to the queue.

     - parameter item: The item to add.
     - parameter playWhenReady: Optional, whether to start playback when the item is ready.
     - throws: `APError`
     */
    public func add(item: AudioItem, playWhenReady: Bool? = nil) throws {
        if currentItem == nil {
            queueManager.addItem(item)
            try load(item: item, playWhenReady: playWhenReady ?? willPlayWhenReady)
        }
        else {
            queueManager.addItem(item)
        }
    }

    /**
     Add items to the queue.

     - parameter items: The items to add to the queue.
     - parameter playWhenReady: Optional, whether to start playback when the item is ready.
     - throws: `APError`
     */
    public func add(items: [AudioItem], playWhenReady: Bool? = nil) throws {
        if currentItem == nil {
            queueManager.addItems(items)
            try load(item: currentItem!, playWhenReady: playWhenReady ?? willPlayWhenReady)
        }
        else {
            queueManager.addItems(items)
        }
    }

    public func add(items: [AudioItem], at index: Int) throws {
        try queueManager.addItems(items, at: index)
    }

    /**
     Step to the next item in the queue.

     - throws: `APError`
     */
    public func next() throws {
        let item = try queueManager.next(wrap: repeatMode == .queue)
        event.playbackEnd.emit(data: .skippedToNext)
        try load(item: item)
    }

    /**
     Step to the previous item in the queue.
     */
    public func previous() throws {
        let item = try queueManager.previous(wrap: repeatMode == .queue)
        event.playbackEnd.emit(data: .skippedToPrevious)
        try load(item: item)
    }

    /**
     Remove an item from the queue.

     - parameter index: The index of the item to remove.
     - throws: `APError.QueueError`
     */
    public func removeItem(at index: Int) throws {
        try queueManager.removeItem(at: index)
    }


    /**
     Jump to a certain item in the queue.

     - parameter index: The index of the item to jump to.
     - parameter playWhenReady: Optional, whether to start playback when the item is ready.
     - throws: `APError`
     */
    public func jumpToItem(atIndex index: Int, playWhenReady: Bool? = nil) throws {
        if (index == currentIndex) {
            seek(to: 0)
            if (playWhenReady == true) {
                play()
            } else if (playWhenReady == false) {
                pause()
            }
            onCurrentIndexChanged(oldIndex: index, newIndex: index)
        } else {
            let item = try queueManager.jump(to: index)
            event.playbackEnd.emit(data: .jumpedToIndex)
            try load(item: item, playWhenReady: playWhenReady ?? willPlayWhenReady)
        }
    }

    /**
     Move an item in the queue from one position to another.

     - parameter fromIndex: The index of the item to move.
     - parameter toIndex: The index to move the item to.
     - throws: `APError.QueueError`
     */
    public func moveItem(fromIndex: Int, toIndex: Int) throws {
        try queueManager.moveItem(fromIndex: fromIndex, toIndex: toIndex)
    }

    /**
     Remove all upcoming items, those returned by `next()`
     */
    public func removeUpcomingItems() {
        queueManager.removeUpcomingItems()
    }

    /**
     Remove all previous items, those returned by `previous()`
     */
    public func removePreviousItems() {
        queueManager.removePreviousItems()
    }

    // MARK: - AVPlayerWrapperDelegate

    override func AVWrapperItemDidPlayToEndTime() {
        super.AVWrapperItemDidPlayToEndTime()
        if (repeatMode == .track) {
            seek(to: 0);
            play()
        } else {
            guard let item = try? queueManager.next(wrap: repeatMode == .queue) else { return }
            try? load(item: item)
        }
    }

    // MARK: - QueueManagerDelegate

    func onCurrentIndexChanged(oldIndex: Int, newIndex: Int) {
        // if _currentItem is nil, then this was triggered by a reset. ignore.
        if currentItem == nil { return }
        event.queueIndex.emit(data: (oldIndex, newIndex))
    }

    func onReceivedFirstItem() {
        event.queueIndex.emit(data: (nil, 0))
    }
}
