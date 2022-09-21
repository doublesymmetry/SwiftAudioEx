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
    let queue: QueueManager = QueueManager<AudioItem>()
    
    public override init(nowPlayingInfoController: NowPlayingInfoControllerProtocol = NowPlayingInfoController(), remoteCommandController: RemoteCommandController = RemoteCommandController()) {
        super.init(nowPlayingInfoController: nowPlayingInfoController, remoteCommandController: remoteCommandController)
        queue.delegate = self
    }

    /// The repeat mode for the queue player.
    public var repeatMode: RepeatMode = .off

    public override var currentItem: AudioItem? {
        queue.current
    }

    /**
     The index of the current item.
     */
    public var currentIndex: Int {
        queue.currentIndex
    }

    override func reset() {
        queue.clearQueue()
    }

    /**
     All items currently in the queue.
     */
    public var items: [AudioItem] {
        queue.items
    }

    /**
     The previous items held by the queue.
     */
    public var previousItems: [AudioItem] {
        queue.previousItems
    }

    /**
     The upcoming items in the queue.
     */
    public var nextItems: [AudioItem] {
        queue.nextItems
    }

    /**
     Will replace the current item with a new one and load it into the player.

     - parameter item: The AudioItem to replace the current item.
     - parameter playWhenReady: Optional, whether to start playback when the item is ready.
     */
    public override func load(item: AudioItem, playWhenReady: Bool? = nil) {
        self.playWhenReady = playWhenReady ?? self.playWhenReady
        queue.replaceCurrentItem(with: item)
    }

    /**
     Add a single item to the queue.

     - parameter item: The item to add.
     - parameter playWhenReady: Optional, whether to start playback when the item is ready.
     - throws: `APError`
     */
    public func add(item: AudioItem, playWhenReady: Bool? = nil) throws {
        if let playWhenReady = playWhenReady {
            self.playWhenReady = playWhenReady
        }
        queue.add(item)
    }

    /**
     Add items to the queue.

     - parameter items: The items to add to the queue.
     - parameter playWhenReady: Optional, whether to start playback when the item is ready.
     - throws: `APError`
     */
    public func add(items: [AudioItem], playWhenReady: Bool? = nil) throws {
        if let playWhenReady = playWhenReady {
            self.playWhenReady = playWhenReady
        }
        queue.add(items)
    }

    public func add(items: [AudioItem], at index: Int) throws {
        try queue.add(items, at: index)
    }

    /**
     Step to the next item in the queue.

     - throws: `APError`
     */
    public func next() {
        _ = queue.next(wrap: repeatMode == .queue)
        event.playbackEnd.emit(data: .skippedToNext)
    }

    /**
     Step to the previous item in the queue.
     */
    public func previous() {
        _ = queue.previous(wrap: repeatMode == .queue)
        event.playbackEnd.emit(data: .skippedToPrevious)
    }

    /**
     Remove an item from the queue.

     - parameter index: The index of the item to remove.
     - throws: `APError.QueueError`
     */
    public func removeItem(at index: Int) throws {
        try queue.removeItem(at: index)
    }


    /**
     Jump to a certain item in the queue.

     - parameter index: The index of the item to jump to.
     - parameter playWhenReady: Optional, whether to start playback when the item is ready.
     - throws: `APError`
     */
    public func jumpToItem(atIndex index: Int, playWhenReady: Bool? = nil) throws {
        if let playWhenReady = playWhenReady {
            self.playWhenReady = playWhenReady
        }
        if (index == currentIndex) {
            seek(to: 0)
        } else {
            _ = try queue.jump(to: index)
            event.playbackEnd.emit(data: .jumpedToIndex)
        }
    }

    /**
     Move an item in the queue from one position to another.

     - parameter fromIndex: The index of the item to move.
     - parameter toIndex: The index to move the item to.
     - throws: `APError.QueueError`
     */
    public func moveItem(fromIndex: Int, toIndex: Int) throws {
        try queue.moveItem(fromIndex: fromIndex, toIndex: toIndex)
    }

    /**
     Remove all upcoming items, those returned by `next()`
     */
    public func removeUpcomingItems() {
        queue.removeUpcomingItems()
    }

    /**
     Remove all previous items, those returned by `previous()`
     */
    public func removePreviousItems() {
        queue.removePreviousItems()
    }

    // MARK: - AVPlayerWrapperDelegate

    override func AVWrapperItemDidPlayToEndTime() {
        super.AVWrapperItemDidPlayToEndTime()
        if (repeatMode == .track) {
            seek(to: 0);
            play()
        } else if (repeatMode == .queue) {
            _ = queue.next(wrap: true)
        // Avoid looping the last item when not in queue repeat mode:
        } else if (currentIndex != items.count - 1) {
            _ = queue.next(wrap: false)
        }
    }

    // MARK: - QueueManagerDelegate

    func onCurrentItemChanged(index: Int?) {
        guard let currentItem = currentItem else {
            self.wrapper.reset()
            super.reset()
            return
        }
        try? super.load(item: currentItem)
        event.currentItem.emit(data: (item: currentItem, index: index == -1 ? nil : index))
    }

    func onReceivedFirstItem() {
        try! queue.jump(to: 0)
    }
}
