//
//  Models.swift
//  Flowcus
//
//  Created by E on 2/3/26.
//

import Foundation
import SwiftUI
import SwiftData

// MARK: - Eisenhower Quadrant

/// Represents the four quadrants of the Eisenhower Matrix, plus an "unassigned" state
/// for tasks that haven't been categorized yet.
/// Uses String raw values for safe SwiftData persistence via `quadrantRaw` on TaskItem.
enum EisenhowerQuadrant: String, Codable, CaseIterable {
    case q1 = "q1"           // Urgent + Important
    case q2 = "q2"           // Not Urgent + Important
    case q3 = "q3"           // Urgent + Not Important
    case q4 = "q4"           // Not Urgent + Not Important
    case unassigned = "unassigned"

    /// Short action-oriented label shown in the quadrant header
    var displayTitle: String {
        switch self {
        case .q1: return "Do First"
        case .q2: return "Schedule"
        case .q3: return "Delegate"
        case .q4: return "Eliminate"
        case .unassigned: return "Unsorted"
        }
    }

    /// Descriptive subtitle explaining the urgency/importance axes
    var subtitle: String {
        switch self {
        case .q1: return "Urgent & Important"
        case .q2: return "Not Urgent & Important"
        case .q3: return "Urgent & Not Important"
        case .q4: return "Not Urgent & Not Important"
        case .unassigned: return ""
        }
    }

    /// Color-coding for each quadrant — aids quick visual recognition and reduces decision fatigue
    var color: Color {
        switch self {
        case .q1: return Color(red: 0.85, green: 0.18, blue: 0.18) // Red — act now
        case .q2: return Color(red: 0.20, green: 0.65, blue: 0.35) // Green — plan it
        case .q3: return Color(red: 0.85, green: 0.65, blue: 0.10) // Yellow — hand off
        case .q4: return Color(.systemGray)                         // Gray — let go
        case .unassigned: return Color(.systemGray2)
        }
    }

    /// The four main quadrants (excludes unassigned) — used for grid layout iteration
    static var quadrants: [EisenhowerQuadrant] { [.q1, .q2, .q3, .q4] }
}

// MARK: - Runway Tier

/// Represents the three tiers of the Focus Runway (1-3-5 system), plus "none" for unassigned tasks.
/// Uses String raw values for safe SwiftData persistence via `runwayTierRaw` on TaskItem.
enum RunwayTier: String, Codable, CaseIterable {
    case none = "none"
    case big = "big"       // The 1 (max 1)
    case medium = "medium" // The 3 (max 3)
    case small = "small"   // The 5 (max 5)

    var displayTitle: String {
        switch self {
        case .none: return "None"
        case .big: return "The Big One"
        case .medium: return "Supporting Cast"
        case .small: return "Quick Win"
        }
    }

    var maxCount: Int {
        switch self {
        case .none: return .max
        case .big: return 1
        case .medium: return 3
        case .small: return 5
        }
    }

    var suggestedMinutes: Int {
        switch self {
        case .big: return 50
        case .medium: return 25
        case .small: return 5
        case .none: return 25
        }
    }

    var icon: FlowcusIcon {
        switch self {
        case .big: return .tierBig
        case .medium: return .tierMedium
        case .small: return .tierSmall
        case .none: return .tierNone
        }
    }

    var color: Color {
        switch self {
        case .big: return .orange
        case .medium: return .blue
        case .small: return .green
        case .none: return .gray
        }
    }

    /// Ordered tiers for display (excludes none)
    static var tiers: [RunwayTier] { [.big, .medium, .small] }
}

// MARK: - TASK DATA MODEL
/// Represents a single to-do item linked to a specific calendar date.
@Model
class TaskItem {
    var title: String
    var isCompleted: Bool
    var createdAt: Date
    var scheduledDate: Date // Links the task to the user's selected day in the calendar
    var focusStreak: Int = 0          // Consecutive days this task was focused on
    var lastFocusedDate: Date?        // Last date a Pomodoro session was logged for this task
    var totalFocusMinutes: Int = 0    // Cumulative Pomodoro minutes spent on this task
    // Eisenhower Matrix quadrant — stored as raw String for safe SwiftData persistence.
    // Defaults to "unassigned" so existing tasks appear in the Unsorted tray.
    var quadrantRaw: String = EisenhowerQuadrant.unassigned.rawValue
    var runwayTierRaw: String = RunwayTier.none.rawValue
    var runwayOrder: Int = 0

    /// Computed accessor for type-safe quadrant read/write over the raw String field.
    /// Not persisted directly — SwiftData stores `quadrantRaw` underneath.
    var quadrant: EisenhowerQuadrant {
        get { EisenhowerQuadrant(rawValue: quadrantRaw) ?? .unassigned }
        set { quadrantRaw = newValue.rawValue }
    }

    var runwayTier: RunwayTier {
        get { RunwayTier(rawValue: runwayTierRaw) ?? .none }
        set { runwayTierRaw = newValue.rawValue }
    }

    init(title: String, isCompleted: Bool = false, scheduledDate: Date? = nil) {
        self.title = title
        self.isCompleted = isCompleted
        #if DEBUG
        self.createdAt = DebugTime.now
        self.scheduledDate = scheduledDate ?? DebugTime.now
        #else
        self.createdAt = Date()
        self.scheduledDate = scheduledDate ?? Date()
        #endif
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

    static let defaultMood = "😐"

    init(title: String = "", content: String, mood: String = JournalEntry.defaultMood) {
        self.title = title
        self.content = content
        #if DEBUG
        self.timestamp = DebugTime.now
        #else
        self.timestamp = Date()
        #endif
        // We trust the UI (Emoji Keyboard) to provide a valid emoji string here.
        self.mood = mood
    }
}
