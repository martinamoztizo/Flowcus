//
//  DebugPanel.swift
//  Flowcus
//
//  Full-screen debug testing sheet. Tap-only controls for instantly setting up
//  any app state or triggering any flow (reward cards, milestones, XP, etc.).
//

#if DEBUG
import SwiftUI
import SwiftData

struct DebugPanel: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var trigger = DebugTrigger.shared

    @AppStorage("totalXP") private var totalXP = 0
    @AppStorage("momentumTier") private var momentumTier: Int = 1
    @AppStorage("lastSessionTimestamp") private var lastSessionTimestamp: Double = 0
    @AppStorage("sessionsToday") private var sessionsToday: Int = 0
    @AppStorage("sessionsTodayDate") private var sessionsTodayDate: String = ""
    @AppStorage("unlockedMilestones") private var unlockedMilestones: String = ""
    @AppStorage("totalFocusMinutes") private var totalFocusMinutes: Int = 0
    @AppStorage("totalFocusSessions") private var totalFocusSessions: Int = 0
    @AppStorage("focusHistory") private var focusHistory: String = ""
    @AppStorage("currentStreak") private var currentStreak: Int = 0
    @AppStorage("lastStreakDate") private var lastStreakDate: String = ""
    @AppStorage("totalTasksCompleted") private var totalTasksCompleted: Int = 0
    @AppStorage("totalJournalEntries") private var totalJournalEntries: Int = 0

    @State private var confirmedLabel: String?

    var body: some View {
        NavigationStack {
            List {
                auraSection
                rewardPreviewsSection
                xpAndLevelsSection
                momentumSection
                streaksAndHistorySection
                milestonesSection
                sessionStatsSection
                swiftDataSection
                scenariosSection
                snapshotsSection
                stepperSection
                resetSection
            }
            .navigationTitle("Test Panel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Aura

    private var auraSection: some View {
        Section {
            HStack {
                Text("Current")
                    .foregroundStyle(.secondary)
                Spacer()
                let s = sessionsTodayDate == todayString ? sessionsToday : 0
                Text("\(s) sessions · Tier \(momentumTier)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                auraButton("0", sessions: 0)
                auraButton("1", sessions: 1)
                auraButton("3", sessions: 3)
                auraButton("5", sessions: 5)
                auraButton("8", sessions: 8)
            }
            .buttonStyle(.plain)
            debugButton("Full Aura (6 sessions + Tier 5 + 5d streak)") {
                sessionsToday = 6
                sessionsTodayDate = todayString
                momentumTier = 5
                currentStreak = 5
                lastStreakDate = todayString
                focusHistory = RewardSystem.recordSession(in: focusHistory, date: todayDate, minutes: 150)
            }
            debugButton("Seed + Complete Today's Tasks") {
                DebugActions.seedTasks(context: modelContext)
                DebugActions.completeAllTodaysTasks(context: modelContext)
            }
            debugButton("Empty Aura (0 sessions + Tier 1)") {
                sessionsToday = 0
                sessionsTodayDate = ""
                momentumTier = 1
                currentStreak = 0
            }
        } header: {
            Text("Aura")
        } footer: {
            Text("Sets sessions/momentum to preview Thermal Core intensity. Switch to Aura tab to see changes.")
        }
    }

    private var todayString: String {
        #if DEBUG
        RewardSystem.dayFormatter.string(from: DebugTime.now)
        #else
        RewardSystem.dayFormatter.string(from: Date())
        #endif
    }

    private var todayDate: Date {
        #if DEBUG
        DebugTime.now
        #else
        Date()
        #endif
    }

    private func auraButton(_ label: String, sessions: Int) -> some View {
        let current = sessionsTodayDate == todayString ? sessionsToday : 0
        let selected = current == sessions
        return Button {
            sessionsToday = sessions
            sessionsTodayDate = sessions > 0 ? todayString : ""
            if sessions > 0 {
                let minutes = sessions * 25
                focusHistory = RewardSystem.recordSession(in: "", date: todayDate, minutes: minutes)
            }
            Haptics.impact(.light)
        } label: {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Capsule().fill(selected ? Color.cardinalRed : Color(.systemGray5)))
                .foregroundStyle(selected ? .white : .primary)
        }
        .animation(.easeInOut(duration: 0.15), value: selected)
    }

    // MARK: - Reward Previews

    private var rewardPreviewsSection: some View {
        Section("Reward Previews") {
            debugButton("Basic Card") {
                let card = DebugActions.buildRewardCard()
                dismissThenTrigger {
                    trigger.pendingRewardCard = card
                    trigger.rewardCardTrigger += 1
                }
            }
            debugButton("Card + Milestones") {
                let card = DebugActions.buildRewardCard(milestoneCount: 2)
                dismissThenTrigger {
                    trigger.pendingRewardCard = card
                    trigger.rewardCardTrigger += 1
                }
            }
            debugButton("Card + Level Up") {
                let card = DebugActions.buildRewardCard(levelUp: true)
                dismissThenTrigger {
                    trigger.pendingRewardCard = card
                    trigger.rewardCardTrigger += 1
                }
            }
            debugButton("Card + Milestones + Level Up") {
                let card = DebugActions.buildRewardCard(milestoneCount: 3, levelUp: true, critical: true)
                dismissThenTrigger {
                    trigger.pendingRewardCard = card
                    trigger.rewardCardTrigger += 1
                }
            }
            debugButton("Mini Break Card") {
                let level = RewardSystem.levelInfo(for: totalXP)
                dismissThenTrigger { trigger.pendingMiniReward = MiniRewardData(xp: 10, level: level) }
            }
        }
    }

    // MARK: - XP & Levels

    private var xpAndLevelsSection: some View {
        Section {
            let info = RewardSystem.levelInfo(for: totalXP)
            HStack {
                Text("Current")
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(totalXP) XP — Lv \(info.level) \(info.name)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                xpButton("0", xp: 0)
                xpButton("95", xp: 95)
                xpButton("245", xp: 245)
                xpButton("695", xp: 695)
                xpButton("995", xp: 995)
            }
            .buttonStyle(.plain)
            HStack(spacing: 8) {
                debugButton("+500 XP") { totalXP += 500 }
                debugButton("+2000 XP") { totalXP += 2000 }
            }
            .buttonStyle(.plain)
        } header: {
            Text("XP & Levels")
        }
    }

    // MARK: - Momentum

    private var momentumSection: some View {
        Section {
            HStack {
                Text("Current")
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Tier \(momentumTier) — \(RewardSystem.momentumName(for: momentumTier))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                momentumButton("Tier 1", tier: 1)
                momentumButton("Tier 3", tier: 3)
                momentumButton("Tier 5", tier: 5)
            }
            .buttonStyle(.plain)
            debugButton("Simulate 3-Day Decay") {
                let threeDaysAgo = DebugTime.now.addingTimeInterval(-3 * 86400)
                lastSessionTimestamp = threeDaysAgo.timeIntervalSinceReferenceDate
                momentumTier = RewardSystem.decayedMomentumTier(current: momentumTier, lastSessionTimestamp: lastSessionTimestamp)
            }
        } header: {
            Text("Momentum")
        }
    }

    // MARK: - Streaks & History

    private var streaksAndHistorySection: some View {
        Section {
            HStack {
                Text("Streak")
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(currentStreak) days")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                streakButton("3", streak: 3)
                streakButton("7", streak: 7)
                streakButton("30", streak: 30)
            }
            .buttonStyle(.plain)
            debugButton("Fill Heat Map 30d") { focusHistory = DebugActions.fillHeatMap(days: 30) }
            debugButton("Fill Heat Map 90d") { focusHistory = DebugActions.fillHeatMap(days: 90) }
            debugButton("Clear Heat Map") { focusHistory = "" }
        } header: {
            Text("Streaks & History")
        }
    }

    // MARK: - Milestones

    private var milestonesSection: some View {
        Section {
            let unlockedCount = RewardSystem.parseUnlocked(unlockedMilestones).count
            HStack {
                Text("Unlocked")
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(unlockedCount) / \(RewardSystem.allMilestones.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            debugButton("Unlock All") {
                let all = Set(RewardSystem.allMilestones.map(\.id))
                unlockedMilestones = RewardSystem.serializeUnlocked(all)
            }
            debugButton("Unlock First 5") {
                let first5 = Set(RewardSystem.allMilestones.prefix(5).map(\.id))
                unlockedMilestones = RewardSystem.serializeUnlocked(first5)
            }
            debugButton("Clear All") { unlockedMilestones = "" }
        } header: {
            Text("Milestones")
        }
    }

    // MARK: - Session Stats

    private var sessionStatsSection: some View {
        Section {
            debugButton("sessionsToday → 4") { sessionsToday = 4 }
            debugButton("totalSessions → 49") { totalFocusSessions = 49 }
            debugButton("totalMinutes → 59") { totalFocusMinutes = 59 }
            debugButton("totalMinutes → 499") { totalFocusMinutes = 499 }
            debugButton("tasksCompleted → 99") { totalTasksCompleted = 99 }
        } header: {
            Text("Session Stats")
        }
    }

    // MARK: - SwiftData

    private var swiftDataSection: some View {
        Section {
            debugButton("Seed 5 Tasks") { DebugActions.seedTasks(context: modelContext) }
            debugButton("Seed Overdue Task") { DebugActions.seedOverdueTask(context: modelContext) }
            debugButton("Seed Full Runway") { DebugActions.seedRunway(context: modelContext) }
            debugButton("Complete All Today's Tasks") { DebugActions.completeAllTodaysTasks(context: modelContext) }
            debugButton("Seed Journal Entries") { DebugActions.seedJournalEntries(context: modelContext) }
            debugButton("Wipe Tasks", destructive: true) { DebugActions.wipeAllTasks(context: modelContext) }
            debugButton("Wipe Journals", destructive: true) { DebugActions.wipeAllJournals(context: modelContext) }
        } header: {
            Text("SwiftData")
        }
    }

    // MARK: - Scenarios

    private var scenariosSection: some View {
        Section {
            debugButton("Next Session Levels Up") { DebugActions.setupNextLevelUp() }
            debugButton("Milestone Storm") { DebugActions.setupMilestoneStorm() }
            debugButton("Comeback Kid") { DebugActions.setupComebackKid() }
            debugButton("Full Runway Day") { DebugActions.setupFullRunwayDay(context: modelContext) }
        } header: {
            Text("Scenarios")
        } footer: {
            Text("Sets AppStorage so the next completed session triggers the scenario.")
        }
    }

    // MARK: - Reset

    private var resetSection: some View {
        Section {
            debugButton("Reset AppStorage", destructive: true) {
                DebugActions.resetAllAppStorage()
            }
            debugButton("Reset Time Travel", destructive: true) {
                DebugTime.shared.reset()
            }
            debugButton("Nuclear Reset", destructive: true) {
                DebugActions.resetAllAppStorage()
                DebugActions.wipeAllTasks(context: modelContext)
                DebugActions.wipeAllJournals(context: modelContext)
                DebugTime.shared.reset()
            }
        } header: {
            Text("Reset")
        } footer: {
            Text("AppStorage reset takes effect immediately for new reads, but some live views may need an app relaunch to reflect changes.")
        }
    }

    // MARK: - Snapshots

    private var snapshotsSection: some View {
        Section {
            ForEach(DebugSnapshot.all) { snapshot in
                debugButton(snapshot.name) {
                    DebugSnapshotLoader.load(snapshot, context: modelContext)
                }
            }
            debugButton("Capture State → Console") {
                _ = DebugSnapshotLoader.captureCurrentState(context: modelContext)
            }
        } header: {
            Text("Snapshots")
        } footer: {
            Text("Wipes all data and loads a predefined state. Capture prints current state to Xcode console.")
        }
    }

    // MARK: - Guided Stepper

    private var stepperSection: some View {
        Section {
            ForEach(DebugSequences.all, id: \.name) { seq in
                Button {
                    DebugStepper.shared.start(name: seq.name, steps: seq.steps)
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(seq.name)
                            .foregroundStyle(Color.cardinalRed)
                        Text(seq.description)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            if DebugStepper.shared.isActive {
                debugButton("Stop Stepper", destructive: true) {
                    DebugStepper.shared.stop()
                }
            }
        } header: {
            Text("Guided Stepper")
        } footer: {
            Text("Launches a floating step-by-step walkthrough. Dismiss panel to use it.")
        }
    }

    // MARK: - Helpers

    private func debugButton(_ title: String, destructive: Bool = false, action: @escaping () -> Void) -> some View {
        let confirmed = confirmedLabel == title
        return Button {
            action()
            Haptics.impact(.light)
            confirmedLabel = title
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                if confirmedLabel == title { confirmedLabel = nil }
            }
        } label: {
            HStack(spacing: 4) {
                Text(confirmed ? "✓ \(title)" : title)
                    .animation(nil, value: confirmed)
            }
        }
        .foregroundStyle(confirmed ? .green : (destructive ? .red : Color.cardinalRed))
        .animation(.easeInOut(duration: 0.15), value: confirmed)
    }

    private func xpButton(_ label: String, xp: Int) -> some View {
        let selected = totalXP == xp
        return Button {
            totalXP = xp
            Haptics.impact(.light)
        } label: {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Capsule().fill(selected ? Color.cardinalRed : Color(.systemGray5)))
                .foregroundStyle(selected ? .white : .primary)
        }
        .animation(.easeInOut(duration: 0.15), value: selected)
    }

    private func momentumButton(_ label: String, tier: Int) -> some View {
        let selected = momentumTier == tier
        return Button {
            momentumTier = tier
            Haptics.impact(.light)
        } label: {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Capsule().fill(selected ? Color.cardinalRed : Color(.systemGray5)))
                .foregroundStyle(selected ? .white : .primary)
        }
        .animation(.easeInOut(duration: 0.15), value: selected)
    }

    private func streakButton(_ label: String, streak: Int) -> some View {
        let selected = currentStreak == streak
        return Button {
            currentStreak = streak
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd"
            lastStreakDate = fmt.string(from: DebugTime.now)
            Haptics.impact(.light)
        } label: {
            Text("\(label)d")
                .font(.caption)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Capsule().fill(selected ? Color.cardinalRed : Color(.systemGray5)))
                .foregroundStyle(selected ? .white : .primary)
        }
        .animation(.easeInOut(duration: 0.15), value: selected)
    }

    /// Dismiss the panel first, then trigger the action after a short delay
    /// (sheet-on-sheet doesn't work in iOS).
    private func dismissThenTrigger(_ action: @escaping () -> Void) {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            action()
        }
    }
}
#endif
