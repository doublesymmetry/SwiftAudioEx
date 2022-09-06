import Quick
import Nimble

@testable import SwiftAudioEx


class QueueManagerTests: QuickSpec {
    
    let dummyItem = 0
    
    let dummyItems: [Int] = [0, 1, 2, 3, 4, 5, 6]
    
    override func spec() {
        
        describe("A QueueManager") {
            
            var queue: QueueManager<Int>!
            
            beforeEach {
                queue = QueueManager()
            }
            
            describe("its current item") {
                
                it("should be nil starting out") {
                    expect(queue.current).to(beNil())
                }
                
                context("when one item is added") {
                    beforeEach {
                        queue.add(self.dummyItem)
                    }
                    
                    it("should be nil, because it wasn't jumped to") {
                        expect(queue.current).to(beNil())
                    }

                    context("after being jumped to") {
                        beforeEach {
                            try! queue.jump(to: 0)
                        }
                    
                        it("should be the added item") {
                            expect(queue.current).to(equal(self.dummyItem))
                        }
                        
                        context("then replaced") {
                            beforeEach {
                                queue.replaceCurrentItem(with: 1)
                            }
                            it("should be the new item") {
                                expect(queue.current).to(equal(1))
                            }
                        }
                    }
                }
                
                context("when replacing the current item when the queue is still empty") {
                    beforeEach {
                        queue.replaceCurrentItem(with: 1)
                    }
                    
                    it("the current item should be the replaced item") {
                        expect(queue.current).toNot(beNil())
                    }
                }
                
                context("when multiple items are added and the last is jumped to") {
                    beforeEach {
                        queue.add(self.dummyItems)
                        try! queue.jump(to: queue.items.count - 1)
                    }
                    
                    it("should not be nil") {
                        expect(queue.current).toNot(beNil())
                    }
                }
                
            }

            describe("when adding at index") {
                context("adding item at index 0 when queue is empty") {
                    beforeEach {
                        try! queue.add([3], at: 0)
                    }
                    it("should add element successfully") {
                        expect(queue.items.first).to(equal(3))
                    }
                    it("should not set currentItem") {
                        expect(queue.current).to(beNil())
                    }
                    it("should not set currentIndex") {
                        expect(queue.currentIndex).to(equal(-1))
                    }
                }

                context("adding item at index and jumping to the first item") {
                    beforeEach {
                        queue.add([1, 2])
                        try! queue.jump(to: 0)
                    }

                    context("adding item at current [element count]") {
                        it("should add element successfully") {
                            try queue.add([3, 4, 5], at: queue.items.count)
                            expect(queue.items.last).to(equal(5))
                        }

                        context("before the first item") {
                            it("should add element successfully") {
                                try queue.add([-1], at: 0)
                                expect(queue.items.first).to(equal(-1))
                            }
                        }

                        context("after the last item") {
                            it("should add element successfully") {
                                try queue.add([6], at: queue.items.count)
                                expect(queue.items.last).to(equal(6))
                            }
                        }
                    }

                    context("calling next, causing currentIndex to become 1, then adding at index 1") {
                        beforeEach {
                            try! queue.next()
                            try! queue.add([5], at: queue.currentIndex)
                        }
                        it("should cause the current item to be shifted to index 2") {
                            expect(queue.current).to(equal(2))
                            expect(queue.currentIndex).to(equal(2))
                        }
                    }
                }
            }
            
            context("when adding one item but not jumping to it yet") {
                
                beforeEach {
                    queue.add(0)
                }
                
                it("should have an item in the queue") {
                    expect(queue.items.count).to(equal(1))
                }
                
                context("then replacing the item") {
                    beforeEach {
                        queue.replaceCurrentItem(with: 1)
                    }
                    it("should have added an item and jumped to it") {
                        expect(queue.current).to(equal(1))
                        expect(queue.currentIndex).to(equal(1))
                    }
                }
                
                context("then calling next") {
                    var error: Error?
                    var item: Int?
                    beforeEach {
                        do {
                            item = try queue.next()
                        }
                        catch let err {
                            error = err
                        }
                    }
                    
                    it("should throw, because there was no currentItem") {
                        expect(error).toNot(beNil())
                        expect(item).to(beNil())
                    }
                }

                context("then calling previous") {
                    var error: Error?
                    var item: Int?
                    beforeEach {
                        do {
                            item = try queue.previous()
                        }
                        catch let err {
                            error = err
                        }
                    }
                    
                    it("should throw, because there was no currentItem") {
                        expect(error).toNot(beNil())
                        expect(item).to(beNil())
                    }
                }
                
                context("then jumping to 0 and calling next(wrap: true)") {
                    
                    var nextIndex: Int?
                    
                    beforeEach {
                        try! queue.jump(to: 0)
                        nextIndex = try! queue.next(wrap: true)
                    }
                    
                    it("should wrap to itself") {
                        expect(nextIndex).to(equal(0))
                    }

                }
                
                context("then jumping to 0 and then calling previous(wrap: true") {
                    var previousIndex: Int?
                    
                    beforeEach {
                        try! queue.jump(to: 0)
                        previousIndex = try? queue.previous(wrap: true)
                    }
                    
                    it("should wrap to itself") {
                        expect(previousIndex).to(equal(0))
                    }
                }
                
            }
            
            context("when adding multiple items") {
                
                beforeEach {
                    queue.add([0, 1, 2, 3, 4, 5, 6])
                }
                
                it("should have items in the queue") {
                    expect(queue.items.count).to(equal(7))
                }
                
                it("the current item should be nil") {
                    expect(queue.current).to(beNil())
                }
                
                it("should not have next items") {
                    expect(queue.nextItems.count).to(equal(0))
                }
                
                context("when jumping to first item") {
                    beforeEach {
                        try! queue.jump(to: 0)
                    }
                    context("then calling next") {
                        var nextItem: Int?
                        beforeEach {
                            nextItem = try? queue.next()
                        }
                        
                        it("should return the next item") {
                            expect(nextItem).toNot(beNil())
                            expect(nextItem).to(equal(self.dummyItems[1]))
                        }
                        
                        it("should have next current item") {
                            expect(queue.current).to(equal(self.dummyItems[1]))
                        }
                        
                        it("should have previous items") {
                            expect(queue.previousItems).toNot(beNil())
                        }
                                            
                        context("then calling previous") {
                            var index: Int?
                            beforeEach {
                                index = try? queue.previous()
                            }
                            it("should return the first item") {
                                expect(index).to(equal(0))
                            }
                            it("should have the previous current item") {
                                expect(queue.current).to(equal(self.dummyItems.first))
                            }
                            context("then calling previous at the start of the queue") {
                                var index: Int?
                                beforeEach {
                                    index = try? queue.previous()
                                }
                                it("should return nil because an error was thrown") {
                                    expect(index).to(beNil())
                                }
                            }
                            context("then calling previous(wrap: true)") {
                                var index: Int?
                                beforeEach {
                                    index = try? queue.previous(wrap: true)
                                }
                                it("should return the last item") {
                                    expect(index).to(equal(queue.items.count - 1))
                                    expect(queue.currentIndex).to(equal(queue.items.count - 1))
                                    expect(queue.current).to(equal(self.dummyItems.last))
                                }

                                context("then calling next again at the end of the queue") {
                                    var index: Int?
                                    beforeEach {
                                        index = try? queue.next()
                                    }
                                    it("should return nil because an error was thrown") {
                                        expect(index).to(beNil())
                                    }
                                }

                                context("then calling next(wrap: true)") {
                                    var index: Int?
                                    beforeEach {
                                        index = try? queue.next(wrap: true)
                                    }
                                    it("should return the first item") {
                                        expect(index).to(equal(0))
                                        expect(queue.currentIndex).to(equal(0))
                                        expect(queue.current).to(equal(self.dummyItems.first))
                                    }
                                }
                            }
                        }
                        
                        context("then removing previous items") {
                            beforeEach {
                                queue.removePreviousItems()
                            }
                            it("should have no previous items") {
                                expect(queue.previousItems.count).to(equal(0))
                            }
                            it("should have current index zero") {
                                expect(queue.currentIndex).to(equal(0))
                            }
                        }
                    }
                
                    context("adding more items") {
                        var initialItemCount: Int!
                        let newItems: [Int] = [10, 11, 12, 13]
                        beforeEach {
                            initialItemCount = queue.items.count
                            try? queue.add(newItems, at: queue.items.endIndex - 1)
                        }
                        
                        it("should have more items") {
                            expect(queue.items.count).to(equal(initialItemCount + newItems.count))
                        }
                    }
                    
                    context("adding more items at a smaller index than currentIndex") {
                        var initialCurrentIndex: Int!
                        let newItems: [Int] = [10, 11, 12, 13]
                        beforeEach {
                            initialCurrentIndex = queue.currentIndex
                            try? queue.add(newItems, at: initialCurrentIndex)
                        }
                        
                        it("currentIndex should increase by number of new items") {
                            expect(queue.currentIndex).to(equal(initialCurrentIndex + newItems.count))
                        }
                    }
                    
                    // MARK: - Removal
                    
                    context("then removing a item with index less than currentIndex") {
                        beforeEach {
                            var removed: Int?
                            var initialCurrentIndex: Int!
                            beforeEach {
                                let _ = try? queue.jump(to: 3)
                                initialCurrentIndex = queue.currentIndex
                                removed = try? queue.removeItem(at: initialCurrentIndex - 1)
                            }
                            
                            it("should remove an item") {
                                expect(removed).toNot(beNil())
                            }
                            
                            it("should decrement the currentIndex") {
                                expect(queue.currentIndex).to(equal(initialCurrentIndex - 1))
                            }
                        }
                    }
                    
                    context("then removing the second item") {
                        var removed: Int?
                        beforeEach {
                            removed = try? queue.removeItem(at: 1)
                        }
                        
                        it("should have one less item") {
                            expect(removed).toNot(beNil())
                            expect(queue.items.count).to(equal(self.dummyItems.count - 1))
                        }
                    }
                    
                    context("then removing the last item") {
                        var removed: Int?
                        beforeEach {
                            removed = try? queue.removeItem(at: self.dummyItems.count - 1)
                        }
                        
                        it("should have one less item") {
                            expect(removed).toNot(beNil())
                            expect(queue.items.count).to(equal(self.dummyItems.count - 1))
                        }
                    }
                    
                    context("then removing the current item when it is the first item") {
                        var removed: Int?
                        beforeEach {
                            removed = try? queue.removeItem(at: queue.currentIndex)
                        }
                        it("should remove the current item") {
                            expect(removed).toNot(beNil())
                            expect(queue.items.count).to(equal(self.dummyItems.count - 1))
                            expect(queue.currentIndex).to(equal(-1))
                            expect(queue.current).to(beNil())
                        }
                    }

                    context("then removing the current item when it is the last item") {
                        var removed: Int?
                        beforeEach {
                            try! queue.jump(to: queue.items.count - 1);
                            removed = try? queue.removeItem(at: queue.currentIndex)
                        }
                        it("should remove the current item") {
                            expect(removed).toNot(beNil())
                            expect(queue.items.count).to(equal(self.dummyItems.count - 1))
                            expect(queue.currentIndex).to(equal(-1))
                        }

                    }

                    context("then removing with too large index") {
                        var removed: Int?
                        beforeEach {
                            removed = try? queue.removeItem(at: self.dummyItems.count)
                        }

                        it("should not remove any items") {
                            expect(removed).to(beNil())
                            expect(queue.items.count).to(equal(self.dummyItems.count))
                        }
                    }
                    
                    context("then removing with too small index") {
                        var removed: Int?
                        beforeEach {
                            removed = try? queue.removeItem(at: -1)
                        }
                        
                        it("should not remove any items") {
                            expect(removed).to(beNil())
                            expect(queue.items.count).to(equal(self.dummyItems.count))
                        }
                    }
                    
                    context("then removing upcoming items") {
                        beforeEach {
                            queue.removeUpcomingItems()
                        }
                        
                        it("should have no next items") {
                            expect(queue.nextItems.count).to(equal(0))
                        }
                    }
                    
                    // MARK: - Jumping
                    
                    context("then jumping to the current item") {
                        var error: Error?
                        var item: Int?
                        beforeEach {
                            do {
                                item = try queue.jump(to: queue.currentIndex)
                            }
                            catch let err {
                                error = err
                            }
                        }
                        
                        it("should return an item") {
                            expect(item).toNot(beNil())
                        }
                        
                        it("should not throw an error") {
                            expect(error).to(beNil())
                        }
                    }
                    
                    context("then jumping to the second item") {
                        var jumped: Int?
                        beforeEach {
                            try? jumped = queue.jump(to: 1)
                        }
                        
                        it("should return the current item") {
                            expect(jumped).toNot(beNil())
                            expect(jumped).to(equal(queue.current))
                        }
                        
                        it("should move the current index") {
                            expect(queue.currentIndex).to(equal(1))
                        }
                    }
                    
                    context("then jumping to last item") {
                        var jumped: Int?
                        beforeEach {
                            try? jumped = queue.jump(to: queue.items.count - 1)
                        }
                        it("should return the current item") {
                            expect(jumped).toNot(beNil())
                            expect(jumped).to(equal(queue.current))
                        }
                        
                        it("should move the current index") {
                            expect(queue.currentIndex).to(equal(queue.items.count - 1))
                        }
                    }
                    
                    context("then jumping to a negative index") {
                        var jumped: Int?
                        beforeEach {
                            jumped = try? queue.jump(to: -1)
                        }
                        
                        it("should not return") {
                            expect(jumped).to(beNil())
                        }
                        
                        it("should not move the current index") {
                            expect(queue.currentIndex).to(equal(0))
                        }
                    }
                    
                    context("then jumping with too large index") {
                        var jumped: Int?
                        beforeEach {
                            jumped = try? queue.jump(to: queue.items.count)
                        }
                        it("should not return") {
                            expect(jumped).to(beNil())
                        }
                        
                        it("should not move the current index") {
                            expect(queue.currentIndex).to(equal(0))
                        }
                    }
                    
                    // MARK: - Moving
                    
                    context("moving the current item up one") {
                        var error: Error?
                        beforeEach {
                            do {
                                try queue.moveItem(fromIndex: queue.currentIndex, toIndex: queue.currentIndex + 1)
                            }
                            catch let err { error = err }
                        }
                        
                        it("should not throw an error") {
                            expect(error).to(beNil())
                        }
                        it("should change currentIndex") {
                            expect(queue.currentIndex).to(equal(1))
                        }

                    }
                    
                    context("moving from a negative index") {
                        var error: Error?
                        beforeEach {
                            do {
                                try queue.moveItem(fromIndex: -1, toIndex: queue.currentIndex + 1)
                            }
                            catch let err { error = err }
                        }
                        
                        it("should throw an error") {
                            expect(error).toNot(beNil())
                        }
                    }
                    
                    context("moving from a too large index") {
                        var error: Error?
                        beforeEach {
                            do {
                                try queue.moveItem(fromIndex: queue.items.count, toIndex: queue.currentIndex + 1)
                            }
                            catch let err { error = err }
                        }
                        
                        it("should throw an error") {
                            expect(error).toNot(beNil())
                        }
                    }
                    
                    context("moving to a negative index") {
                        var error: Error?
                        beforeEach {
                            do {
                                try queue.moveItem(fromIndex: queue.currentIndex + 1, toIndex: -1)
                            }
                            catch let err { error = err }
                        }
                        
                        it("should throw an error") {
                            expect(error).toNot(beNil())
                        }
                    }
                    
                    context("moving to a too large index") {
                        var error: Error?
                        beforeEach {
                            do {
                                try queue.moveItem(fromIndex: queue.currentIndex + 1, toIndex: queue.items.count)
                            }
                            catch let err { error = err }
                        }
                        
                        it("should throw an error") {
                            expect(error).toNot(beNil())
                        }
                    }
                    
                    context("then moving 2nd to 4th") {
                        let afterMoving: [Int] = [0, 2, 3, 1, 4, 5, 6]
                        beforeEach {
                            try? queue.moveItem(fromIndex: 1, toIndex: 3)
                        }
                        
                        it("should move the item") {
                            expect(queue.items).to(equal(afterMoving))
                        }
                    }
                    
                    // MARK: - Clear
                    
                    context("when queue is cleared") {
                        beforeEach {
                            queue.clearQueue()
                        }
                        
                        it("should have currentIndex -1") {
                            expect(queue.currentIndex).to(equal(-1))
                        }
                        
                        it("should have no items") {
                            expect(queue.items.count).to(equal(0))
                        }
                    }
                }
            }
        }
    }
}
