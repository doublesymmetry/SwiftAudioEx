//
//  QueueManager.swift
//  SwiftAudio
//
//  Created by Jørgen Henrichsen on 24/03/2018.
//

import Foundation

protocol QueueManagerDelegate: AnyObject {
    func onReceivedFirstItem()
    func onCurrentItemChanged()
}

class QueueManager<T> {

    weak var delegate: QueueManagerDelegate? = nil

    /**
     All items held by the queue.
     */
    private(set) var items: [T] = [] {
        didSet {
            if oldValue.count == 0 && items.count > 0 {
                delegate?.onReceivedFirstItem()
            }
        }
    }

    public var nextItems: [T] {
        return currentIndex == -1 || currentIndex == items.count - 1
            ? []
            : Array(items[currentIndex + 1..<items.count])
    }

    public var previousItems: [T] {
        return currentIndex <= 0
            ? []
            : Array(items[0..<currentIndex])
    }

    /**
     The current item for the queue.
     */
    public var current: T? {
        get {
            return currentIndex == -1 ? nil : items[currentIndex]
        }
    }

    /**
     The index of the current item. `-1` when there is no current item
     */
    private(set) var currentIndex: Int = -1
    private func throwIfQueueEmpty() throws {
        if items.count == 0 {
            throw AudioPlayerError.QueueError.empty
        }
    }

    private func throwIfIndexInvalid(
        index: Int,
        name: String = "index",
        min: Int? = nil,
        max: Int? = nil
    ) throws {
        guard index >= (min ?? 0) && (max ?? items.count) > index else {
            throw AudioPlayerError.QueueError.invalidIndex(
                index: index,
                message: "\(name.prefix(1).uppercased() + name.dropFirst())) has to be positive and smaller than the count of current items (\(items.count))"
            )
        }
    }

    private func mutateCurrentIndex(index: Int) {
        if (index == currentIndex) { return }
        currentIndex = index
        delegate?.onCurrentItemChanged()
    }

    /**
     Add a single item to the queue.

     - parameter item: The `AudioItem` to be added.
     */
    public func add(_ item: T) {
        items.append(item)
    }

    /**
     Add an array of items to the queue.

     - parameter items: The `AudioItem`s to be added.
     */
    public func add(_ items: [T]) {
        if (items.count == 0) { return }
        self.items.append(contentsOf: items)
    }

    /**
     Add an array of items to the queue at a given index.

     - parameter items: The `AudioItem`s to be added.
     - parameter at: The index to insert the items at.
     */
    public func add(_ items: [T], at index: Int) throws {
        if (items.count == 0) { return }
        guard index >= 0 && self.items.count >= index else {
            throw AudioPlayerError.QueueError.invalidIndex(index: index, message: "Index to insert at has to be non-negative and equal to or smaller than the number of items: (\(items.count))")
        }
        // Correct index when items were inserted in front of it:
        if (self.items.count > 1 && currentIndex >= index) {
            currentIndex += items.count
        }
        self.items.insert(contentsOf: items, at: index)
    }

    internal enum SkipDirection : Int {
        case next = 1
        case previous = -1
    }

    private func skip(direction: SkipDirection, wrap: Bool) -> T? {
        if (items.count > 0) {
            var index = currentIndex + direction.rawValue
            if (wrap) {
                index = (items.count + index) % items.count;
            }
            mutateCurrentIndex(index: max(0, min(items.count - 1, index)))
        }
        return current
    }

    /**
     Makes the next item in the queue active, or the last item when already at the end of the queue. When wrap is true and at the end of the queue, the first track in the queue is made active.
     - parameter wrap: Whether to wrap to the start of the queue
     - returns: The next (or current) item.
     */
    @discardableResult
    public func next(wrap: Bool = false) -> T? {
        return skip(direction: SkipDirection.next, wrap: wrap);
    }

    /**
     Makes the previous item in the queue active, or the first item when already at the start of the queue. When wrap is true and at the start of the queue, the last track in the queue is made active.

     - parameter wrap: Whether to wrap to the end of the queue
     - returns: The previous item.
     */
    @discardableResult
    public func previous(wrap: Bool = false) -> T? {
        return skip(direction: SkipDirection.previous, wrap: wrap);
    }

    /**
     Jump to a position in the queue.
     Will update the current item.

     - parameter index: The index to jump to.
     - throws: `APError.QueueError`
     - returns: The item at the index.
     */
    @discardableResult
    func jump(to index: Int) throws -> T {
        try throwIfQueueEmpty();
        try throwIfIndexInvalid(index: index)

        mutateCurrentIndex(index: index)
        return current!
    }

    /**
     Move an item in the queue.

     - parameter fromIndex: The index of the item to be moved.
     - parameter toIndex: The index to move the item to. If the index is larger than the size of the queue, the item is moved to the end of the queue instead.
     - throws: `APError.QueueError`
     */
    func moveItem(fromIndex: Int, toIndex: Int) throws {
        try throwIfQueueEmpty();
        try throwIfIndexInvalid(index: fromIndex, name: "fromIndex")
        try throwIfIndexInvalid(index: toIndex, name: "toIndex", max: Int.max)

        let item = items.remove(at: fromIndex)
        self.items.insert(item, at: min(items.count, toIndex));
        if (fromIndex == currentIndex) {
            currentIndex = toIndex;
        }
    }

    /**
     Remove an item.

     - parameter index: The index of the item to remove.
     - throws: APError.QueueError
     - returns: The removed item.
     */
    @discardableResult
    public func removeItem(at index: Int) throws -> T {
        try throwIfQueueEmpty()
        try throwIfIndexInvalid(index: index)
        let result = items.remove(at: index)

        mutateCurrentIndex(index: index == currentIndex && items.count > 0
           ? currentIndex % items.count : -1
        )

        return result;
    }

    /**
     Replace the current item with a new one. If there is no current item, it is equivalent to calling `add(item:)`, `jump(to: itemIndex)`.

     - parameter item: The item to set as the new current item.
     */
    public func replaceCurrentItem(with item: T) {
        if currentIndex == -1  {
            add(item)
            mutateCurrentIndex(index: items.count - 1)
        } else {
            items[currentIndex] = item
            delegate?.onCurrentItemChanged()
        }
    }

    /**
     Remove all previous items in the queue.
     If no previous items exist, no action will be taken.
     */
    public func removePreviousItems() {
        if (items.count == 0) { return };
        guard currentIndex > 0 else { return }
        items.removeSubrange(0..<currentIndex)
        currentIndex = 0
    }

    /**
     Remove upcoming items.
     If no upcoming items exist, no action will be taken.
     */
    public func removeUpcomingItems() {
        if (items.count == 0) { return };
        let nextIndex = currentIndex + 1
        guard nextIndex < items.count else { return }
        items.removeSubrange(nextIndex..<items.count)
    }

    /**
     Removes all items for queue
     */
    public func clearQueue() {
        let itemWasNil = currentIndex == -1;
        currentIndex = -1
        items.removeAll()
        if (!itemWasNil) {
            delegate?.onCurrentItemChanged()
        }
    }

}
