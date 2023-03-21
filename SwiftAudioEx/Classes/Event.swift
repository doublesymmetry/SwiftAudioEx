//
//  Event.swift
//  SwiftAudio
//
//  Created by Jørgen Henrichsen on 09/03/2019.
//

import Foundation
import MediaPlayer

@available(iOS 13.0, *)
extension AudioPlayer {
    
    public typealias PlayWhenReadyChangeData = Bool
    public typealias StateChangeEventData = AudioPlayerState
    public typealias PlaybackEndEventData = PlaybackEndedReason
    public typealias SecondElapseEventData = TimeInterval
    public typealias FailEventData = Error?
    public typealias SeekEventData = (seconds: Double, didFinish: Bool)
    public typealias UpdateDurationEventData = Double
    public typealias MetadataEventData = [AVTimedMetadataGroup]
    public typealias DidRecreateAVPlayerEventData = ()
    public typealias CurrentItemEventData = (
        item: AudioItem?,
        index: Int?,
        lastItem: AudioItem?,
        lastIndex: Int?,
        lastPosition: Double?
    )
    
    @available(iOS 13.0, *)
    public struct EventHolder {
        
        /**
         Emitted when the `AudioPlayer`s state is changed
         - Important: Remember to dispatch to the main queue if any UI is updated in the event handler.
         */
        public let stateChange: AudioPlayer.Event<StateChangeEventData> = AudioPlayer.Event()

        /**
         Emitted when the `AudioPlayer#playWhenReady` has changed
         - Important: Remember to dispatch to the main queue if any UI is updated in the event handler.
         */
        public let playWhenReadyChange: AudioPlayer.Event<PlayWhenReadyChangeData> = AudioPlayer.Event()
        
        /**
         Emitted when the playback of the player, for some reason, has stopped.
         - Important: Remember to dispatch to the main queue if any UI is updated in the event handler.
         */
        public let playbackEnd: AudioPlayer.Event<PlaybackEndEventData> = AudioPlayer.Event()
        
        /**
         Emitted when a second is elapsed in the `AudioPlayer`.
         - Important: Remember to dispatch to the main queue if any UI is updated in the event handler.
         */
        public let secondElapse: AudioPlayer.Event<SecondElapseEventData> = AudioPlayer.Event()
        
        /**
         Emitted when the player encounters an error. This will ultimately result in the AVPlayer instance to be recreated.
         If this event is emitted, it means you will need to load a new item in some way. Calling play() will not resume playback.
         - Important: Remember to dispatch to the main queue if any UI is updated in the event handler.
         */
        public let fail: AudioPlayer.Event<FailEventData> = AudioPlayer.Event()
        
        /**
         Emitted when the player is done attempting to seek.
         - Important: Remember to dispatch to the main queue if any UI is updated in the event handler.
         */
        public let seek: AudioPlayer.Event<SeekEventData> = AudioPlayer.Event()
        
        /**
         Emitted when the player updates its duration.
         - Important: Remember to dispatch to the main queue if any UI is updated in the event handler.
         */
        public let updateDuration: AudioPlayer.Event<UpdateDurationEventData> = AudioPlayer.Event()

        /**
         Emitted when the player receives metadata.
         - Important: Remember to dispatch to the main queue if any UI is updated in the event handler.
         */
        public let receiveMetadata: AudioPlayer.Event<MetadataEventData> = AudioPlayer.Event()
        
        /**
         Emitted when the underlying AVPlayer instance is recreated. Recreation happens if the current player fails.
         - Important: Remember to dispatch to the main queue if any UI is updated in the event handler.
         - Note: It can be necessary to set the AVAudioSession's category again when this event is emitted.
         */
        public let didRecreateAVPlayer: AudioPlayer.Event<()> = AudioPlayer.Event()

        /**
         Emitted when the current track has changed.
         - Important: Remember to dispatch to the main queue if any UI is updated in the event handler.
         - Note: It is only fired for instances of a QueuedAudioPlayer.
         */
        public let currentItem: AudioPlayer.Event<CurrentItemEventData> = AudioPlayer.Event()
    }
    
    public typealias EventClosure<EventData> = (EventData) async -> Void
    
    class Invoker<EventData> {
        
        // Signals false if the listener object is nil
        let invoke: (EventData) async -> Bool
        weak var listener: AnyObject?
        
        init<Listener: AnyObject>(listener: Listener, closure: @escaping EventClosure<EventData>) {
            self.listener = listener
            invoke = { [weak listener] (data: EventData) async in
                guard let _ = listener else {
                    return false
                }
                await closure(data)
                return true
            }
        }
        
    }
    
    @available(iOS 13.0, *)
    public class Event<EventData> {
        var invokers: [Invoker<EventData>] = []
        private let invokersSemaphore: DispatchSemaphore = DispatchSemaphore(value: 1)

        public func addListener<Listener: AnyObject>(_ listener: Listener, _ closure: @escaping EventClosure<EventData>) {
            self.invokersSemaphore.wait()
            self.invokers.append(Invoker(listener: listener, closure: closure))
            self.invokersSemaphore.signal()
        }
        
        public func removeListener(_ listener: AnyObject) {
            self.invokersSemaphore.wait()
            let invokers = self.invokers;
            self.invokers = invokers.filter({ (invoker) -> Bool in
                if let listenerToCheck = invoker.listener {
                    return listenerToCheck !== listener
                }
                return true
            })
            self.invokersSemaphore.signal()
        }
        
        private func setInvokers(_ invokers: [Invoker<EventData>]) {
            self.invokersSemaphore.wait()
            self.invokers = invokers
            self.invokersSemaphore.signal()
        }
        
        public func emit(data: EventData) async {
            let invokersToInvoke = self.invokers
            var filteredInvokers: [Invoker<EventData>] = []
            for invoker in invokersToInvoke {
                if(await invoker.invoke(data)) {
                    filteredInvokers.append(invoker)
                }
            }
            setInvokers(filteredInvokers)
        }
    }
}
