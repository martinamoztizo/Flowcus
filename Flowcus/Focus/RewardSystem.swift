//
//  RewardSystem.swift
//  Flowcus
//
//  Pure logic for XP economy, levels, momentum, milestones, and variable bonus rolls.
//  No UI — consumed by FocusTimer, RewardCardView, and StatsView.
//

import Foundation

// MARK: - Data Types

struct LevelInfo {
    let level: Int
    let name: String
    let currentXP: Int
    let neededXP: Int
}

struct RewardLine {
    let label: String
    let xp: Int
    let isBonus: Bool
}

struct RewardResult {
    let lines: [RewardLine]
    var totalXP: Int { lines.reduce(0) { $0 + $1.xp } }
}

enum MilestoneCategory: String, CaseIterable {
    case gettingStarted = "Getting Started"
    case focus          = "Focus"
    case levels         = "Levels"
    case streaks        = "Streaks"
    case tasks          = "Tasks"
    case secret         = "Secret"
}

struct Milestone: Identifiable {
    let id: String
    let name: String
    let description: String
    let xpReward: Int
    let icon: FlowcusIcon
    let isHidden: Bool
    let category: MilestoneCategory
    let check: (MilestoneContext) -> Bool
}

struct MilestoneContext {
    let totalMinutes: Int
    let totalSessions: Int
    let sessionsToday: Int
    let sessionDurationMinutes: Int
    let completedFullRunway: Bool
    let currentHour: Int
    let daysSinceLastSession: Int
    let currentLevel: Int
    let currentStreak: Int
    let currentWeekday: Int
    let totalTasksCompleted: Int
    let totalJournalEntries: Int
}

// MARK: - Reward System

enum RewardSystem {

    // MARK: Level System

    private static let levels: [(name: String, threshold: Int, toNext: Int)] = [
        ("Spark",    0,    100),
        ("Kindling", 100,  150),
        ("Flame",    250,  200),
        ("Blaze",    450,  250),
        ("Furnace",  700,  300),
        ("Inferno",  1000, 400),
    ]

    static func levelInfo(for totalXP: Int) -> LevelInfo {
        // Walk defined levels
        for i in stride(from: levels.count - 1, through: 0, by: -1) {
            let (name, threshold, toNext) = levels[i]
            guard totalXP >= threshold else { continue }

            // Levels beyond 6 extend from Inferno
            if i == levels.count - 1 {
                var t = threshold, gap = toNext, lvl = i + 1
                while totalXP >= t + gap {
                    t += gap; gap += 50; lvl += 1
                }
                return LevelInfo(level: lvl, name: lvl == i + 1 ? name : "\(name) \(lvl - i)", currentXP: totalXP - t, neededXP: gap)
            }

            return LevelInfo(level: i + 1, name: name, currentXP: totalXP - threshold, neededXP: toNext)
        }
        return LevelInfo(level: 1, name: "Spark", currentXP: 0, neededXP: 100)
    }

    static func checkLevelUp(xpBefore: Int, xpAfter: Int) -> LevelInfo? {
        let after = levelInfo(for: xpAfter)
        return after.level > levelInfo(for: xpBefore).level ? after : nil
    }

    // MARK: Break XP

    static func breakXP(for mode: TimerMode) -> Int {
        mode == .longBreak ? 10 : 5
    }

    // MARK: Reward Calculation

    static func calculateReward(
        mode: TimerMode,
        didPause: Bool,
        momentumTier: Int,
        sessionsToday: Int,
        runwayBonuses: [(label: String, xp: Int)] = []
    ) -> RewardResult {
        var lines: [RewardLine] = []

        // Base XP
        let base = mode == .focus ? 25 : breakXP(for: mode)
        let modeLabel = mode == .focus ? "Focus Session" : mode == .longBreak ? "Long Break" : "Short Break"
        lines.append(RewardLine(label: modeLabel, xp: base, isBonus: false))

        guard mode == .focus else { return RewardResult(lines: lines) }

        // Flow State: no pause during focus
        if !didPause {
            lines.append(RewardLine(label: "Flow State", xp: 10, isBonus: true))
        }

        // Critical Focus: 20% chance, doubles base
        if Int.random(in: 1...5) == 1 {
            lines.append(RewardLine(label: "Critical Focus!", xp: 25, isBonus: true))
        }

        // Momentum bonus
        if momentumTier > 0 {
            let bonus = momentumTier * 3
            lines.append(RewardLine(label: "Momentum (\(momentumName(for: momentumTier)))", xp: bonus, isBonus: true))
        }

        // Daily compound
        if sessionsToday > 1 {
            lines.append(RewardLine(label: "Daily Compound", xp: (sessionsToday - 1) * 5, isBonus: true))
        }

        // Runway bonuses (passed in from FocusTimer which does the SwiftData fetch)
        for bonus in runwayBonuses {
            lines.append(RewardLine(label: bonus.label, xp: bonus.xp, isBonus: false))
        }

        return RewardResult(lines: lines)
    }

    // MARK: Momentum

    private static let momentumNames = ["Building", "Rolling", "Flowing", "Surging", "Unstoppable"]

    static func momentumName(for tier: Int) -> String {
        momentumNames[max(1, min(tier, 5)) - 1]
    }

    /// Returns updated tier after completing a session today.
    static func updatedMomentumTier(current: Int, lastSessionTimestamp: Double) -> Int {
        let gap = daysSince(lastSessionTimestamp)
        let base: Int
        if gap <= 1 { base = current }
        else if gap == 2 { base = max(1, current - 1) }
        else { base = 1 }
        return min(base + 1, 5)
    }

    /// Returns decayed tier on app open (no session completed).
    static func decayedMomentumTier(current: Int, lastSessionTimestamp: Double) -> Int {
        let gap = daysSince(lastSessionTimestamp)
        if gap <= 1 { return current }
        if gap == 2 { return max(1, current - 1) }
        return 1
    }

    static func daysSince(_ timestamp: Double) -> Int {
        guard timestamp > 0 else { return 0 }
        let calendar = Calendar.current
        let last = calendar.startOfDay(for: Date(timeIntervalSinceReferenceDate: timestamp))
        #if DEBUG
        let today = calendar.startOfDay(for: DebugTime.now)
        #else
        let today = calendar.startOfDay(for: Date())
        #endif
        return calendar.dateComponents([.day], from: last, to: today).day ?? 0
    }

    // MARK: Milestones

    static let allMilestones: [Milestone] = [
        // Getting Started
        Milestone(id: "firstSpark",    name: "First Spark",    description: "Complete your first focus session",  xpReward: 50,  icon: .msSparkles,   isHidden: false, category: .gettingStarted) { $0.totalSessions >= 1 },
        Milestone(id: "firstStep",     name: "First Step",     description: "Complete your first task",           xpReward: 50,  icon: .msCheckmark,  isHidden: false, category: .gettingStarted) { $0.totalTasksCompleted >= 1 },
        Milestone(id: "dearDiary",     name: "Dear Diary",     description: "Write your first journal entry",     xpReward: 50,  icon: .msDiary,      isHidden: false, category: .gettingStarted) { $0.totalJournalEntries >= 1 },

        // Focus
        Milestone(id: "hourOfPower",   name: "Hour of Power",  description: "60 cumulative focus minutes",        xpReward: 75,  icon: .msBolt,       isHidden: false, category: .focus) { $0.totalMinutes >= 60 },
        Milestone(id: "centurion",     name: "Centurion",      description: "100 cumulative focus minutes",       xpReward: 100, icon: .msShield,     isHidden: false, category: .focus) { $0.totalMinutes >= 100 },
        Milestone(id: "deepDiver",     name: "Deep Diver",     description: "Complete a 50+ minute session",      xpReward: 75,  icon: .msWaves,      isHidden: false, category: .focus) { $0.sessionDurationMinutes >= 50 },
        Milestone(id: "fiveADay",      name: "Five-a-Day",     description: "5 focus sessions in one day",        xpReward: 100, icon: .msStar,       isHidden: false, category: .focus) { $0.sessionsToday >= 5 },
        Milestone(id: "marathon",      name: "The Marathon",   description: "500 cumulative focus minutes",       xpReward: 150, icon: .msMarathon,   isHidden: false, category: .focus) { $0.totalMinutes >= 500 },
        Milestone(id: "tomatoGarden",  name: "Tomato Garden",  description: "50 total focus sessions",            xpReward: 100, icon: .msTomato,     isHidden: false, category: .focus) { $0.totalSessions >= 50 },
        Milestone(id: "zenMaster",     name: "Zen Master",     description: "200 total focus sessions",           xpReward: 200, icon: .msZen,        isHidden: false, category: .focus) { $0.totalSessions >= 200 },
        Milestone(id: "timeLord",      name: "Time Lord",      description: "1000 cumulative focus minutes",      xpReward: 200, icon: .msTimeLord,   isHidden: false, category: .focus) { $0.totalMinutes >= 1000 },

        // Levels
        Milestone(id: "levelingUp",    name: "Leveling Up",    description: "Reach level 5",                      xpReward: 75,  icon: .msLevelUp,    isHidden: false, category: .levels) { $0.currentLevel >= 5 },
        Milestone(id: "expert",        name: "Expert",         description: "Reach level 10",                     xpReward: 150, icon: .msExpert,     isHidden: false, category: .levels) { $0.currentLevel >= 10 },
        Milestone(id: "grandMaster",   name: "Grand Master",   description: "Reach level 25",                     xpReward: 300, icon: .msGrandMaster, isHidden: false, category: .levels) { $0.currentLevel >= 25 },

        // Streaks
        Milestone(id: "spark",         name: "Spark",          description: "3-day focus streak",                  xpReward: 50,  icon: .msSpark,      isHidden: false, category: .streaks) { $0.currentStreak >= 3 },
        Milestone(id: "onFire",        name: "On Fire",        description: "7-day focus streak",                  xpReward: 75,  icon: .msOnFire,     isHidden: false, category: .streaks) { $0.currentStreak >= 7 },
        Milestone(id: "kindling",      name: "Kindling",       description: "14-day focus streak",                 xpReward: 100, icon: .msKindling,   isHidden: false, category: .streaks) { $0.currentStreak >= 14 },
        Milestone(id: "blazing",       name: "Blazing",        description: "30-day focus streak",                 xpReward: 150, icon: .msBlazing,    isHidden: false, category: .streaks) { $0.currentStreak >= 30 },
        Milestone(id: "wildfire",      name: "Wildfire",       description: "60-day focus streak",                 xpReward: 200, icon: .msWildfire,   isHidden: true,  category: .streaks) { $0.currentStreak >= 60 },
        Milestone(id: "inferno",       name: "Inferno",        description: "100-day focus streak",                xpReward: 300, icon: .msInferno,    isHidden: true,  category: .streaks) { $0.currentStreak >= 100 },
        Milestone(id: "eternalFlame",  name: "Eternal Flame",  description: "365-day focus streak",                xpReward: 500, icon: .msEternalFlame, isHidden: true, category: .streaks) { $0.currentStreak >= 365 },

        // Tasks
        Milestone(id: "runwayCleared", name: "Runway Cleared", description: "Complete a full runway",             xpReward: 100, icon: .msRunway,     isHidden: false, category: .tasks) { $0.completedFullRunway },
        Milestone(id: "taskMaster",    name: "Task Master",    description: "Complete 100 tasks",                  xpReward: 100, icon: .msTaskMaster, isHidden: false, category: .tasks) { $0.totalTasksCompleted >= 100 },
        Milestone(id: "taskinator",    name: "Taskinator",     description: "Complete 500 tasks",                  xpReward: 200, icon: .msTaskinator, isHidden: false, category: .tasks) { $0.totalTasksCompleted >= 500 },

        // Secret
        Milestone(id: "nightOwl",      name: "Night Owl",      description: "Session completed after 10pm",       xpReward: 50,  icon: .msMoon,       isHidden: true, category: .secret) { $0.currentHour >= 22 },
        Milestone(id: "earlyBird",     name: "Early Bird",     description: "Session completed before 7am",       xpReward: 50,  icon: .msSunrise,    isHidden: true, category: .secret) { $0.currentHour < 7 },
        Milestone(id: "triplePlay",    name: "Triple Play",    description: "3 sessions in one day",              xpReward: 50,  icon: .msTriple,     isHidden: true, category: .secret) { $0.sessionsToday >= 3 },
        Milestone(id: "comeback",      name: "Comeback",       description: "Return after 5+ days away",          xpReward: 75,  icon: .msComeback,   isHidden: true, category: .secret) { $0.daysSinceLastSession >= 5 },
        Milestone(id: "tenADay",       name: "Ten-a-Day",      description: "10 focus sessions in one day",       xpReward: 150, icon: .msTenADay,    isHidden: true, category: .secret) { $0.sessionsToday >= 10 },
        Milestone(id: "weekendWarrior", name: "Weekend Warrior", description: "Focus on a weekend",               xpReward: 50,  icon: .msWeekend,    isHidden: true, category: .secret) { $0.currentWeekday == 1 || $0.currentWeekday == 7 },
        Milestone(id: "deepBreath",    name: "Deep Breath",    description: "Complete a 90+ minute session",      xpReward: 100, icon: .msDeepBreath, isHidden: true, category: .secret) { $0.sessionDurationMinutes >= 90 },
    ]

    static func checkNewMilestones(context: MilestoneContext, unlocked: Set<String>) -> [Milestone] {
        allMilestones.filter { !unlocked.contains($0.id) && $0.check(context) }
    }

    // MARK: Milestone Storage Helpers

    static func parseUnlocked(_ stored: String) -> Set<String> {
        guard !stored.isEmpty else { return [] }
        return Set(stored.split(separator: ",").map(String.init))
    }

    static func serializeUnlocked(_ set: Set<String>) -> String {
        set.sorted().joined(separator: ",")
    }

    // MARK: Focus History Helpers

    struct DayRecord {
        var sessions: Int
        var minutes: Int
    }

    static func parseHistory(_ stored: String) -> [String: DayRecord] {
        guard !stored.isEmpty else { return [:] }
        var result: [String: DayRecord] = [:]
        for entry in stored.split(separator: ",") {
            let parts = entry.split(separator: ":")
            guard parts.count == 3,
                  let sessions = Int(parts[1]),
                  let minutes = Int(parts[2]) else { continue }
            result[String(parts[0])] = DayRecord(sessions: sessions, minutes: minutes)
        }
        return result
    }

    static func serializeHistory(_ history: [String: DayRecord]) -> String {
        history.sorted { $0.key < $1.key }
            .map { "\($0.key):\($0.value.sessions):\($0.value.minutes)" }
            .joined(separator: ",")
    }

    static func recordSession(in stored: String, date: Date, minutes: Int) -> String {
        let key = dayKey(for: date)
        var history = parseHistory(stored)
        var record = history[key] ?? DayRecord(sessions: 0, minutes: 0)
        record.sessions += 1
        record.minutes += minutes
        history[key] = record
        // Prune entries older than 365 days (heat map shows 52 weeks)
        let cutoff = Calendar.current.date(byAdding: .day, value: -365, to: date)!
        let cutoffKey = dayKey(for: cutoff)
        history = history.filter { $0.key >= cutoffKey }
        return serializeHistory(history)
    }

    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static func dayKey(for date: Date) -> String {
        dayFormatter.string(from: date)
    }

    // MARK: Streak Tracking

    static func updatedStreak(current: Int, lastDate: String, today: String) -> (streak: Int, date: String) {
        guard !lastDate.isEmpty else {
            return (streak: 1, date: today)
        }
        if lastDate == today {
            return (streak: current, date: today)
        }
        // Check if lastDate was yesterday
        if let last = dayFormatter.date(from: lastDate),
           let todayDate = dayFormatter.date(from: today) {
            let diff = Calendar.current.dateComponents([.day], from: last, to: todayDate).day ?? 0
            if diff == 1 {
                return (streak: current + 1, date: today)
            }
        }
        return (streak: 1, date: today)
    }
}
