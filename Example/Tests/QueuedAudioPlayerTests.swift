import Quick
import Nimble
import Foundation

@testable import SwiftAudioEx
import AVFoundation

extension QueuedAudioPlayer {

    class SeekEventListener {
        private let lockQueue = DispatchQueue(
            label: "SeekEventListener.lockQueue",
            target: .global()
        )
        var _eventResult: (Double, Bool) = (-1, false)
        var eventResult: (Double, Bool) {
            get {
                return lockQueue.sync {
                    _eventResult
                }
            }
        }
        func handleEvent(seconds: Double, didFinish: Bool) {
            lockQueue.sync {
                _eventResult = (seconds, didFinish)
            }
        }
    }

    class CurrentItemEventListener {
        private let lockQueue = DispatchQueue(
            label: "CurrentItemEventListener.lockQueue",
            target: .global()
        )
        var _item: AudioItem? = nil
        var _index: Int? = nil
        var _lastItem: AudioItem? = nil
        var _lastIndex: Int? = nil
        var _lastPosition: Double? = nil

        var item: AudioItem? {
            get {
                return lockQueue.sync {
                    return _item
                }
            }
        }
        var index: Int? {
            return lockQueue.sync {
                return _index
            }
        }
        var lastItem: AudioItem? {
            return lockQueue.sync {
                return _lastItem
            }
        }
        var lastIndex: Int? {
            return lockQueue.sync {
                return _lastIndex
            }
        }
        var lastPosition: Double? {
            return lockQueue.sync {
                return _lastPosition
            }
        }


        func handleEvent(
            item: AudioItem?,
            index: Int?,
            lastItem: AudioItem?,
            lastIndex: Int?,
            lastPosition: Double?
        ) {
            lockQueue.sync {
                _item = item
                _index = index
                _lastItem = lastItem
                _lastIndex = lastIndex
                _lastPosition = lastPosition
            }
        }
    }
    
    class PlaybackEndEventListener {
        private let lockQueue = DispatchQueue(
            label: "PlaybackEndEventListener.lockQueue",
            target: .global()
        )
        var _lastReason: PlaybackEndedReason? = nil
        var lastReason: PlaybackEndedReason? {
            get {
                return lockQueue.sync {
                    return _lastReason
                }
            }
        }
        var _reasons: [PlaybackEndedReason] = []
        var reasons: [PlaybackEndedReason] {
            get {
                return lockQueue.sync {
                    return _reasons
                }
            }
        }

        func handleEvent(reason: PlaybackEndedReason) {
            lockQueue.sync {
                _lastReason = reason
                _reasons.append(reason)
            }
        }
    }

    class PlayerStateEventListener {
        private let lockQueue = DispatchQueue(
            label: "PlayerStateEventListener.lockQueue",
            target: .global()
        )
        var _states: [AudioPlayerState] = []
        var states: [AudioPlayerState] {
            get {
                return lockQueue.sync {
                    return _states
                }
            }

            set {
                lockQueue.sync {
                    _states = newValue
                }
            }
        }
        private var _statesWithoutBuffering: [AudioPlayerState] = []
        var statesWithoutBuffering: [AudioPlayerState] {
            get {
                return lockQueue.sync {
                    return _statesWithoutBuffering
                }
            }

            set {
                lockQueue.sync {
                    _statesWithoutBuffering = newValue
                }
            }
        }
        func handleEvent(state: AudioPlayerState) {
            states.append(state)
            if (state != .ready && state != .buffering && (statesWithoutBuffering.isEmpty || statesWithoutBuffering.last != state)) {
                statesWithoutBuffering.append(state)
            }
        }
    }
    
    func seekWithExpectation(to time: Double) async {
        let seekEventListener = SeekEventListener()
        event.seek.addListener(seekEventListener, seekEventListener.handleEvent)
        await seek(to: time)
        await expect(seekEventListener.eventResult).toEventually(equal((time, true)))
    }
}

class QueuedAudioPlayerTests: QuickSpec {
    override func spec() {
        describe("A QueuedAudioPlayer") {
            var audioPlayer: QueuedAudioPlayer!
            var currentItemEventListener: QueuedAudioPlayer.CurrentItemEventListener!
            var playbackEndEventListener: QueuedAudioPlayer.PlaybackEndEventListener!
            var playerStateEventListener: QueuedAudioPlayer.PlayerStateEventListener!

            beforeEach {
                audioPlayer = QueuedAudioPlayer()
                currentItemEventListener = QueuedAudioPlayer.CurrentItemEventListener()
                audioPlayer.event.currentItem.addListener(
                    currentItemEventListener,
                    currentItemEventListener.handleEvent
                )

                playbackEndEventListener = QueuedAudioPlayer.PlaybackEndEventListener()
                audioPlayer.event.playbackEnd.addListener(
                    playbackEndEventListener,
                    playbackEndEventListener.handleEvent
                )

                playerStateEventListener = QueuedAudioPlayer.PlayerStateEventListener()
                audioPlayer.event.stateChange.addListener(
                    playerStateEventListener,
                    playerStateEventListener.handleEvent
                )
                
                audioPlayer.volume = 0.0
            }

            // MARK: currentItem
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
                        await audioPlayer.add(item: fiveSecondItem)
                    }
                    it("should not be nil") {
                        expect(audioPlayer.currentItem).toNot(beNil())
                    }

                    context("then loading a new item") {
                        beforeEach {
                            await audioPlayer.load(item: item)
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
                            await audioPlayer.play();
                            await audioPlayer.seek(to: 4);
                            try? await audioPlayer.removeItem(at: audioPlayer.currentIndex);
                        }
                        
                        it("should have made the currentItem nil") {
                            expect(audioPlayer.currentItem).to(beNil())
                        }

                        it("should make the player be idle") {
                            expect(audioPlayer.playerState).to(equal(AudioPlayerState.idle))
                        }

                        context("then loading a new item") {
                            beforeEach {
                                await audioPlayer.load(item: Source.getAudioItem())
                            }
                            
                            it("should have set the item") {
                                expect(audioPlayer.currentItem?.getSourceUrl()).toNot(equal(fiveSecondItem.getSourceUrl()))
                            }
                            it("should have started loading") {
                                expect(playerStateEventListener.states[0]).to(equal(AudioPlayerState.loading))
                            }
                            it("should have started playing") {
                                await expect(audioPlayer.playerState).toEventually(equal(AudioPlayerState.playing))
                            }
                        }
                    }
                }

                context("when adding multiple items") {
                    beforeEach {
                        await audioPlayer.add(items: [FiveSecondSource.getAudioItem(), ShortSource.getAudioItem()], playWhenReady: false)
                    }

                    it("currentItem should not be nil") {
                        expect(audioPlayer.currentItem).toNot(beNil())
                    }

                    it("currentIndex should be 0") {
                        expect(audioPlayer.currentIndex).to(equal(0))
                    }

                    context("then removing the first item") {
                        it("the current item should now be what was previously the second item") {
                            try? await audioPlayer.removeItem(at: 0)
                            expect (currentItemEventListener.item?.getSourceUrl()).to(equal(ShortSource.getAudioItem().getSourceUrl()))
                            expect(audioPlayer.currentItem?.getSourceUrl()).to(equal(ShortSource.getAudioItem().getSourceUrl()))
                        }
                    }
                }
            }

            // MARK: nextItems
            describe("its next items") {
                it("should be empty") {
                    expect(audioPlayer.nextItems.count).to(equal(0))
                }

                context("when adding 2 items") {
                    beforeEach {
                        await audioPlayer.add(items: [Source.getAudioItem(), Source.getAudioItem()])
                    }
                    it("should contain 1 item") {
                        expect(audioPlayer.nextItems.count).to(equal(1))
                    }

                    context("then calling next()") {
                        beforeEach {
                            await audioPlayer.next()
                        }
                        it("should contain 0 items") {
                            expect(audioPlayer.nextItems.count).to(equal(0))
                        }

                        context("then calling previous()") {
                            beforeEach {
                                await audioPlayer.previous()
                            }
                            it("should contain 1 item") {
                                expect(audioPlayer.nextItems.count).to(equal(1))
                            }
                        }
                    }

                    context("then removing one item") {
                        beforeEach {
                            try? await audioPlayer.removeItem(at: 1)
                        }

                        it("should be empty") {
                            expect(audioPlayer.nextItems.count).to(equal(0))
                        }
                    }

                    context("then jumping to the last item") {
                        beforeEach {
                            try? await audioPlayer.jumpToItem(atIndex: 1)
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
                            await audioPlayer.stop()
                        }

                        it("should not be empty") {
                            expect(audioPlayer.nextItems.count).to(equal(1))
                        }
                    }
                }
            }

            // MARK: previousItems
            describe("its previous items") {
                it("should be empty") {
                    expect(audioPlayer.previousItems.count).to(equal(0))
                }

                context("when adding 2 items") {
                    beforeEach {
                        await audioPlayer.add(items: [FiveSecondSource.getAudioItem(), FiveSecondSource.getAudioItem()])
                        await waitUntil { done in
                            if (playerStateEventListener.states.count > 0) {
                                done()
                            }
                        }
                    }

                    it("should be empty") {
                        expect(audioPlayer.previousItems.count).to(equal(0))
                    }

                    context("then calling next()") {
                        beforeEach {
                            await audioPlayer.next()
                            await waitUntil { done in
                                if (playerStateEventListener.states.count > 0) {
                                    done()
                                }
                            }
                        }
                        it("should contain one item") {
                            expect(audioPlayer.previousItems.count).to(equal(1))
                        }

                        it("should have emitted playbackEnd") {
                            expect(playbackEndEventListener.lastReason).to(equal(.skippedToNext))
                        }

                        context("then calling stop()") {
                            beforeEach {
                                await audioPlayer.stop()
                            }
                            it("should have emitted playbackEnd .playerStopped") {
                                await expect(audioPlayer.playerState).toEventually(equal(.stopped))
                                await expect(playbackEndEventListener.reasons).toEventually(
                                    equal([.skippedToNext, .playerStopped])
                                )
                            }

                            context("then calling stop() again") {
                                beforeEach {
                                    await audioPlayer.stop()
                                }

                                it("should not have emitted playbackEnd .playerStopped because the player was already stopped") {
                                    await expect(audioPlayer.playerState).toEventually(equal(.stopped))
                                    await expect(playbackEndEventListener.reasons).toEventually(
                                        equal([.skippedToNext, .playerStopped])
                                    )
                                }
                            }
                        }

                        context("then calling previous() after stop()") {
                            beforeEach {
                                await audioPlayer.stop()
                                await audioPlayer.previous()
                            }
                            it("should not have emitted playbackEnd .skippedToPrevious because playback was already stopped previously") {
                                await expect(audioPlayer.playerState).toEventually(equal(.loading))
                                expect(playbackEndEventListener.reasons).to(
                                    equal([.skippedToNext, .playerStopped])
                                )
                            }
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
                }
            }

            // MARK: pause()
            describe("pause") {
                context("with playWhenReady == true") {
                    beforeEach {
                        await audioPlayer.setPlayWhenReady(true)
                    }

                    it("should have mutated playWhenReady to true") {
                        expect(audioPlayer.getPlayWhenReady()).to(beTrue())
                    }

                    context("calling pause() on empty queue") {
                        beforeEach {
                            await audioPlayer.pause()
                        }
                        it("should have mutated playWhenReady to false") {
                            expect(audioPlayer.getPlayWhenReady()).to(beFalse())
                        }
                        it("should not have mutated player state to .paused because playback was already idle") {
                            await expect(playerStateEventListener.states).toEventually(equal([]))
                        }
                    }
                    context("pausing and then adding an item") {
                        beforeEach {
                            await audioPlayer.pause()
                            await audioPlayer.add(items: [
                                FiveSecondSource.getAudioItem()
                            ])
                        }
                        it("should have gone into .paused state from .loading and then into .ready because playback can be started") {
                            await expect(playerStateEventListener.states).toEventually(equal([
                                .loading, .buffering, .paused, .ready
                            ]))
                        }
                    }
                }
            }
            
            // MARK: stop()
            describe("stop") {
                context("calling stop() on empty queue") {
                    beforeEach {
                        await audioPlayer.stop()
                    }
                    it("should have mutated player state to .stopped") {
                        expect(playerStateEventListener.states).to(equal([
                            .stopped
                        ]))
                    }
                    it("should not have emitted a playbackEnd event") {
                        expect(playbackEndEventListener.lastReason).to(beNil())
                    }
                }
                context("when adding 2 items and calling stop()") {
                    beforeEach {
                        await audioPlayer.add(items: [
                            FiveSecondSource.getAudioItem(),
                            FiveSecondSource.getAudioItem()
                        ])
                        await audioPlayer.stop()
                    }
                    it("should have emitted a playbackEnd .playerStopped event") {
                        await expect(playbackEndEventListener.lastReason).toEventually(
                            equal(.playerStopped)
                        )
                    }
                    it("should have mutated player state from .loading to .stopped") {
                        await expect(playerStateEventListener.states).toEventually(equal([
                            .loading,
                            .stopped
                        ]))
                    }
                }
            }

            // MARK: load(item)
            describe("load") {
                context("calling load(item) on empty queue") {
                    beforeEach {
                        await audioPlayer.load(item: FiveSecondSource.getAudioItem())
                    }
                    it("should have set currentItem") {
                        expect(audioPlayer.currentItem).toNot((beNil()))
                    }
                    it("should have started loading, but not playing yet") {
                        await expect(playerStateEventListener.states).toEventually(equal([
                            .loading, .ready
                        ]))
                    }
                }
                context("calling play() then load(item) on empty queue") {
                    beforeEach {
                        await audioPlayer.play()
                        await audioPlayer.load(item: FiveSecondSource.getAudioItem())
                    }
                    it("should have set currentItem") {
                        expect(audioPlayer.currentItem).toNot((beNil()))
                    }
                    it("should have started playing") {
                        await expect(playerStateEventListener.statesWithoutBuffering).toEventually(equal([
                            .loading, .playing
                        ]))
                    }

                    context("waiting for the track to start playing, then loading another track") {
                        it("should start playing the second track") {
                            await expect(playerStateEventListener.statesWithoutBuffering).toEventually(equal([
                                .loading, .playing
                            ]))
                            await audioPlayer.load(item: Source.getAudioItem())
                            expect(audioPlayer.items.count).to(equal(1))
                            expect(audioPlayer.currentItem?.getSourceUrl())
                                .to(equal(Source.getAudioItem().getSourceUrl()))
                            await expect(playerStateEventListener.statesWithoutBuffering.prefix(4)).toEventually(equal([
                                .loading, .playing, .loading, .playing
                            ]))
                        }
                    }
                }
            }

            
            // MARK: next()
            describe("next") {
                context("calling next() on empty queue") {
                    beforeEach {
                        await audioPlayer.next()
                    }
                    it("should not have emitted a playbackEnd event") {
                        expect(playbackEndEventListener.lastReason).to(beNil())
                    }
                }

                context("player was paused") {
                    beforeEach {
                        await audioPlayer.add(items: [FiveSecondSource.getAudioItem(), FiveSecondSource.getAudioItem()])
                    }

                    context("then calling next()") {
                        beforeEach {
                            await audioPlayer.next()
                        }

                        it("should go to next item and play") {
                            await expect(audioPlayer.nextItems.count).toEventually(equal(0))
                            await expect(audioPlayer.currentIndex).toEventually(equal(1))
                            await expect(audioPlayer.playerState).toEventually(equal(AudioPlayerState.ready))
                        }
                    }
                }
                context("player was paused") {
                    beforeEach {
                        await audioPlayer.add(items: [FiveSecondSource.getAudioItem(), FiveSecondSource.getAudioItem()])
                        await audioPlayer.pause()

                    }

                    context("then calling next()") {
                        beforeEach {
                            await audioPlayer.next()
                        }

                        it("should go to next item and not play") {
                            await expect(audioPlayer.nextItems.count).toEventually(equal(0))
                            await expect(audioPlayer.currentIndex).toEventually(equal(1))
                            await expect(audioPlayer.playerState).toEventually(equal(AudioPlayerState.ready))
                        }
                    }
                }
                context("player was playing") {
                    beforeEach {
                        await audioPlayer.play()
                        await audioPlayer.add(items: [FiveSecondSource.getAudioItem(), FiveSecondSource.getAudioItem()])
                    }

                    context("then calling next()") {
                        beforeEach {
                            await audioPlayer.next()
                        }

                        it("should go to next item and play") {
                            await expect(audioPlayer.nextItems.count).toEventually(equal(0))
                            await expect(audioPlayer.currentIndex).toEventually(equal(1))
                            await expect(audioPlayer.playerState).toEventually(equal(AudioPlayerState.playing))
                        }
                    }
                }
            }

            // MARK: previous()
            describe("onPrevious") {
                context("calling previous() on empty queue") {
                    beforeEach {
                        await audioPlayer.previous()
                    }
                    it("should not have emitted a playbackEnd event") {
                        expect(playbackEndEventListener.lastReason).to(beNil())
                    }
                }

                context("player was playing") {
                    beforeEach {
                        await audioPlayer.add(items: [FiveSecondSource.getAudioItem(), FiveSecondSource.getAudioItem()], playWhenReady: true)
                        await audioPlayer.next()
                    }

                    context("then calling previous()") {
                        beforeEach {
                            await audioPlayer.previous()
                        }

                        it("should go to previous item and play") {
                            await expect(audioPlayer.nextItems.count).toEventually(equal(1))
                            await expect(audioPlayer.previousItems.count).toEventually(equal(0))
                            await expect(audioPlayer.currentIndex).toEventually(equal(0))
                            await expect(audioPlayer.playerState).toEventually(equal(AudioPlayerState.playing))
                        }
                    }
                }
                context("player was paused") {
                    beforeEach {
                        await audioPlayer.add(items: [FiveSecondSource.getAudioItem(), FiveSecondSource.getAudioItem()])
                        await audioPlayer.next()
                        await audioPlayer.pause()

                    }

                    context("then calling previous()") {
                        beforeEach {
                            await audioPlayer.previous()
                        }

                        it("should go to previous item and not play") {
                            await expect(audioPlayer.nextItems.count).toEventually(equal(1))
                            await expect(audioPlayer.previousItems.count).toEventually(equal(0))
                            await expect(audioPlayer.currentIndex).toEventually(equal(0))
                            await expect(audioPlayer.playerState).toEventually(equal(AudioPlayerState.ready))
                        }
                    }
                }
            }

            // MARK: moveItem()
            describe("moving items") {
                context("when adding 2 items") {
                    beforeEach {
                        await audioPlayer.play()
                        await audioPlayer.add(items: [
                            FiveSecondSource.getAudioItem(),
                            FiveSecondSource.getAudioItem()
                        ])
                    }
                    
                    context("moving the first (currently playing track) above the second and seek to near the end of the track") {
                        beforeEach {
                            try? audioPlayer.moveItem(fromIndex: 0, toIndex: 1)
                            await audioPlayer.seekWithExpectation(to: 4.95)
                        }
                        
                        context("whith no repeat mode none") {
                            beforeEach {
                                audioPlayer.repeatMode = .off
                            }

                            it("should end playback") {
                                await expect(audioPlayer.playerState).toEventually(equal(AudioPlayerState.ended))
                            }
                        }

                        context("whith repeat mode queue") {
                            beforeEach {
                                audioPlayer.repeatMode = .queue
                            }

                            it("should start playing the first track") {
                                await expect(audioPlayer.currentIndex).toEventually(equal(0))
                                await expect(audioPlayer.currentTime).toEventually(beGreaterThan(0))
                                await expect(audioPlayer.playerState).toEventually(equal(AudioPlayerState.playing))
                            }
                        }

                        context("whith repeat mode track") {
                            beforeEach {
                                audioPlayer.repeatMode = .track
                            }

                            it("should start playing the current track again") {
                                await expect(audioPlayer.currentTime).toEventually(beLessThan(4.95))
                                await expect(audioPlayer.currentTime).toEventually(beGreaterThan(0))
                                expect(audioPlayer.currentIndex).to(equal(1))
                                await expect(audioPlayer.playerState).toEventually(equal(AudioPlayerState.playing))
                            }
                        }
                    }
                }
            }

            // MARK: repeatMode
            describe("its repeat mode") {
                context("when adding 2 items") {
                    beforeEach {
                        await audioPlayer.play()
                        await audioPlayer.add(
                            items: [
                                FiveSecondSource.getAudioItem(),
                                FiveSecondSource.getAudioItem()
                            ]
                        )
                    }

                    context("then setting repeat mode off") {
                        beforeEach {
                            audioPlayer.repeatMode = .off
                        }

                        context("allow playback to end normally") {
                            beforeEach {
                                await audioPlayer.seekWithExpectation(to: 4.95)
                            }

                            it("should move to next item") {
                                await expect(audioPlayer.nextItems.count).toEventually(equal(0))
                                await expect(audioPlayer.currentIndex).toEventually(equal(1))
                                await expect(audioPlayer.playerState).toEventually(equal(AudioPlayerState.playing))
                                await expect(currentItemEventListener.lastIndex).toEventually(equal(0))
                            }

                            context("allow playback to end again") {
                                it("should stop playback normally") {
                                    // Wait for track to move to next:
                                    await expect(audioPlayer.currentIndex).toEventually(equal(1))
                                    // Seek to close to the end of the track
                                    await audioPlayer.seekWithExpectation(to: 4.95)

                                    await expect(audioPlayer.nextItems.count).toEventually(equal(0))
                                    await expect(audioPlayer.currentIndex).toEventually(equal(1))
                                    await expect(audioPlayer.currentTime).toEventually(equal(5))
                                    await expect(audioPlayer.playerState).toEventually(equal(AudioPlayerState.ended))
                                    await expect(currentItemEventListener.index).toEventually(equal(1))
                                    await expect(currentItemEventListener.lastIndex).toEventually(equal(0))
                                }
                            }
                        }

                        context("then calling next()") {
                            it("should move to next item") {

                                await audioPlayer.next()
                                await expect(audioPlayer.nextItems.count).toEventually(equal(0))
                                await expect(audioPlayer.currentIndex).toEventually(equal(1))
                                await expect(audioPlayer.playerState).toEventually(equal(AudioPlayerState.playing))
                                await expect(currentItemEventListener.lastIndex).toEventually(equal(0))
                            }

                            context("then calling next() twice") {
                                it("should stay on the last track, but it should repeat") {
                                    await audioPlayer.play()
                                    await audioPlayer.next()
                                    await audioPlayer.seekWithExpectation(to: 1)
                                    await audioPlayer.next()
                                    await expect(audioPlayer.currentTime).toEventually(beLessThan(1))
                                    await expect(audioPlayer.currentIndex).toEventually(equal(1))
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
                                await audioPlayer.seekWithExpectation(to: 4.95)
                            }

                            it("should restart current item") {
                                await expect(audioPlayer.currentTime).toEventually(equal(0))
                                await expect(audioPlayer.nextItems.count).toEventually(equal(1))
                                await expect(audioPlayer.currentIndex).toEventually(equal(0))
                                await expect(audioPlayer.playerState).toEventually(equal(AudioPlayerState.playing))
                            }
                        }

                        context("then calling next()") {
                            it("should move to next item and should play") {
                                await audioPlayer.next()
                                expect(audioPlayer.nextItems.count).to(equal(0))
                                await expect(audioPlayer.playerState).toEventually(equal(AudioPlayerState.playing))
                                await expect(currentItemEventListener.lastIndex).toEventually(equal(0))
                            }
                        }
                    }

                    context("then setting repeat mode queue") {
                        beforeEach {
                            audioPlayer.repeatMode = .queue
                        }

                        context("seek to close to the end of the track") {
                            beforeEach {
                                await audioPlayer.seekWithExpectation(to: 4.95)
                            }

                            it("should move to next item and should play") {
                                await expect(audioPlayer.nextItems.count).toEventually(equal(0))
                                await expect(audioPlayer.currentIndex).toEventually(equal(1))
                                await expect(audioPlayer.playerState).toEventually(equal(AudioPlayerState.playing))
                                await expect(currentItemEventListener.lastIndex).toEventually(equal(0))
                            }

                            context("allow playback to end again") {
                                it("it should move to first track and should play") {
                                    await expect(audioPlayer.currentIndex).toEventually(equal(1))
                                    await audioPlayer.seekWithExpectation(to: 4.95)
                                    await expect(audioPlayer.nextItems.count).toEventually(equal(1))
                                    await expect(audioPlayer.currentIndex).toEventually(equal(0))
                                    await expect(audioPlayer.playerState).toEventually(equal(AudioPlayerState.playing))
                                    await expect(currentItemEventListener.lastIndex).toEventually(equal(1))
                                }
                            }
                        }

                        context("then calling next()") {
                            it("should move to next item and should play") {
                                await audioPlayer.next()
                                expect(audioPlayer.nextItems.count).to(equal(0))
                                expect(audioPlayer.currentIndex).to(equal(1))
                                await expect(audioPlayer.playerState).toEventually(equal(AudioPlayerState.playing))
                                await expect(currentItemEventListener.lastIndex).toEventually(equal(0))
                            }
                        }
                        context("then calling next() twice") {
                            it("should move to first track and should play") {
                                expect(audioPlayer.currentIndex).to(equal(0))
                                expect(currentItemEventListener.lastIndex).to(beNil())

                                await audioPlayer.next()
                                expect(audioPlayer.currentIndex).to(equal(1))
                                await expect(currentItemEventListener.lastIndex).toEventually(equal(0))

                                await audioPlayer.next()
                                expect(audioPlayer.currentIndex).to(equal(0))
                                await expect(currentItemEventListener.lastIndex).toEventually(equal(1))

                                expect(audioPlayer.nextItems.count).to(equal(1))
                                await expect(audioPlayer.playerState).toEventually(equal(AudioPlayerState.playing))
                            }
                        }
                    }
                }

                context("when adding 1 items") {
                    beforeEach {
                        await audioPlayer.add(item: FiveSecondSource.getAudioItem(), playWhenReady: true)
                    }

                    context("then setting repeat mode off") {
                        beforeEach {
                            audioPlayer.repeatMode = .off
                        }

                        context("allow playback to end normally") {
                            beforeEach {
                                await audioPlayer.seekWithExpectation(to: 4.95)
                            }

                            it("should stop playback normally") {
                                await expect(audioPlayer.nextItems.count).toEventually(equal(0))
                                await expect(audioPlayer.playerState).toEventually(equal(AudioPlayerState.ended))
                            }
                        }

                        context("then calling next()") {
                            it("should noop") {
                                await audioPlayer.next()
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
                                await audioPlayer.seekWithExpectation(to: 4.95)
                            }

                            it("should restart current item") {
                                await expect(audioPlayer.currentTime).toEventually(equal(0))
                                await expect(audioPlayer.currentIndex).toEventually(equal(0))
                                await expect(audioPlayer.playerState).toEventually(equal(AudioPlayerState.playing))
                                await expect(currentItemEventListener.lastIndex).toEventually(beNil())
                            }
                        }

                        context("then calling next()") {
                            it("should restart current item") {
                                await expect(audioPlayer.currentTime).toEventually(equal(0))
                                await expect(audioPlayer.currentIndex).toEventually(equal(0))
                                await expect(audioPlayer.playerState).toEventually(equal(AudioPlayerState.playing))
                            }
                        }
                    }

                    context("then setting repeat mode queue") {
                        beforeEach {
                            audioPlayer.repeatMode = .queue
                        }

                        context("allow playback to end") {
                            beforeEach {
                                await audioPlayer.seekWithExpectation(to: 4.95)
                            }

                            it("should restart current item") {
                                await expect(audioPlayer.playerState).toEventually(equal(AudioPlayerState.playing))
                                await expect(audioPlayer.currentTime).toEventually(beGreaterThan(4.95))
                                await expect(audioPlayer.currentTime).toEventually(beGreaterThan(0))
                                await expect(audioPlayer.currentIndex).toEventually(equal(0))
                                await expect(audioPlayer.playerState).toEventually(equal(AudioPlayerState.playing))
                            }
                        }

                        context("then calling next()") {
                            beforeEach {
                                await audioPlayer.seekWithExpectation(to: 2)
                                await audioPlayer.next()
                            }
                            it("should restart current item") {
                                await expect(audioPlayer.playerState).toEventually(equal(AudioPlayerState.playing))
                                await expect(audioPlayer.currentTime).toEventually(beLessThan(2))
                                await expect(audioPlayer.currentTime).toEventually(beGreaterThan(0))
                                await expect(audioPlayer.currentIndex).toEventually(equal(0))
                                await expect(audioPlayer.playerState).toEventually(equal(AudioPlayerState.playing))
                            }
                        }
                    }
                }
            }
        }
    }
}
