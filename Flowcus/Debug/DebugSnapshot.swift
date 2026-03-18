//
//  DebugSnapshot.swift
//  Flowcus
//
//  Predefined app-state snapshots for instant testing. Each snapshot defines
//  a complete AppStorage + SwiftData state. Load one to instantly jump to
//  any point in a user's journey.
//
//  To remove: delete this file. No other files reference it except DebugPanel.

#if DEBUG
import SwiftUI
import SwiftData

// MARK: - Snapshot Model

struct DebugSnapshot: Identifiable {
    let id: String
    let name: String
    let description: String
    let appStorage: [String: Any]
    let seedData: (ModelContext) -> Void
    let timeOffsetDays: Double
}

// MARK: - Loader

enum DebugSnapshotLoader {

    static func load(_ snapshot: DebugSnapshot, context: ModelContext) {
        // 1. Wipe everything
        DebugActions.resetAllAppStorage()
        DebugActions.wipeAllTasks(context: context)
        DebugActions.wipeAllJournals(context: context)
        DebugTime.shared.reset()

        // 2. Apply AppStorage
        let defaults = UserDefaults.standard
        for (key, value) in snapshot.appStorage {
            defaults.set(value, forKey: key)
        }

        // 3. Time offset
        DebugTime.shared.offset = snapshot.timeOffsetDays * 86400

        // 4. Seed SwiftData
        snapshot.seedData(context)
    }

    static func captureCurrentState(context: ModelContext) -> String {
        let defaults = UserDefaults.standard
        var lines: [String] = ["=== Current State ==="]
        for key in DebugActions.allAppStorageKeys.sorted() {
            let val = defaults.object(forKey: key) ?? "nil"
            lines.append("  \(key): \(val)")
        }
        let taskCount = (try? context.fetchCount(FetchDescriptor<TaskItem>())) ?? 0
        let journalCount = (try? context.fetchCount(FetchDescriptor<JournalEntry>())) ?? 0
        lines.append("  tasks: \(taskCount)")
        lines.append("  journals: \(journalCount)")
        lines.append("  timeOffset: \(DebugTime.shared.offset)s")
        let result = lines.joined(separator: "\n")
        print(result)
        return result
    }
}

// MARK: - Predefined Snapshots

extension DebugSnapshot {

    static let all: [DebugSnapshot] = [
        freshInstall, firstSessionDone, midWeekUser, powerUser,
        aboutToLevelUp, milestoneStormReady, comebackAfterBreak,
        fullRunwayEOD, overflowMax,
    ]

    // MARK: Helpers

    private static func today() -> String {
        RewardSystem.dayFormatter.string(from: Date())
    }

    private static func daysAgo(_ n: Int) -> String {
        let date = Calendar.current.date(byAdding: .day, value: -n, to: Date())!
        return RewardSystem.dayFormatter.string(from: date)
    }

    private static func timestamp(_ daysAgo: Int = 0) -> Double {
        Date().addingTimeInterval(Double(-daysAgo) * 86400).timeIntervalSinceReferenceDate
    }

    // MARK: 1. Fresh Install

    static let freshInstall = DebugSnapshot(
        id: "freshInstall",
        name: "Fresh Install",
        description: "Zero state — brand new user",
        appStorage: [:],
        seedData: { _ in },
        timeOffsetDays: 0
    )

    // MARK: 2. First Session Done

    static let firstSessionDone = DebugSnapshot(
        id: "firstSessionDone",
        name: "First Session Done",
        description: "1 session, ~35 XP, first milestone",
        appStorage: [
            "totalXP": 35,
            "momentumTier": 2,
            "totalFocusMinutes": 25,
            "totalFocusSessions": 1,
            "sessionsToday": 1,
            "sessionsTodayDate": today(),
            "lastSessionTimestamp": timestamp(),
            "unlockedMilestones": "firstSpark",
            "currentStreak": 1,
            "lastStreakDate": today(),
            "sessionCount": 1,
        ],
        seedData: { ctx in DebugActions.seedTasks(context: ctx) },
        timeOffsetDays: 0
    )

    // MARK: 3. Mid-Week User

    static let midWeekUser = DebugSnapshot(
        id: "midWeekUser",
        name: "Mid-Week User",
        description: "Day 3, ~250 XP, Lv2, 3-day streak",
        appStorage: [
            "totalXP": 250,
            "momentumTier": 3,
            "totalFocusMinutes": 150,
            "totalFocusSessions": 8,
            "sessionsToday": 2,
            "sessionsTodayDate": today(),
            "lastSessionTimestamp": timestamp(),
            "unlockedMilestones": "firstSpark,hourOfPower,firstStep",
            "currentStreak": 3,
            "lastStreakDate": today(),
            "sessionCount": 0,
            "totalTasksCompleted": 5,
            "totalJournalEntries": 3,
            "focusHistory": DebugActions.fillHeatMap(days: 3),
        ],
        seedData: { ctx in
            DebugActions.seedRunway(context: ctx)
            DebugActions.seedJournalEntries(context: ctx)
        },
        timeOffsetDays: 0
    )

    // MARK: 4. Power User

    static let powerUser = DebugSnapshot(
        id: "powerUser",
        name: "Power User",
        description: "~1000 XP, Lv6, 14-day streak, full heat map",
        appStorage: [
            "totalXP": 1000,
            "momentumTier": 5,
            "totalFocusMinutes": 500,
            "totalFocusSessions": 50,
            "sessionsToday": 3,
            "sessionsTodayDate": today(),
            "lastSessionTimestamp": timestamp(),
            "unlockedMilestones": "firstSpark,hourOfPower,centurion,firstStep,dearDiary,triplePlay,spark,onFire,kindling,deepDiver,marathon,tomatoGarden",
            "currentStreak": 14,
            "lastStreakDate": today(),
            "sessionCount": 1,
            "totalTasksCompleted": 40,
            "totalJournalEntries": 15,
            "focusHistory": DebugActions.fillHeatMap(days: 30),
        ],
        seedData: { ctx in
            DebugActions.seedRunway(context: ctx)
            DebugActions.seedTasks(context: ctx)
            DebugActions.seedJournalEntries(context: ctx)
        },
        timeOffsetDays: 0
    )

    // MARK: 5. About to Level Up

    static let aboutToLevelUp = DebugSnapshot(
        id: "aboutToLevelUp",
        name: "About to Level Up",
        description: "5 XP below next level — next session triggers it",
        appStorage: [
            "totalXP": 95,
            "momentumTier": 2,
            "totalFocusMinutes": 50,
            "totalFocusSessions": 3,
            "sessionsToday": 0,
            "sessionsTodayDate": "",
            "lastSessionTimestamp": timestamp(1),
            "unlockedMilestones": "firstSpark",
            "currentStreak": 2,
            "lastStreakDate": daysAgo(1),
            "sessionCount": 1,
        ],
        seedData: { ctx in DebugActions.seedTasks(context: ctx) },
        timeOffsetDays: 0
    )

    // MARK: 6. Milestone Storm Ready

    static let milestoneStormReady = DebugSnapshot(
        id: "milestoneStormReady",
        name: "Milestone Storm",
        description: "Next session unlocks 3+ milestones",
        appStorage: [
            "totalXP": 200,
            "momentumTier": 2,
            "totalFocusMinutes": 59,
            "totalFocusSessions": 0,
            "sessionsToday": 0,
            "sessionsTodayDate": "",
            "lastSessionTimestamp": timestamp(1),
            "unlockedMilestones": "",
            "currentStreak": 1,
            "lastStreakDate": daysAgo(1),
            "sessionCount": 1,
            "totalTasksCompleted": 0,
            "totalJournalEntries": 0,
        ],
        seedData: { ctx in DebugActions.seedTasks(context: ctx) },
        timeOffsetDays: 0
    )

    // MARK: 7. Comeback After Break

    static let comebackAfterBreak = DebugSnapshot(
        id: "comebackAfterBreak",
        name: "Comeback",
        description: "7 days away — decayed momentum, broken streak",
        appStorage: [
            "totalXP": 300,
            "momentumTier": 1,
            "totalFocusMinutes": 200,
            "totalFocusSessions": 10,
            "sessionsToday": 0,
            "sessionsTodayDate": "",
            "lastSessionTimestamp": timestamp(7),
            "unlockedMilestones": "firstSpark,hourOfPower,centurion",
            "currentStreak": 0,
            "lastStreakDate": daysAgo(7),
            "sessionCount": 0,
        ],
        seedData: { ctx in DebugActions.seedTasks(context: ctx) },
        timeOffsetDays: 0
    )

    // MARK: 8. Full Runway EOD

    static let fullRunwayEOD = DebugSnapshot(
        id: "fullRunwayEOD",
        name: "Full Runway EOD",
        description: "Runway almost clear — one small task left",
        appStorage: [
            "totalXP": 400,
            "momentumTier": 3,
            "totalFocusMinutes": 180,
            "totalFocusSessions": 8,
            "sessionsToday": 3,
            "sessionsTodayDate": today(),
            "lastSessionTimestamp": timestamp(),
            "unlockedMilestones": "firstSpark,hourOfPower,centurion,firstStep",
            "currentStreak": 5,
            "lastStreakDate": today(),
            "sessionCount": 0,
        ],
        seedData: { ctx in DebugActions.setupFullRunwayDay(context: ctx) },
        timeOffsetDays: 0
    )

    // MARK: 9. Overflow / Max

    static let overflowMax = DebugSnapshot(
        id: "overflowMax",
        name: "Overflow / Max",
        description: "Extreme values — stress-test all UI counters",
        appStorage: [
            "totalXP": 99999,
            "momentumTier": 5,
            "totalFocusMinutes": 50000,
            "totalFocusSessions": 2000,
            "sessionsToday": 99,
            "sessionsTodayDate": today(),
            "lastSessionTimestamp": timestamp(),
            "unlockedMilestones": RewardSystem.serializeUnlocked(Set(RewardSystem.allMilestones.map(\.id))),
            "currentStreak": 365,
            "lastStreakDate": today(),
            "sessionCount": 1,
            "totalTasksCompleted": 9999,
            "totalJournalEntries": 999,
            "focusHistory": DebugActions.fillHeatMap(days: 90),
        ],
        seedData: { ctx in
            DebugActions.seedRunway(context: ctx)
            DebugActions.seedTasks(context: ctx)
            DebugActions.seedJournalEntries(context: ctx)
        },
        timeOffsetDays: 0
    )
}
#endif
