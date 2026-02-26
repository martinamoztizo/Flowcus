//
//  Models.swift
//  Flowcus
//
//  Created by E on 2/3/26.
//

import Foundation
import SwiftData

// MARK: - TASK DATA MODEL
/// Represents a single to-do item linked to a specific calendar date.
@Model
class TaskItem {
    var title: String
    var isCompleted: Bool
    var createdAt: Date
    var scheduledDate: Date // Links the task to the user's selected day in the calendar
    
    init(title: String, isCompleted: Bool = false, scheduledDate: Date = Date()) {
        self.title = title
        self.isCompleted = isCompleted
        self.createdAt = Date()
        self.scheduledDate = scheduledDate
    }
}

// MARK: - JOURNAL DATA MODEL
/// Represents a "Brain Dump" entry with a title, body text, and a custom emoji mood.
@Model
class JournalEntry {
    var title: String
    var content: String
    var timestamp: Date
    var mood: String // Stores a single emoji character chosen by the user (e.g., "🔥", "🤠")
    
    init(title: String = "", content: String, mood: String = "😐") {
        self.title = title
        self.content = content
        self.timestamp = Date()
        // We trust the UI (Emoji Keyboard) to provide a valid emoji string here.
        self.mood = mood
    }
}
