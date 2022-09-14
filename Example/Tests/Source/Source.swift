//
//  Sources.swift
//  SwiftAudio_Tests
//
//  Created by Jørgen Henrichsen on 05/08/2018.
//  Copyright © 2018 CocoaPods. All rights reserved.
//

import Foundation
import SwiftAudioEx
import UIKit

struct Source {
    static let path: String = Bundle.main.path(forResource: "TestSound", ofType: "m4a")!
    static let url: URL = URL(fileURLWithPath: Source.path)
    
    static func getAudioItem() -> AudioItem {
        return DefaultAudioItem(audioUrl: self.path, artist: "Artist", title: "Title", albumTitle: "AlbumTitle", sourceType: .file, artwork: UIImage())
    }
}

struct ShortSource {
    static let path: String = Bundle.main.path(forResource: "ShortTestSound", ofType: "m4a")!
    static let url: URL = URL(fileURLWithPath: ShortSource.path)
    
    static func getAudioItem() -> AudioItem {
        return DefaultAudioItem(audioUrl: self.path, sourceType: .file)
    }
}

struct LongSource {
    static let path: String = Bundle.main.path(forResource: "WAV-MP3", ofType: "wav")!
    static let url: URL = URL(fileURLWithPath: LongSource.path)
    
    static func getAudioItem() -> AudioItem {
        return DefaultAudioItem(audioUrl: self.path, sourceType: .file)
    }
}

struct FiveSecondSource {
    static let path: String = Bundle.main.path(forResource: "five_seconds", ofType: "mp3")!
    static let url: URL = URL(fileURLWithPath: FiveSecondSource.path)
    
    static func getAudioItem() -> AudioItem {
        return DefaultAudioItem(audioUrl: self.path, sourceType: .file)
    }
}
