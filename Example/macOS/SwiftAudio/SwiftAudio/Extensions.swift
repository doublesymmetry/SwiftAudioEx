//
//  Extensions.swift
//  SwiftAudio
//
//  Created by Brandon Sneed on 3/30/24.
//

import Foundation

extension Double {
    private var formatter: DateComponentsFormatter {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }
    
    func secondsToString() -> String {
        return formatter.string(from: self) ?? ""
    }
}
