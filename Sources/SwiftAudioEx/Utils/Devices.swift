//
//  File.swift
//  
//
//  Created by Brandon Sneed on 4/1/24.
//

import Foundation
import AVFoundation
import CoreAudio

public class AudioDevice: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        return name ?? "Unknown"
    }
    
    public var debugDescription: String {
        return name ?? "Unknown"
    }
    
    static var system: AudioDevice = {
        return AudioDevice()
    }()
    
    public let deviceID: AudioDeviceID?
    public let uniqueID: String?
    public let name: String?
    
    internal init(deviceID: AudioDeviceID) {
        self.deviceID = deviceID
        self.uniqueID = Self.propertyValue(deviceID: deviceID, selector: AudioObjectPropertySelector(kAudioDevicePropertyDeviceUID))
        self.name = Self.propertyValue(deviceID: deviceID, selector: AudioObjectPropertySelector(kAudioDevicePropertyDeviceNameCFString))
    }
    
    internal init() {
        self.deviceID = 0
        self.uniqueID = nil
        self.name = "System"
    }
}

extension AudioDevice {
    static func hasOutput(deviceID: AudioDeviceID) -> Bool {
        var status: OSStatus = 0
        var address = AudioObjectPropertyAddress(
            mSelector: AudioObjectPropertySelector(kAudioDevicePropertyStreamConfiguration),
            mScope: AudioObjectPropertyScope(kAudioObjectPropertyScopeOutput),
            mElement: 0)
        
        var size: UInt32 = 0
        withUnsafeMutablePointer(to: &size) { size in
            withUnsafePointer(to: &address) { addressPtr in
                status = AudioObjectGetPropertyDataSize(deviceID, addressPtr, 0, nil, size)
            }
        }
        
        if status != 0 {
            // we weren't able to get the size
            return false
        }
        
        let bufferList = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: Int(size))
        withUnsafeMutablePointer(to: &size) { size in
            withUnsafePointer(to: &address) { addressPtr in
                status = AudioObjectGetPropertyData(deviceID, addressPtr, 0, nil, size, bufferList)
            }
        }
        
        if status != 0 {
            // we couldn't get the buffer list
            return false
        }
        
        let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
        for buffer in buffers {
            if buffer.mNumberChannels > 0 {
                return true
            }
        }
        
        return false
    }
    
    static internal func propertyValue(deviceID: AudioDeviceID, selector: AudioObjectPropertySelector) -> String? {
        var result: String? = nil
        
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: AudioObjectPropertyScope(kAudioObjectPropertyScopeGlobal),
            mElement: AudioObjectPropertyElement(kAudioObjectPropertyElementMain))
        
        var name: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<CFString?>.size)
        withUnsafeMutablePointer(to: &size) { size in
            withUnsafePointer(to: &address) { addressPtr in
                let status = AudioObjectGetPropertyData(deviceID, addressPtr, 0, nil, size, &name)
                if status != 0 {
                    return
                }
                result = name?.takeUnretainedValue() as String?
            }
        }
        
        return result
    }
}

extension AudioPlayer {
    /**
     Set the output device for the Player.  Default is system.
     */
    public func setOutputDevice(_ device: AudioDevice) {
        guard let wrapper = wrapper as? AVPlayerWrapper else { return }
        wrapper.avPlayer.audioOutputDeviceUniqueID = device.uniqueID
    }
    
    /**
     Get the current output device
     */
    public var outputDevice: AudioDevice {
        get {
            guard let wrapper = wrapper as? AVPlayerWrapper else { return AudioDevice.system }
            guard let uniqueID = wrapper.avPlayer.audioOutputDeviceUniqueID else { return AudioDevice.system }
            let devices = localDevices.filter { device in
                return device.uniqueID == uniqueID
            }
            if let match = devices.first {
                return match
            }
            return AudioDevice.system
        }
        set(value) {
            guard let wrapper = wrapper as? AVPlayerWrapper else { return }
            wrapper.avPlayer.audioOutputDeviceUniqueID = value.uniqueID
        }
    }
    
    /**
     Get a list of local audio devices capable of output.
     
     This list will *NOT* include AirPlay devices.  For Airplay and other streaming
     audio devices, see AVRoutePickerView.
     */
    public var localDevices: [AudioDevice] {
        get {
            var status: OSStatus = 0
            var address = AudioObjectPropertyAddress(
                mSelector: AudioObjectPropertySelector(kAudioHardwarePropertyDevices),
                mScope: AudioObjectPropertyScope(kAudioObjectPropertyScopeGlobal),
                mElement: AudioObjectPropertyElement(kAudioObjectPropertyElementMaster))
            
            var size: UInt32 = 0
            withUnsafeMutablePointer(to: &size) { size in
                withUnsafePointer(to: &address) { address in
                    status = AudioObjectGetPropertyDataSize(
                        AudioObjectID(kAudioObjectSystemObject),
                        address,
                        UInt32(MemoryLayout<AudioObjectPropertyAddress>.size),
                        nil,
                        size)
                }
            }
            
            if status != 0 {
                // we couldn't get a data size
                return []
            }
            
            let deviceCount = size / UInt32(MemoryLayout<AudioDeviceID>.size)
            var deviceIDs = [AudioDeviceID]()
            for _ in 0..<deviceCount {
                deviceIDs.append(AudioDeviceID())
            }
            
            withUnsafeMutablePointer(to: &size) { size in
                withUnsafePointer(to: &address) { address in
                    status = AudioObjectGetPropertyData(
                        AudioObjectID(kAudioObjectSystemObject),
                        address,
                        0,
                        nil,
                        size,
                        &deviceIDs)
                }
            }
            
            if status != 0 {
                // we couldn't get anything from property data
                return []
            }
            
            var devices = [AudioDevice]()
            
            for id in deviceIDs {
                if AudioDevice.hasOutput(deviceID: id) {
                    let audioDevice = AudioDevice(deviceID: id)
                    devices.append(audioDevice)
                }
            }
            
            return devices
        }
    }
}
