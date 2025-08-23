//
//  Item.swift
//  PhotoSwipe2
//
//  Created by Wade Bernhardt on 8/22/25.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
