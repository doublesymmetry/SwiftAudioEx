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
@available(iOS 13.0, *)
public class QueuedAudioPlayer: AudioPlayer, QueueManagerDelegate {
    let queue: QueueManager = QueueManager<AudioItem>()
    fileprivate var lastIndex: Int = -1
    fileprivate var lastItem: AudioItem? = nil

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

    override public func clear() async {
        await queue.clearQueue()
        await super.clear()
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
    public override func load(item: AudioItem, playWhenReady: Bool? = nil) async {
        if let playWhenReady = playWhenReady {
            await self.setPlayWhenReady(playWhenReady)
        }
        await queue.replaceCurrentItem(with: item)
    }

    /**
     Add a single item to the queue.

     - parameter item: The item to add.
     - parameter playWhenReady: Optional, whether to start playback when the item is ready.
     */
    public func add(item: AudioItem, playWhenReady: Bool? = nil) async {
        if let playWhenReady = playWhenReady {
            await self.setPlayWhenReady(playWhenReady)
        }
        await queue.add(item)
    }

    /**
     Add items to the queue.

     - parameter items: The items to add to the queue.
     - parameter playWhenReady: Optional, whether to start playback when the item is ready.
     */
    public func add(items: [AudioItem], playWhenReady: Bool? = nil) async {
        if let playWhenReady = playWhenReady {
            await self.setPlayWhenReady(playWhenReady)
        }
        await queue.add(items)
    }

    public func add(items: [AudioItem], at index: Int) async throws {
        try await queue.add(items, at: index)
    }

    /**
     Step to the next item in the queue.
     */
    public func next() async {
        let lastIndex = currentIndex
        let playbackWasActive = wrapper.playbackActive;
        _ = await queue.next(wrap: repeatMode == .queue)
        if (playbackWasActive && lastIndex != currentIndex || repeatMode == .queue) {
            await event.playbackEnd.emit(data: .skippedToNext)
        }
    }

    /**
     Step to the previous item in the queue.
     */
    public func previous() async {
        let lastIndex = currentIndex
        let playbackWasActive = wrapper.playbackActive;
        _ = await queue.previous(wrap: repeatMode == .queue)
        if (playbackWasActive && lastIndex != currentIndex || repeatMode == .queue) {
            await event.playbackEnd.emit(data: .skippedToPrevious)
        }
    }

    /**
     Remove an item from the queue.

     - parameter index: The index of the item to remove.
     - throws: `AudioPlayerError.QueueError`
     */
    public func removeItem(at index: Int) async throws {
        _ = try await queue.removeItem(at: index)
    }


    /**
     Jump to a certain item in the queue.

     - parameter index: The index of the item to jump to.
     - parameter playWhenReady: Optional, whether to start playback when the item is ready.
     - throws: `AudioPlayerError`
     */
    public func jumpToItem(atIndex index: Int, playWhenReady: Bool? = nil) async throws {
        if let playWhenReady = playWhenReady {
            await self.setPlayWhenReady(playWhenReady)
        }
        if (index == currentIndex) {
            await seek(to: 0)
        } else {
            _ = try await queue.jump(to: index)
        }
        await event.playbackEnd.emit(data: .jumpedToIndex)
    }

    /**
     Move an item in the queue from one position to another.

     - parameter fromIndex: The index of the item to move.
     - parameter toIndex: The index to move the item to.
     - throws: `AudioPlayerError.QueueError`
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

    func replay() async {
        await seek(to: 0);
        await play()
    }

    // MARK: - AVPlayerWrapperDelegate

    override func AVWrapperItemDidPlayToEndTime() async {
        await event.playbackEnd.emit(data: .playedUntilEnd)
        if (repeatMode == .track) {
            await replay()
        } else if (repeatMode == .queue) {
            _ = await queue.next(wrap: true)
        } else if (currentIndex != items.count - 1) {
            _ = await queue.next(wrap: false)
        } else {
            await wrapper.setState(state: .ended)
        }
    }

    // MARK: - QueueManagerDelegate

    func onCurrentItemChanged() async {
        let lastPosition = currentTime;
        if let currentItem = currentItem {
            await super.load(item: currentItem)
        } else {
            await super.clear()
        }
        let lastItemToEmit = currentItem
        let lastIndexToEmit = lastIndex == -1 ? nil : lastIndex
        lastItem = currentItem
        lastIndex = currentIndex
        await event.currentItem.emit(
            data: (
                item: currentItem,
                index: currentIndex == -1 ? nil : currentIndex,
                lastItem: lastItemToEmit,
                lastIndex: lastIndexToEmit,
                lastPosition: lastPosition
            )
        )
    }

    func onSkippedToSameCurrentItem() async {
        if (wrapper.playbackActive) {
            await replay()
        }
    }

    func onReceivedFirstItem() async {
        try! await queue.jump(to: 0)
    }
}
