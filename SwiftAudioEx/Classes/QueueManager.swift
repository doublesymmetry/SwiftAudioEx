//
//  QueueManager.swift
//  SwiftAudio
//
//  Created by Jørgen Henrichsen on 24/03/2018.
//

import Foundation

protocol QueueManagerDelegate: AnyObject {
    func onReceivedFirstItem()
    func onCurrentIndexChanged(oldIndex: Int, newIndex: Int)
}

class QueueManager<T> {

    weak var delegate: QueueManagerDelegate? = nil

    /**
     All items held by the queue.
     */
    private(set) var items: [T] = [] {
        didSet {
            if oldValue.count == 0 && items.count > 0 && currentIndex == 0 {
                delegate?.onReceivedFirstItem()
            }
        }
    }

    public var nextItems: [T] {
        guard currentIndex + 1 < items.count else {
            return []
        }
        return Array(items[currentIndex + 1..<items.count])
    }

    public var previousItems: [T] {
        if (currentIndex == 0) {
            return []
        }
        return Array(items[0..<currentIndex])
    }

    /**
     The index of the current item.
     Will be populated event though there is no current item (When the queue is empty).
     */
    private(set) var currentIndex: Int = 0 {
        didSet {
            delegate?.onCurrentIndexChanged(oldIndex: oldValue, newIndex: currentIndex)
        }
    }

    /**
     The current item for the queue.
     */
    public var current: T? {
        if items.count > currentIndex {
            return items[currentIndex]
        }
        return nil
    }

    /**
     Add a single item to the queue.

     - parameter item: The `AudioItem` to be added.
     */
    public func addItem(_ item: T) {
        items.append(item)
    }

    /**
     Add an array of items to the queue.

     - parameter items: The `AudioItem`s to be added.
     */
    public func addItems(_ items: [T]) {
        self.items.append(contentsOf: items)
    }

    /**
     Add an array of items to the queue at a given index.

     - parameter items: The `AudioItem`s to be added.
     - parameter at: The index to insert the items at.
     */
    public func addItems(_ items: [T], at index: Int) throws {
        guard index >= 0 && self.items.count >= index else {
            throw APError.QueueError.invalidIndex(index: index, message: "Index to insert at has to be non-negative and equal to or smaller than the number of items: (\(items.count))")
        }

        self.items.insert(contentsOf: items, at: index)

        if (currentIndex >= index && self.items.count != 1) { currentIndex += items.count }
    }

    internal enum SkipDirection : Int {
        case next = 1
        case previous = -1
    }
    
    private func skip(direction: SkipDirection, wrap: Bool) throws -> T {
        var index = currentIndex + direction.rawValue
        if (wrap) {
            index = (items.count + index) % items.count;
        }
        guard items.count > index else {
            throw APError.QueueError.noNextItem
        }
        guard index >= 0 else {
            throw APError.QueueError.noPreviousItem
        }
        currentIndex = index
        return items[index]
    }

    /**
     Get the next item in the queue, if there are any.
     Will update the current item.

     - throws: `APError.QueueError`
     - returns: The next item.
     */
    @discardableResult
    public func next(wrap: Bool = false) throws -> T {
        return try skip(direction: SkipDirection.next, wrap: wrap);
    }

    /**
     Get the previous item in the queue, if there are any.
     Will update the current item.

     - throws: `APError.QueueError`
     - returns: The previous item.
     */
    @discardableResult
    public func previous(wrap: Bool = false) throws -> T {
        return try skip(direction: SkipDirection.previous, wrap: wrap);
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
        guard index != currentIndex else {
            throw APError.QueueError.invalidIndex(index: index, message: "Cannot jump to the current item")
        }

        guard index >= 0 && items.count > index else {
            throw APError.QueueError.invalidIndex(index: index, message: "The jump index has to be positive and smaller thant the count of current items (\(items.count))")
        }

        currentIndex = index
        return items[index]
    }

    /**
     Move an item in the queue.

     - parameter fromIndex: The index of the item to be moved.
     - parameter toIndex: The index to move the item to.
     - throws: `APError.QueueError`
     */
    func moveItem(fromIndex: Int, toIndex: Int) throws {
        guard fromIndex != currentIndex else {
            throw APError.QueueError.invalidIndex(index: fromIndex, message: "The fromIndex cannot be equal to the current index.")
        }

        guard fromIndex >= 0 && fromIndex < items.count else {
            throw APError.QueueError.invalidIndex(index: fromIndex, message: "The fromIndex has to be positive and smaller than the count of current items (\(items.count)).")
        }

        guard toIndex >= 0 && toIndex < items.count else {
            throw APError.QueueError.invalidIndex(index: toIndex, message: "The toIndex has to be positive and smaller than the count of current items (\(items.count)).")
        }

        let item = try removeItem(at: fromIndex)
        try addItems([item], at: toIndex)
    }

    /**
     Remove an item.

     - parameter index: The index of the item to remove.
     - throws: APError.QueueError
     - returns: The removed item.
     */
    @discardableResult
    public func removeItem(at index: Int) throws -> T {
        guard index != currentIndex else {
            throw APError.QueueError.invalidIndex(index: index, message: "Cannot remove the current item!")
        }

        guard index >= 0 && items.count > index else {
            throw APError.QueueError.invalidIndex(index: index, message: "Index for removal has to be positive and smaller than the count of current items (\(items.count)).")
        }

        if index < currentIndex {
            currentIndex -= 1
        }

        return items.remove(at: index)
    }

    /**
     Replace the current item with a new one. If there is no current item, it is equivalent to calling add(item:).

     - parameter item: The item to set as the new current item.
     */
    public func replaceCurrentItem(with item: T) {
        if current == nil  {
            addItem(item)
        }

        items[currentIndex] = item
    }

    /**
     Remove all previous items in the queue.
     If no previous items exist, no action will be taken.
     */
    public func removePreviousItems() {
        guard currentIndex > 0 else { return }
        items.removeSubrange(0..<currentIndex)
        currentIndex = 0
    }

    /**
     Remove upcoming items.
     If no upcoming items exist, no action will be taken.
     */
    public func removeUpcomingItems() {
        let nextIndex = currentIndex + 1
        guard nextIndex < items.count else { return }
        items.removeSubrange(nextIndex..<items.count)
    }

    /**
     Removes all items for queue
     */
    public func clearQueue() {
        currentIndex = 0
        items.removeAll()
    }

}
