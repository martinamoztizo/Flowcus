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

struct Milestone: Identifiable {
    let id: String
    let name: String
    let description: String
    let xpReward: Int
    let sfSymbol: String
    let isHidden: Bool
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
        let base = mode == .focus ? 25 : mode == .longBreak ? 10 : 5
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
        let today = calendar.startOfDay(for: Date())
        return calendar.dateComponents([.day], from: last, to: today).day ?? 0
    }

    // MARK: Milestones

    static let allMilestones: [Milestone] = [
        // Visible
        Milestone(id: "firstSpark",    name: "First Spark",    description: "Complete your first focus session",  xpReward: 50,  sfSymbol: "sparkles",              isHidden: false) { $0.totalSessions >= 1 },
        Milestone(id: "hourOfPower",   name: "Hour of Power",  description: "60 cumulative focus minutes",        xpReward: 75,  sfSymbol: "bolt.fill",             isHidden: false) { $0.totalMinutes >= 60 },
        Milestone(id: "centurion",     name: "Centurion",      description: "100 cumulative focus minutes",       xpReward: 100, sfSymbol: "shield.fill",           isHidden: false) { $0.totalMinutes >= 100 },
        Milestone(id: "deepDiver",     name: "Deep Diver",     description: "Complete a 50+ minute session",      xpReward: 75,  sfSymbol: "water.waves",           isHidden: false) { $0.sessionDurationMinutes >= 50 },
        Milestone(id: "runwayCleared", name: "Runway Cleared", description: "Complete a full runway",             xpReward: 100, sfSymbol: "airplane.departure",    isHidden: false) { $0.completedFullRunway },
        Milestone(id: "fiveADay",      name: "Five-a-Day",     description: "5 focus sessions in one day",        xpReward: 100, sfSymbol: "star.fill",             isHidden: false) { $0.sessionsToday >= 5 },
        // Hidden
        Milestone(id: "nightOwl",      name: "Night Owl",      description: "Session completed after 10pm",       xpReward: 50,  sfSymbol: "moon.stars.fill",       isHidden: true) { $0.currentHour >= 22 },
        Milestone(id: "earlyBird",     name: "Early Bird",     description: "Session completed before 7am",       xpReward: 50,  sfSymbol: "sunrise.fill",          isHidden: true) { $0.currentHour < 7 },
        Milestone(id: "triplePlay",    name: "Triple Play",    description: "3 sessions in one day",              xpReward: 50,  sfSymbol: "3.circle.fill",         isHidden: true) { $0.sessionsToday >= 3 },
        Milestone(id: "comeback",      name: "Comeback",       description: "Return after 5+ days away",          xpReward: 75,  sfSymbol: "arrow.uturn.up.circle.fill", isHidden: true) { $0.daysSinceLastSession >= 5 },
        Milestone(id: "marathon",      name: "The Marathon",   description: "500 cumulative focus minutes",       xpReward: 150, sfSymbol: "figure.run",            isHidden: true) { $0.totalMinutes >= 500 },
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
}
