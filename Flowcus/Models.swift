//
//  Models.swift
//  Flowcus
//
//  Created by E on 2/3/26.
//

import Foundation
import SwiftData

@Model
class TaskItem {
    var title: String
    var isCompleted: Bool
    var createdAt: Date
    
    init(title: String, isCompleted: Bool = false) {
        self.title = title
        self.isCompleted = isCompleted
        self.createdAt = Date()
    }
}

@Model
class JournalEntry {
    var title: String // New Title Property
    var content: String
    var timestamp: Date
    var mood: String // Simple "Good", "Neutral", "Bad" tracker
    
    init(title: String = "", content: String, mood: String = "Neutral") {
        self.title = title
        self.content = content
        self.timestamp = Date()
        self.mood = mood
    }
}