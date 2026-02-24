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
    var scheduledDate: Date // Links task to a specific calendar day
    
    init(title: String, isCompleted: Bool = false, scheduledDate: Date = Date()) {
        self.title = title
        self.isCompleted = isCompleted
        self.createdAt = Date()
        self.scheduledDate = scheduledDate
    }
}

@Model
class JournalEntry {
    static let allowedMoods: Set<String> = ["🔥", "🙂", "😐", "😫", "🧠"]

    var title: String // New Title Property
    var content: String
    var timestamp: Date
    var mood: String // Stored as emoji for consistent picker/display values
    
    init(title: String = "", content: String, mood: String = "😐") {
        self.title = title
        self.content = content
        self.timestamp = Date()
        self.mood = Self.allowedMoods.contains(mood) ? mood : "😐"
    }

    func setMood(_ newMood: String) {
        mood = Self.allowedMoods.contains(newMood) ? newMood : "😐"
    }
}
