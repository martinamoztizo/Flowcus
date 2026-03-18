//
//  DebugActions.swift
//  Flowcus
//
//  Static factory methods for debug testing: synthetic reward cards, data seeding,
//  AppStorage manipulation, heat map generation, and scenario setup.
//

#if DEBUG
import SwiftUI
import SwiftData

enum DebugActions {

    // MARK: - AppStorage Reset

    static let allAppStorageKeys: [String] = [
        "workMinutes", "shortBreakMinutes", "longBreakMinutes",
        "totalXP", "sessionCount", "selectedModeRaw",
        "momentumTier", "lastSessionTimestamp",
        "sessionsToday", "sessionsTodayDate",
        "unlockedMilestones", "totalFocusMinutes", "totalFocusSessions",
        "focusHistory", "currentStreak", "lastStreakDate",
        "activeTaskID", "totalTasksCompleted", "totalJournalEntries"
    ]

    static func resetAllAppStorage() {
        let defaults = UserDefaults.standard
        for key in allAppStorageKeys {
            defaults.removeObject(forKey: key)
        }
    }

    // MARK: - Reward Card Builders

    static func buildRewardCard(
        milestoneCount: Int = 0,
        levelUp: Bool = false,
        critical: Bool = false
    ) -> RewardCardData {
        let totalXP = UserDefaults.standard.integer(forKey: "totalXP")
        let momentumTier = max(1, UserDefaults.standard.integer(forKey: "momentumTier"))

        var lines: [RewardLine] = [
            RewardLine(label: "Focus Session", xp: 25, isBonus: false),
            RewardLine(label: "Flow State", xp: 10, isBonus: true),
        ]
        if critical {
            lines.append(RewardLine(label: "Critical Focus!", xp: 25, isBonus: true))
        }
        lines.append(RewardLine(label: "Momentum (\(RewardSystem.momentumName(for: momentumTier)))", xp: momentumTier * 3, isBonus: true))

        // Grab milestones
        let unlocked = RewardSystem.parseUnlocked(UserDefaults.standard.string(forKey: "unlockedMilestones") ?? "")
        let available = RewardSystem.allMilestones.filter { !unlocked.contains($0.id) }
        let milestones = Array(available.prefix(milestoneCount))

        for m in milestones {
            lines.append(RewardLine(label: m.name, xp: m.xpReward, isBonus: true))
        }

        let reward = RewardResult(lines: lines)

        let xpBefore: Int
        let xpAfter: Int
        if levelUp {
            // Position xpBefore so that adding reward.totalXP crosses a level boundary
            let currentLevel = RewardSystem.levelInfo(for: totalXP)
            xpBefore = totalXP + currentLevel.neededXP - currentLevel.currentXP - 5
            xpAfter = xpBefore + reward.totalXP
        } else {
            xpBefore = totalXP
            xpAfter = totalXP + reward.totalXP
        }

        let levelBefore = RewardSystem.levelInfo(for: xpBefore)
        let levelAfter = RewardSystem.levelInfo(for: xpAfter)

        return RewardCardData(
            taskName: "Debug Task",
            durationMinutes: 25,
            reward: reward,
            milestones: milestones,
            levelBefore: levelBefore,
            levelAfter: levelAfter,
            didLevelUp: levelUp
        )
    }

    // MARK: - SwiftData Seeding

    static func seedTasks(context: ModelContext) {
        let titles = ["Review design mockups", "Write unit tests", "Fix login bug", "Update README", "Refactor API layer"]
        for title in titles {
            context.insert(TaskItem(title: title))
        }
        try? context.save()
    }

    static func seedRunway(context: ModelContext) {
        let big = TaskItem(title: "Ship v2.0 release")
        big.runwayTier = .big; big.runwayOrder = 0
        context.insert(big)

        let mediums = ["Write migration guide", "Update onboarding flow", "Fix dark mode bugs"]
        for (i, title) in mediums.enumerated() {
            let t = TaskItem(title: title)
            t.runwayTier = .medium; t.runwayOrder = i
            context.insert(t)
        }

        let smalls = ["Bump version number", "Add loading spinner", "Fix typo in settings", "Update app icon", "Clear build warnings"]
        for (i, title) in smalls.enumerated() {
            let t = TaskItem(title: title)
            t.runwayTier = .small; t.runwayOrder = i
            context.insert(t)
        }
        try? context.save()
    }

    static func seedOverdueTask(context: ModelContext) {
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: DebugTime.now)!
        let task = TaskItem(title: "Overdue: clean up tech debt", scheduledDate: threeDaysAgo)
        task.totalFocusMinutes = 0
        context.insert(task)
        try? context.save()
    }

    static func seedJournalEntries(context: ModelContext) {
        let entries: [(String, String, String)] = [
            ("Morning Flow", "Had a great focus session on the new feature", "🔥"),
            ("Afternoon Slump", "Struggled to focus after lunch, but pushed through", "😤"),
            ("Evening Reflection", "Productive day overall, wrapped up 3 tasks", "✨"),
        ]
        for (title, content, mood) in entries {
            let entry = JournalEntry(title: title, content: content, mood: mood)
            context.insert(entry)
        }
        try? context.save()
    }

    static func completeAllTodaysTasks(context: ModelContext) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: DebugTime.now)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        let descriptor = FetchDescriptor<TaskItem>(predicate: #Predicate {
            $0.scheduledDate >= startOfDay && $0.scheduledDate < endOfDay && !$0.isCompleted
        })
        guard let tasks = try? context.fetch(descriptor) else { return }
        for task in tasks { task.isCompleted = true }
        try? context.save()
    }

    static func wipeAllTasks(context: ModelContext) {
        try? context.delete(model: TaskItem.self)
        try? context.save()
    }

    static func wipeAllJournals(context: ModelContext) {
        try? context.delete(model: JournalEntry.self)
        try? context.save()
    }

    // MARK: - Heat Map

    static func fillHeatMap(days: Int) -> String {
        let calendar = Calendar.current
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"

        var history: [String: RewardSystem.DayRecord] = [:]
        for i in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: -i, to: DebugTime.now) else { continue }
            let key = fmt.string(from: date)
            let sessions = Int.random(in: 1...6)
            let minutes = sessions * Int.random(in: 15...35)
            history[key] = RewardSystem.DayRecord(sessions: sessions, minutes: minutes)
        }
        return RewardSystem.serializeHistory(history)
    }

    // MARK: - Scenario Setup

    /// Set AppStorage so next session triggers 3+ milestones.
    static func setupMilestoneStorm() {
        let defaults = UserDefaults.standard
        // Clear milestones so they can trigger fresh
        defaults.set("", forKey: "unlockedMilestones")
        // Set stats just below thresholds
        defaults.set(59, forKey: "totalFocusMinutes")
        defaults.set(0, forKey: "totalFocusSessions")
        defaults.set(0, forKey: "sessionsToday")
        defaults.set("", forKey: "sessionsTodayDate")
        defaults.set(0, forKey: "totalTasksCompleted")
        defaults.set(0, forKey: "totalJournalEntries")
    }

    /// Set totalXP just below next level threshold.
    static func setupNextLevelUp() {
        let defaults = UserDefaults.standard
        let current = defaults.integer(forKey: "totalXP")
        let info = RewardSystem.levelInfo(for: current)
        let xpToNextLevel = info.neededXP - info.currentXP
        // Put XP 5 below the next threshold
        let target = current + xpToNextLevel - 5
        defaults.set(target, forKey: "totalXP")
    }

    /// "Comeback Kid" — simulate 7 days away.
    static func setupComebackKid() {
        let defaults = UserDefaults.standard
        let sevenDaysAgo = DebugTime.now.addingTimeInterval(-7 * 86400)
        defaults.set(sevenDaysAgo.timeIntervalSinceReferenceDate, forKey: "lastSessionTimestamp")
        defaults.set(1, forKey: "momentumTier")
        defaults.set(0, forKey: "currentStreak")
    }

    /// "Full Runway Day" — seed a complete runway so bonuses trigger.
    static func setupFullRunwayDay(context: ModelContext) {
        seedRunway(context: context)
        // Complete all except one small task (so next session completes it)
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: DebugTime.now)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        let descriptor = FetchDescriptor<TaskItem>(predicate: #Predicate {
            $0.scheduledDate >= startOfDay && $0.scheduledDate < endOfDay
        })
        guard let tasks = try? context.fetch(descriptor) else { return }
        for task in tasks {
            if task.runwayTier != .none {
                task.isCompleted = true
            }
        }
        // Leave the last small incomplete
        if let lastSmall = tasks.last(where: { $0.runwayTier == .small }) {
            lastSmall.isCompleted = false
        }
        try? context.save()
    }
}
#endif
