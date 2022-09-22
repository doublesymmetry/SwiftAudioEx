//
//  APError.swift
//  SwiftAudio
//
//  Created by Jørgen Henrichsen on 25/03/2018.
//

import Foundation


public struct APError {

    enum LoadError: Error {
        case invalidSourceUrl(String)
    }

    enum QueueError: Error {
        case noCurrentItem
        case invalidIndex(index: Int, message: String)
        case empty
    }

}
