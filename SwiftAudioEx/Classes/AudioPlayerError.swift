//
//  APError.swift
//  SwiftAudio
//
//  Created by Jørgen Henrichsen on 25/03/2018.
//

import Foundation


public struct AudioPlayerError {

    enum LoadError: Error {
        case invalidSourceUrl(String)
    }

    enum PlaybackError: Error {
        case itemFailedToPlayToEndTime
    }
    
    enum QueueError: Error {
        case noCurrentItem
        case invalidIndex(index: Int, message: String)
        case empty
    }

}
