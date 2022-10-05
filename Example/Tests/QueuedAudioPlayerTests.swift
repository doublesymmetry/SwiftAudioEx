import Quick
import Nimble
import Foundation

@testable import SwiftAudioEx
import AVFoundation

extension QueuedAudioPlayer {
    class SeekEventListener {
        var eventResult: (Double, Bool) = (-1, false)
        func handleEvent(seconds: Double, didFinish: Bool) { eventResult = (seconds, didFinish) }
    }

    func seekWithExpectation(to time: Double) {
        let seekEventListener = SeekEventListener()
        event.seek.addListener(seekEventListener, seekEventListener.handleEvent)

        seek(to: time)
        expect(seekEventListener.eventResult).toEventually(equal((time, true)))
    }
}

class QueuedAudioPlayerTests: QuickSpec {
    override func spec() {
        describe("A QueuedAudioPlayer") {
            var audioPlayer: QueuedAudioPlayer!
            beforeEach {
                audioPlayer = QueuedAudioPlayer()
                audioPlayer.volume = 0.0
            }
            describe("its current item") {
                it("should be nil") {
                    expect(audioPlayer.currentItem).to(beNil())
                }

                context("when adding one item") {
                    var fiveSecondItem: AudioItem!
                    var item: AudioItem!
                    beforeEach {
                        fiveSecondItem = FiveSecondSource.getAudioItem()
                        item = Source.getAudioItem()
                        try? audioPlayer.add(item: fiveSecondItem)
                    }
                    it("should not be nil") {
                        expect(audioPlayer.currentItem).toNot(beNil())
                    }

                    context("then loading a new item") {
                        beforeEach {
                            audioPlayer.load(item: item)
                        }

                        it("should have replaced the item") {
                            expect(
                                audioPlayer.currentItem?.getSourceUrl()
                            ).to(
                                equal(item.getSourceUrl())
                            )
                        }
                    }

                    context("then removing it again") {
                        beforeEach {
                            audioPlayer.repeatMode = RepeatMode.track;
                            audioPlayer.play();
                            audioPlayer.seek(to: 4);
                            try? audioPlayer.removeItem(at: audioPlayer.currentIndex);
                        }
                        
                        it("should have made the currentItem nil") {
                            expect(audioPlayer.currentItem).to(beNil())
                        }

                        it("should make the player be idle") {
                            expect(audioPlayer.playerState).to(equal(AudioPlayerState.idle))
                        }

                        context("then loading a new item") {
                            beforeEach {
                                audioPlayer.load(item: Source.getAudioItem())
                            }
                            
                            it("should have set the item") {
                                expect(audioPlayer.currentItem?.getSourceUrl()).toNot(equal(fiveSecondItem.getSourceUrl()))
                            }
                            it("should have started loading") {
                                expect(audioPlayer.playerState).toEventually(equal(AudioPlayerState.loading))
                            }
                            it("should have started playing") {
                                expect(audioPlayer.playerState).toEventually(equal(AudioPlayerState.playing))
                            }
                        }
                    }
                }

                context("when adding multiple items") {
                    beforeEach {
                        try? audioPlayer.add(items: [FiveSecondSource.getAudioItem(), FiveSecondSource.getAudioItem()], playWhenReady: false)
                    }
                    it("should not be nil") {
                        expect(audioPlayer.currentItem).toNot(beNil())
                    }
                }
            }

            describe("its next items") {
                it("should be empty") {
                    expect(audioPlayer.nextItems.count).to(equal(0))
                }

                context("when adding 2 items") {
                    beforeEach {
                        try? audioPlayer.add(items: [Source.getAudioItem(), Source.getAudioItem()])
                    }
                    it("should contain 1 item") {
                        expect(audioPlayer.nextItems.count).to(equal(1))
                    }

                    context("then calling next()") {
                        beforeEach {
                            audioPlayer.next()
                        }
                        it("should contain 0 items") {
                            expect(audioPlayer.nextItems.count).to(equal(0))
                        }

                        context("then calling previous()") {
                            beforeEach {
                                audioPlayer.previous()
                            }
                            it("should contain 1 item") {
                                expect(audioPlayer.nextItems.count).to(equal(1))
                            }
                        }
                    }

                    context("then removing one item") {
                        beforeEach {
                            try? audioPlayer.removeItem(at: 1)
                        }

                        it("should be empty") {
                            expect(audioPlayer.nextItems.count).to(equal(0))
                        }
                    }

                    context("then jumping to the last item") {
                        beforeEach {
                            try? audioPlayer.jumpToItem(atIndex: 1)
                        }
                        it("should be empty") {
                            expect(audioPlayer.nextItems.count).to(equal(0))
                        }
                    }

                    context("then removing upcoming items") {
                        beforeEach {
                            audioPlayer.removeUpcomingItems()
                        }

                        it("should be empty") {
                            expect(audioPlayer.nextItems.count).to(equal(0))
                        }
                    }

                    context("then stopping") {
                        beforeEach {
                            audioPlayer.stop()
                        }

                        it("should be empty") {
                            expect(audioPlayer.nextItems.count).to(equal(0))
                        }
                    }
                }
            }

            describe("its previous items") {
                it("should be empty") {
                    expect(audioPlayer.previousItems.count).to(equal(0))
                }

                context("when adding 2 items") {
                    beforeEach {
                        try? audioPlayer.add(items: [FiveSecondSource.getAudioItem(), FiveSecondSource.getAudioItem()])
                    }

                    it("should be empty") {
                        expect(audioPlayer.previousItems.count).to(equal(0))
                    }

                    context("then calling next()") {
                        beforeEach {
                            audioPlayer.next()
                        }
                        it("should contain one item") {
                            expect(audioPlayer.previousItems.count).to(equal(1))
                        }
                    }

                    context("then removing all previous items") {
                        beforeEach {
                            audioPlayer.removePreviousItems()
                        }

                        it("should be empty") {
                            expect(audioPlayer.previousItems.count).to(equal(0))
                        }
                    }

                    context("then stopping") {
                        beforeEach {
                            audioPlayer.stop()
                        }

                        it("should be empty") {
                            expect(audioPlayer.previousItems.count).to(equal(0))
                        }
                    }

                }
            }

            describe("onNext") {
                context("player was playing") {
                    beforeEach {
                        try? audioPlayer.add(items: [FiveSecondSource.getAudioItem(), FiveSecondSource.getAudioItem()])
                    }

                    context("then calling next()") {
                        beforeEach {
                            audioPlayer.next()
                        }

                        it("should go to next item and play") {
                            expect(audioPlayer.nextItems.count).toEventually(equal(0))
                            expect(audioPlayer.currentIndex).toEventually(equal(1))
                            expect(audioPlayer.playerState).toEventually(equal(AudioPlayerState.playing))
                        }
                    }
                }
                context("player was paused") {
                    beforeEach {
                        try? audioPlayer.add(items: [FiveSecondSource.getAudioItem(), FiveSecondSource.getAudioItem()])
                        audioPlayer.pause()

                    }

                    context("then calling next()") {
                        beforeEach {
                            audioPlayer.next()
                        }

                        it("should go to next item and not play") {
                            expect(audioPlayer.nextItems.count).toEventually(equal(0))
                            expect(audioPlayer.currentIndex).toEventually(equal(1))
                            expect(audioPlayer.playerState).toEventually(equal(AudioPlayerState.ready))
                        }
                    }
                }
            }

            describe("onPrevious") {
                context("player was playing") {
                    beforeEach {
                        try? audioPlayer.add(items: [FiveSecondSource.getAudioItem(), FiveSecondSource.getAudioItem()], playWhenReady: true)
                        audioPlayer.next()
                    }

                    context("then calling previous()") {
                        beforeEach {
                            audioPlayer.previous()
                        }

                        it("should go to previous item and play") {
                            expect(audioPlayer.nextItems.count).toEventually(equal(1))
                            expect(audioPlayer.previousItems.count).toEventually(equal(0))
                            expect(audioPlayer.currentIndex).toEventually(equal(0))
                            expect(audioPlayer.playerState).toEventually(equal(AudioPlayerState.playing))
                        }
                    }
                }
                context("player was paused") {
                    beforeEach {
                        try? audioPlayer.add(items: [FiveSecondSource.getAudioItem(), FiveSecondSource.getAudioItem()])
                        audioPlayer.next()
                        audioPlayer.pause()

                    }

                    context("then calling previous()") {
                        beforeEach {
                            audioPlayer.previous()
                        }

                        it("should go to previous item and not play") {
                            expect(audioPlayer.nextItems.count).toEventually(equal(1))
                            expect(audioPlayer.previousItems.count).toEventually(equal(0))
                            expect(audioPlayer.currentIndex).toEventually(equal(0))
                            expect(audioPlayer.playerState).toEventually(equal(AudioPlayerState.ready))
                        }
                    }
                }
            }

            class CurrentItemEventListener {
                var item: AudioItem? = nil
                var index: Int? = nil
                var lastItem: AudioItem? = nil
                var lastIndex: Int? = nil
                var lastPosition: Double? = nil
                func handleEvent(
                    item: AudioItem?,
                    index: Int?,
                    lastItem: AudioItem?,
                    lastIndex: Int?,
                    lastPosition: Double?
                ) {
                    self.item = item
                    self.index = index
                    self.lastItem = lastItem
                    self.lastIndex = lastIndex
                    self.lastPosition = lastPosition
                }
            }

            describe("its repeat mode") {
                context("when adding 2 items") {
                    beforeEach {
                        audioPlayer.play()
                        try? audioPlayer.add(items: [FiveSecondSource.getAudioItem(), FiveSecondSource.getAudioItem()])
                    }

                    context("then setting repeat mode off") {
                        beforeEach {
                            audioPlayer.repeatMode = .off
                        }

                        context("allow playback to end normally") {
                            beforeEach {
                                audioPlayer.seekWithExpectation(to: 4.95)
                            }

                            it("should move to next item") {
                                let currentItemEventListener = CurrentItemEventListener()

                                audioPlayer.event.currentItem.addListener(currentItemEventListener, currentItemEventListener.handleEvent)

                                expect(audioPlayer.nextItems.count).toEventually(equal(0))
                                expect(audioPlayer.currentIndex).toEventually(equal(1))
                                expect(audioPlayer.playerState).toEventually(equal(AudioPlayerState.playing))
                                expect(currentItemEventListener.lastIndex).toEventually(equal(1))
                            }

                            context("allow playback to end again") {
                                beforeEach {
                                    audioPlayer.seekWithExpectation(to: 4.95)
                                }

                                it("should stop playback normally") {
                                    let eventListener = CurrentItemEventListener()
                                    audioPlayer.event.currentItem.addListener(eventListener, eventListener.handleEvent)

                                    expect(audioPlayer.nextItems.count).toEventually(equal(0))
                                    expect(audioPlayer.currentIndex).toEventually(equal(1))
                                    audioPlayer.seekWithExpectation(to: 4.95)
                                    expect(audioPlayer.playerState).toEventually(equal(AudioPlayerState.paused))
                                    expect(eventListener.lastIndex).toEventually(equal(1))
                                }
                            }
                        }

                        context("then calling next()") {
                            it("should move to next item") {
                                let eventListener = CurrentItemEventListener()
                                audioPlayer.event.currentItem.addListener(eventListener, eventListener.handleEvent)

                                audioPlayer.next()
                                expect(audioPlayer.nextItems.count).toEventually(equal(0))
                                expect(audioPlayer.currentIndex).toEventually(equal(1))
                                expect(audioPlayer.playerState).toEventually(equal(AudioPlayerState.playing))
                                expect(eventListener.lastIndex).toEventually(equal(1))
                            }

                            context("then calling next() twice") {
                                it("should noop") {
                                    audioPlayer.next()
                                    audioPlayer.next()
                                    expect(audioPlayer.currentIndex).to(equal(1))
                                }
                            }
                        }
                    }

                    context("then setting repeat mode track") {
                        beforeEach {
                            audioPlayer.repeatMode = .track
                        }

                        context("allow playback to end") {
                            beforeEach {
                                audioPlayer.seekWithExpectation(to: 4.95)
                            }

                            it("should restart current item") {
                                let eventListener = CurrentItemEventListener()
                                audioPlayer.event.currentItem.addListener(eventListener, eventListener.handleEvent)

                                expect(audioPlayer.currentTime).toEventually(equal(0))
                                expect(audioPlayer.nextItems.count).toEventually(equal(1))
                                expect(audioPlayer.currentIndex).toEventually(equal(0))
                                expect(audioPlayer.playerState).toEventually(equal(AudioPlayerState.playing))
                            }
                        }

                        context("then calling next()") {
                            it("should move to next item and should play") {
                                let eventListener = CurrentItemEventListener()
                                audioPlayer.event.currentItem.addListener(eventListener, eventListener.handleEvent)

                                audioPlayer.next()
                                expect(audioPlayer.nextItems.count).to(equal(0))
                                expect(audioPlayer.playerState).toEventually(equal(AudioPlayerState.playing))
                                expect(eventListener.lastIndex).toEventually(equal(1))
                            }
                        }
                    }

                    context("then setting repeat mode queue") {
                        beforeEach {
                            audioPlayer.repeatMode = .queue
                        }

                        context("allow playback to end") {
                            beforeEach {
                                audioPlayer.seekWithExpectation(to: 4.95)
                            }

                            it("should move to next item and should play") {
                                let eventListener = CurrentItemEventListener()
                                audioPlayer.event.currentItem.addListener(eventListener, eventListener.handleEvent)

                                expect(audioPlayer.nextItems.count).toEventually(equal(0))
                                expect(audioPlayer.currentIndex).toEventually(equal(1))
                                expect(audioPlayer.playerState).toEventually(equal(AudioPlayerState.playing))
                                expect(eventListener.lastIndex).toEventually(equal(1))
                            }

                            context("allow playback to end again") {
                                beforeEach {
                                    audioPlayer.seekWithExpectation(to: 4.95)
                                }

                                it("should move to first track and should play") {
                                    let eventListener = CurrentItemEventListener()
                                    audioPlayer.event.currentItem.addListener(eventListener, eventListener.handleEvent)

                                    expect(audioPlayer.nextItems.count).toEventually(equal(1))
                                    expect(audioPlayer.currentIndex).toEventually(equal(0))
                                    expect(audioPlayer.playerState).toEventually(equal(AudioPlayerState.playing))
                                    expect(eventListener.lastIndex).toEventually(equal(1))
                                }
                            }
                        }

                        context("then calling next()") {
                            it("should move to next item and should play") {
                                let eventListener = CurrentItemEventListener()
                                audioPlayer.event.currentItem.addListener(eventListener, eventListener.handleEvent)

                                audioPlayer.next()
                                expect(audioPlayer.nextItems.count).to(equal(0))
                                expect(audioPlayer.currentIndex).to(equal(1))
                                expect(audioPlayer.playerState).toEventually(equal(AudioPlayerState.playing))
                                expect(eventListener.lastIndex).toEventually(equal(1))
                            }

                            context("then calling next() again") {
                                beforeEach {
                                    audioPlayer.next()
                                }

                                it("should move to first track and should play") {
                                    let eventListener = CurrentItemEventListener()
                                    audioPlayer.event.currentItem.addListener(eventListener, eventListener.handleEvent)

                                    audioPlayer.next()
                                    expect(audioPlayer.nextItems.count).to(equal(1))
                                    expect(audioPlayer.currentIndex).to(equal(0))
                                    expect(audioPlayer.playerState).toEventually(equal(AudioPlayerState.playing))
                                    expect(eventListener.lastIndex).toEventually(equal(0))
                                }
                            }
                        }
                    }
                }

                context("when adding 1 items") {
                    beforeEach {
                        try? audioPlayer.add(item: FiveSecondSource.getAudioItem(), playWhenReady: true)
                    }

                    context("then setting repeat mode off") {
                        beforeEach {
                            audioPlayer.repeatMode = .off
                        }

                        context("allow playback to end normally") {
                            beforeEach {
                                audioPlayer.seekWithExpectation(to: 4.95)
                            }

                            it("should stop playback normally") {
                                let eventListener = CurrentItemEventListener()
                                audioPlayer.event.currentItem.addListener(eventListener, eventListener.handleEvent)

                                expect(audioPlayer.nextItems.count).toEventually(equal(0))
                                expect(audioPlayer.playerState).toEventually(equal(AudioPlayerState.paused))
                            }
                        }

                        context("then calling next()") {
                            it("should noop") {
                                audioPlayer.next()
                                expect(audioPlayer.currentIndex).to(equal(0))
                            }
                        }
                    }

                    context("then setting repeat mode track") {
                        beforeEach {
                            audioPlayer.repeatMode = .track
                        }

                        context("allow playback to end") {
                            beforeEach {
                                audioPlayer.seekWithExpectation(to: 4.95)
                            }

                            it("should restart current item") {
                                let eventListener = CurrentItemEventListener()
                                audioPlayer.event.currentItem.addListener(eventListener, eventListener.handleEvent)

                                expect(audioPlayer.currentTime).toEventually(equal(0))
                                expect(audioPlayer.currentIndex).toEventually(equal(0))
                                expect(audioPlayer.playerState).toEventually(equal(AudioPlayerState.playing))
                                expect(eventListener.lastIndex).toEventually(beNil())
                            }
                        }

                        context("then calling next()") {
                            it("should restart current item") {
                                let eventListener = CurrentItemEventListener()
                                audioPlayer.event.currentItem.addListener(eventListener, eventListener.handleEvent)

                                expect(audioPlayer.currentTime).toEventually(equal(0))
                                expect(audioPlayer.currentIndex).toEventually(equal(0))
                                expect(audioPlayer.playerState).toEventually(equal(AudioPlayerState.playing))
                            }
                        }
                    }

                    context("then setting repeat mode queue") {
                        beforeEach {
                            audioPlayer.repeatMode = .queue
                        }

                        context("allow playback to end") {
                            beforeEach {
                                audioPlayer.seekWithExpectation(to: 4.95)
                            }

                            it("should restart current item") {
                                let eventListener = CurrentItemEventListener()
                                audioPlayer.event.currentItem.addListener(eventListener, eventListener.handleEvent)

                                expect(audioPlayer.currentTime).toEventually(equal(0))
                                expect(audioPlayer.currentIndex).toEventually(equal(0))
                                expect(audioPlayer.playerState).toEventually(equal(AudioPlayerState.playing))
                                expect(eventListener.lastIndex).toEventually(equal(0))
                            }
                        }

                        context("then calling next()") {
                            it("should restart current item") {
                                let eventListener = CurrentItemEventListener()
                                audioPlayer.event.currentItem.addListener(eventListener, eventListener.handleEvent)

                                // workaround: seek not to beggining, for 0 expecations to correctly fail if necessary.
                                audioPlayer.seekWithExpectation(to: 0.05)
                                audioPlayer.next()
                                expect(audioPlayer.currentTime).toEventually(equal(0))
                                expect(audioPlayer.currentIndex).toEventually(equal(0))
                                expect(audioPlayer.playerState).toEventually(equal(AudioPlayerState.playing))
                                expect(eventListener.lastIndex).toEventually(equal(0))
                            }
                        }
                    }
                }
            }
        }
    }
}
