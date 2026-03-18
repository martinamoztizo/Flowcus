//
//  FocusTimer.swift
//  Flowcus
//

import SwiftUI
import SwiftData

// MARK: - Wave Shape
struct Wave: Shape {
    var offset: Angle
    var percent: Double

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(offset.degrees, percent) }
        set {
            offset = Angle(degrees: newValue.first)
            percent = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let waveHeight = 0.025 * rect.height
        let yOffset = rect.height * (1.0 - CGFloat(percent))

        path.move(to: CGPoint(x: 0, y: yOffset))

        for x in stride(from: 0, to: rect.width, by: 2) {
            let relativeX = x / rect.width
            let sine = sin(relativeX * 3 * .pi + offset.radians)
            let y = yOffset + (sine * waveHeight)
            path.addLine(to: CGPoint(x: x, y: y))
        }

        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()

        return path
    }
}

// MARK: - Focus Timer View
struct FocusTimerView: View {
    @EnvironmentObject private var timerManager: TimeManager
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.modelContext) private var modelContext

    // PERMANENT SETTINGS
    @AppStorage("workMinutes") private var defaultWorkTime = 25
    @AppStorage("shortBreakMinutes") private var shortBreakTime = 5
    @AppStorage("longBreakMinutes") private var longBreakTime = 15
    @AppStorage("sessionCount") private var sessionCount = 0
    @AppStorage("totalXP") private var totalXP = 0

    // PERSIST MODE (Safe String Storage)
    @AppStorage("selectedModeRaw") private var selectedModeRaw: String = TimerMode.focus.rawValue
    @AppStorage("activeTaskID") private var activeTaskID: String = ""
    @AppStorage("momentumTier") private var momentumTier: Int = 1
    @AppStorage("lastSessionTimestamp") private var lastSessionTimestamp: Double = 0
    @AppStorage("sessionsToday") private var sessionsToday: Int = 0
    @AppStorage("sessionsTodayDate") private var sessionsTodayDate: String = ""
    @AppStorage("unlockedMilestones") private var unlockedMilestones: String = ""
    @AppStorage("focusHistory") private var focusHistory: String = ""
    @AppStorage("totalFocusMinutes") private var totalFocusMinutes: Int = 0
    @AppStorage("totalFocusSessions") private var totalFocusSessions: Int = 0
    @AppStorage("totalTasksCompleted") private var totalTasksCompleted: Int = 0
    @AppStorage("totalJournalEntries") private var totalJournalEntries: Int = 0

    var selectedMode: TimerMode {
        get { TimerMode(rawValue: selectedModeRaw) ?? .focus }
        nonmutating set { selectedModeRaw = newValue.rawValue }
    }

    @State private var showingSettings = false
    @State private var activeTask: TaskItem? = nil
    @State private var showTaskPicker = false
    @State private var shouldStartAfterPicker = false
    @State private var showMoodPrompt = false
    @State private var completedTask: TaskItem? = nil
    @State private var completedDuration: Int = 0
    @State private var showStopConfirmation = false
    @State private var nudgeTask: TaskItem? = nil
    @State private var showRewardCard = false
    @State private var rewardCardData: RewardCardData? = nil
    @State private var showMiniRewardCard = false
    @State private var miniRewardXP: Int = 0
    @State private var miniRewardLevel: LevelInfo = RewardSystem.levelInfo(for: 0)

    let modes = TimerMode.allCases

    var isPaused: Bool {
        return !timerManager.isRunning && timerManager.timeRemaining < timerManager.initialTime && timerManager.timeRemaining > 0
    }

    var isSessionActive: Bool {
        return timerManager.isRunning || isPaused
    }

    // Height Logic: 1.03 buffer for full screen coverage
    var liquidHeightPercentage: Double {
        if !isSessionActive { return 0.0 }
        guard timerManager.initialTime > 0 else { return 1.0 }
        let rawPercent = timerManager.timeRemaining / timerManager.initialTime
        return min(rawPercent * 1.03, 1.03)
    }

    // MARK: - DYNAMIC COLORS
    var themeColors: [Color] {
        switch selectedMode {
        case .shortBreak:
            return [Color.teal.opacity(0.8), Color.cyan.opacity(0.6)]
        case .longBreak:
            return [Color(red: 0.4, green: 0.8, blue: 0.6).opacity(0.9), Color.mint.opacity(0.7)]
        case .focus:
            return [Color.red.opacity(0.9), Color.red.opacity(0.7)]
        }
    }

    var contentColor: Color {
        if isSessionActive {
            return .white
        } else {
            return colorScheme == .dark ? .white : .black
        }
    }

    var backgroundColor: Color {
        if isSessionActive {
            return .black
        } else {
            return colorScheme == .dark ? .black : .white
        }
    }

    var preferredScheme: ColorScheme? {
        if isSessionActive { return .dark }
        return nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // 1. BACKGROUND (Dynamic)
                backgroundColor
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.5), value: isSessionActive)

                // 2. CONTINUOUS LIQUID WAVES
                GeometryReader { geo in
                    ZStack(alignment: .bottom) {
                        TimelineView(.animation) { timeline in
                            let time = timeline.date.timeIntervalSinceReferenceDate

                            ZStack(alignment: .bottom) {
                                Wave(offset: Angle(degrees: time * 50), percent: 1.1)
                                    .fill(themeColors[1])
                                    .ignoresSafeArea()

                                Wave(offset: Angle(degrees: time * 70 + 90), percent: 1.1)
                                    .fill(themeColors[0])
                                    .ignoresSafeArea()
                            }
                        }
                    }
                    .offset(y: geo.size.height * (1.1 - liquidHeightPercentage))
                    .animation(.spring(response: 2.0, dampingFraction: 1.0), value: liquidHeightPercentage)
                }
                .ignoresSafeArea(.all)

                // 3. CONTENT OVERLAY
                VStack(spacing: 0) {
                    Spacer()

                    TimerDisplayView(
                        timeString: timerManager.timeString,
                        isPaused: isPaused,
                        contentColor: contentColor,
                        activeTaskTitle: selectedMode == .focus ? activeTask?.title : nil,
                        onTap: handleTap
                    )

                    if selectedMode == .focus, !isSessionActive, let task = nudgeTask {
                        JustFiveMinutesCard(task: task, onLaunch: { launchNudge(task) }, onDismiss: { nudgeTask = nil })
                            .padding(.horizontal, 40)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    Spacer()

                    TimerControlsView(
                        isRunning: timerManager.isRunning,
                        isPaused: isPaused,
                        selectedMode: Binding(
                            get: { selectedMode },
                            set: { selectedMode = $0 }
                        ),
                        modes: modes,
                        contentColor: contentColor,
                        themeColor: themeColors[0],
                        onTapRunning: handleTap,
                        onStop: { showStopConfirmation = true },
                        onStart: {
                            nudgeTask = nil
                            // Show task picker first if in focus mode and no task selected
                            if selectedMode == .focus && activeTask == nil {
                                showTaskPicker = true
                            } else {
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                    timerManager.start()
                                    Haptics.impact(.heavy)
                                }
                            }
                        }
                    )
                }
            }
            .preferredColorScheme(preferredScheme)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !isSessionActive {
                        Button(action: { showingSettings = true }) {
                            Image(systemName: "gearshape.fill").foregroundStyle(contentColor.opacity(0.5))
                        }
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView().onDisappear { updateTimerForMode(selectedMode) }
            }
            .sheet(isPresented: $showTaskPicker, onDismiss: {
                if shouldStartAfterPicker {
                    shouldStartAfterPicker = false
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        timerManager.start()
                        Haptics.impact(.heavy)
                    }
                }
            }) {
                TaskPickerSheetView(activeTask: $activeTask, shouldStart: $shouldStartAfterPicker)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .alert("End this session?", isPresented: $showStopConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("End Session", role: .destructive) {
                    stopTimer()
                    activeTask = nil
                    activeTaskID = ""
                }
            }
            .sheet(isPresented: $showRewardCard, onDismiss: {
                showMoodPrompt = true
            }) {
                if let data = rewardCardData {
                    RewardCardView(data: data) { showRewardCard = false }
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.visible)
                        .interactiveDismissDisabled()
                }
            }
            .sheet(isPresented: $showMiniRewardCard) {
                MiniRewardCardView(xp: miniRewardXP, levelInfo: miniRewardLevel) {
                    showMiniRewardCard = false
                }
                .presentationDetents([.height(200)])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showMoodPrompt) {
                SessionMoodPromptView(
                    task: completedTask,
                    durationMinutes: completedDuration,
                    onSelect: { emoji in
                        logJournalEntry(emoji: emoji)
                        showMoodPrompt = false
                    },
                    onSkip: { showMoodPrompt = false }
                )
                .presentationDetents([.height(320)])
                .presentationDragIndicator(.visible)
                .interactiveDismissDisabled()
            }
            .onChange(of: timerManager.completionEvents) { _, _ in
                completeSession()
                findNudgeTask()
            }
            .onChange(of: isSessionActive) { _, active in
                if !active { findNudgeTask() }
            }
            .onChange(of: selectedMode) { _, newMode in
                 if !timerManager.isRunning { updateTimerForMode(newMode) }
            }
            .onAppear {
                if !timerManager.isRunning { updateTimerForMode(selectedMode) }
                loadActiveTaskFromStorage()
                findNudgeTask()
            }
            .onChange(of: activeTaskID) { _, _ in
                loadActiveTaskFromStorage()
            }
        }
    }

    // MARK: - LOGIC

    private func handleTap() {
        if timerManager.isRunning {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                timerManager.pause()
                Haptics.impact(.medium)
            }
        } else if isPaused {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                timerManager.start()
                Haptics.impact(.medium)
            }
        }
    }

    private func stopTimer() {
        withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
            timerManager.pause()
            updateTimerForMode(selectedMode)
        }
        Haptics.impact(.medium)
    }

    private func incrementSessionsToday() -> Int {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let today = fmt.string(from: Date())
        if sessionsTodayDate != today {
            sessionsToday = 1
            sessionsTodayDate = today
        } else {
            sessionsToday += 1
        }
        return sessionsToday
    }

    private func completeSession() {
        timerManager.pause()
        Haptics.impact(.heavy)

        withAnimation {
            if selectedMode == .focus {
                // 1. Capture context
                sessionCount += 1
                completedTask = activeTask
                completedDuration = Int(timerManager.initialTime / 60)

                if let task = activeTask {
                    updateTaskStreak(task, minutes: completedDuration)
                }

                // 2. Cycle Pomodoro mode
                if sessionCount >= 2 {
                    selectedMode = .longBreak
                    sessionCount = 0
                } else {
                    selectedMode = .shortBreak
                }

                // 3. Compute bonuses
                let runwayBonuses = computeRunwayBonuses()
                let todaySessions = incrementSessionsToday()

                // 4. Calculate reward
                let reward = RewardSystem.calculateReward(
                    mode: .focus,
                    didPause: timerManager.didPauseThisSession,
                    momentumTier: momentumTier,
                    sessionsToday: todaySessions,
                    runwayBonuses: runwayBonuses
                )

                // 5. Check milestones (use OLD lastSessionTimestamp for comeback check)
                let milestoneCtx = MilestoneContext(
                    totalMinutes: totalFocusMinutes + completedDuration,
                    totalSessions: totalFocusSessions + 1,
                    sessionsToday: todaySessions,
                    sessionDurationMinutes: completedDuration,
                    completedFullRunway: runwayBonuses.contains { $0.label == "Full Runway Clear" },
                    currentHour: Calendar.current.component(.hour, from: Date()),
                    daysSinceLastSession: RewardSystem.daysSince(lastSessionTimestamp),
                    currentLevel: RewardSystem.levelInfo(for: totalXP).level,
                    currentStreak: momentumTier,
                    currentWeekday: Calendar.current.component(.weekday, from: Date()),
                    totalTasksCompleted: totalTasksCompleted,
                    totalJournalEntries: totalJournalEntries
                )
                let unlockedSet = RewardSystem.parseUnlocked(unlockedMilestones)
                let newMilestones = RewardSystem.checkNewMilestones(context: milestoneCtx, unlocked: unlockedSet)

                // 6. Merge milestone XP into reward lines
                var combinedLines = reward.lines
                for m in newMilestones {
                    combinedLines.append(RewardLine(label: m.name, xp: m.xpReward, isBonus: true))
                }
                let combinedReward = RewardResult(lines: combinedLines)

                // 7. Apply XP (single write)
                let xpBefore = totalXP
                totalXP += combinedReward.totalXP
                let levelUp = RewardSystem.checkLevelUp(xpBefore: xpBefore, xpAfter: totalXP)

                // 8. Update persistence (AFTER reward calc uses old values)
                momentumTier = RewardSystem.updatedMomentumTier(current: momentumTier, lastSessionTimestamp: lastSessionTimestamp)
                lastSessionTimestamp = Date().timeIntervalSinceReferenceDate
                totalFocusMinutes += completedDuration
                totalFocusSessions += 1
                if !newMilestones.isEmpty {
                    var updated = unlockedSet
                    for m in newMilestones { updated.insert(m.id) }
                    unlockedMilestones = RewardSystem.serializeUnlocked(updated)
                }

                // Record session for heat map
                focusHistory = RewardSystem.recordSession(in: focusHistory, date: Date(), minutes: completedDuration)

                // 9. Clear active task
                activeTask = nil
                activeTaskID = ""

                // 10. Build RewardCardData and show
                let levelBefore = RewardSystem.levelInfo(for: xpBefore)
                let levelAfter = RewardSystem.levelInfo(for: totalXP)
                rewardCardData = RewardCardData(
                    taskName: completedTask?.title,
                    durationMinutes: completedDuration,
                    reward: combinedReward,
                    milestones: newMilestones,
                    levelBefore: levelBefore,
                    levelAfter: levelAfter,
                    didLevelUp: levelUp != nil
                )
                showRewardCard = true
            } else if selectedMode == .longBreak {
                // Long break: route through RewardSystem
                let breakReward = RewardSystem.calculateReward(
                    mode: .longBreak,
                    didPause: false,
                    momentumTier: momentumTier,
                    sessionsToday: sessionsToday
                )
                totalXP += breakReward.totalXP
                miniRewardXP = breakReward.totalXP
                miniRewardLevel = RewardSystem.levelInfo(for: totalXP)
                showMiniRewardCard = true
                selectedMode = .focus
            } else {
                // Short break: route through RewardSystem
                let breakReward = RewardSystem.calculateReward(
                    mode: .shortBreak,
                    didPause: false,
                    momentumTier: momentumTier,
                    sessionsToday: sessionsToday
                )
                totalXP += breakReward.totalXP
                selectedMode = .focus
            }
            updateTimerForMode(selectedMode)
        }
    }

    private func updateTaskStreak(_ task: TaskItem, minutes: Int) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        if let lastDate = task.lastFocusedDate {
            let lastDay = calendar.startOfDay(for: lastDate)
            let diff = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0
            if diff == 1 {
                task.focusStreak += 1      // consecutive day — extend streak
            } else if diff > 1 {
                task.focusStreak = 1       // gap — restart streak
            }
            // diff == 0: same day, keep current streak value
        } else {
            task.focusStreak = 1           // first focus session on this task
        }

        task.lastFocusedDate = Date()
        task.totalFocusMinutes += minutes
    }

    private func logJournalEntry(emoji: String) {
        let taskName = completedTask?.title ?? "a focus session"
        let duration = completedDuration
        let content = "Completed a \(duration)-minute focus session on: \(taskName)"
        let entry = JournalEntry(title: "Focus Session", content: content, mood: emoji)
        modelContext.insert(entry)
    }

    private func updateTimerForMode(_ mode: TimerMode) {
        guard !timerManager.isRunning else { return }
        switch mode {
        case .focus:
            // Use tier-appropriate duration if an active task has a runway tier
            if let task = activeTask, task.runwayTier == .small {
                timerManager.setDuration(minutes: 5)
            } else {
                timerManager.setDuration(minutes: defaultWorkTime)
            }
        case .shortBreak: timerManager.setDuration(minutes: shortBreakTime)
        case .longBreak: timerManager.setDuration(minutes: longBreakTime)
        }
    }

    private func computeRunwayBonuses() -> [(label: String, xp: Int)] {
        guard let task = completedTask, task.runwayTier != .none else { return [] }

        var bonuses: [(label: String, xp: Int)] = []
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let tier = task.runwayTier
        let tierRaw = tier.rawValue
        let descriptor = FetchDescriptor<TaskItem>(predicate: #Predicate {
            $0.scheduledDate >= startOfDay && $0.scheduledDate < endOfDay
            && $0.runwayTierRaw == tierRaw
        })

        guard let tierTasks = try? modelContext.fetch(descriptor) else { return [] }
        let allDone = tierTasks.allSatisfy { $0.isCompleted }

        if allDone {
            let tierXP: Int
            switch tier {
            case .small: tierXP = 10
            case .medium: tierXP = 25
            case .big: tierXP = 50
            case .none: tierXP = 0
            }
            if tierXP > 0 {
                bonuses.append((label: "\(tier.rawValue.capitalized) Tier Clear", xp: tierXP))
            }

            // Check if entire runway is complete
            let allTiersRaw = RunwayTier.tiers.map(\.rawValue)
            let allRunwayDescriptor = FetchDescriptor<TaskItem>(predicate: #Predicate {
                $0.scheduledDate >= startOfDay && $0.scheduledDate < endOfDay
                && allTiersRaw.contains($0.runwayTierRaw)
            })
            if let allRunway = try? modelContext.fetch(allRunwayDescriptor),
               !allRunway.isEmpty,
               allRunway.allSatisfy({ $0.isCompleted }) {
                bonuses.append((label: "Full Runway Clear", xp: 100))
            }
        }

        return bonuses
    }

    // MARK: - Just 5 Minutes Nudge

    private func findNudgeTask() {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: startOfDay)!

        let descriptor = FetchDescriptor<TaskItem>(predicate: #Predicate {
            $0.scheduledDate >= startOfDay && $0.scheduledDate < endOfDay && !$0.isCompleted
        })
        guard let tasks = try? modelContext.fetch(descriptor) else { return }

        nudgeTask = tasks.first { task in
            if let lastFocused = task.lastFocusedDate {
                return lastFocused < twoDaysAgo
            } else {
                return task.createdAt < twoDaysAgo
            }
        }
    }

    private func launchNudge(_ task: TaskItem) {
        activeTask = task
        activeTaskID = String(task.createdAt.timeIntervalSinceReferenceDate)
        timerManager.setDuration(minutes: 5)
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            timerManager.start()
            Haptics.impact(.heavy)
        }
        nudgeTask = nil
    }

    /// Load active task from persisted createdAt timestamp
    private func loadActiveTaskFromStorage() {
        guard !activeTaskID.isEmpty, activeTask == nil else { return }
        guard let interval = Double(activeTaskID) else { return }
        let targetDate = Date(timeIntervalSinceReferenceDate: interval)
        // Small window around the exact timestamp for floating-point safety
        let lo = targetDate.addingTimeInterval(-0.001)
        let hi = targetDate.addingTimeInterval(0.001)
        let descriptor = FetchDescriptor<TaskItem>(predicate: #Predicate {
            $0.createdAt >= lo && $0.createdAt <= hi
        })
        if let task = try? modelContext.fetch(descriptor).first {
            activeTask = task
            // Apply tier-appropriate duration
            if selectedMode == .focus {
                updateTimerForMode(.focus)
            }
        }
    }
}

// MARK: - SUBVIEWS FOR COMPILER OPTIMIZATION
struct TimerDisplayView: View {
    let timeString: String
    let isPaused: Bool
    let contentColor: Color
    var activeTaskTitle: String? = nil
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            // Active task label above timer
            if let title = activeTaskTitle {
                Text(title)
                    .font(.appSubhead)
                    .fontWeight(.medium)
                    .foregroundStyle(contentColor.opacity(0.75))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.horizontal, 40)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Text(timeString)
                .font(.system(size: 95, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(contentColor)
                .contentTransition(.numericText())
                .shadow(color: contentColor == .white ? .black.opacity(0.2) : .clear, radius: 10, x: 0, y: 5)
                .animation(.easeIn(duration: 0.3), value: contentColor)

            if isPaused {
                Text("Tap to Resume")
                    .font(.appHeadline)
                    .foregroundStyle(contentColor.opacity(0.8))
                    .padding(.top, 5)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
}

struct TimerControlsView: View {
    let isRunning: Bool
    let isPaused: Bool
    @Binding var selectedMode: TimerMode
    let modes: [TimerMode]
    let contentColor: Color
    let themeColor: Color
    let onTapRunning: () -> Void
    let onStop: () -> Void
    let onStart: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            if !isRunning {
                VStack(spacing: 30) {
                    if !isPaused {
                        Picker("Mode", selection: $selectedMode) {
                            ForEach(modes, id: \.self) { mode in
                                Text(mode.displayTitle).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 40)
                        .colorScheme(contentColor == .white ? .dark : .light)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    if isPaused {
                        Button(action: onStop) {
                            Text("Stop Session")
                                .font(.appTitle3).fontWeight(.semibold)
                                .frame(maxWidth: .infinity).frame(height: 60)
                                .background(Color.white.opacity(0.15))
                                .foregroundColor(.white)
                                .cornerRadius(20)
                                .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white, lineWidth: 1))
                        }
                        .padding(.horizontal, 40)
                    } else {
                        Button(action: onStart) {
                            Text("Start \(selectedMode.displayTitle)")
                                .font(.appTitle3).fontWeight(.semibold)
                                .frame(maxWidth: .infinity).frame(height: 60)
                                .background(themeColor)
                                .foregroundColor(.white)
                                .cornerRadius(20)
                                .shadow(radius: 5)
                        }
                        .padding(.horizontal, 40)
                    }
                }
                .padding(.bottom, 100)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                Color.clear.contentShape(Rectangle()).frame(height: 150)
                    .onTapGesture { onTapRunning() }
                Text("Tap screen to pause")
                    .font(.appCaption).foregroundStyle(contentColor.opacity(0.6)).padding(.bottom, 100)
            }
        }
    }
}

// MARK: - TASK PICKER SHEET
struct TaskPickerSheetView: View {
    @Binding var activeTask: TaskItem?
    @Binding var shouldStart: Bool
    @Environment(\.dismiss) private var dismiss
    @Query private var todayTasks: [TaskItem]

    init(activeTask: Binding<TaskItem?>, shouldStart: Binding<Bool>) {
        self._activeTask = activeTask
        self._shouldStart = shouldStart
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        _todayTasks = Query(
            filter: #Predicate<TaskItem> { task in
                task.scheduledDate >= start && task.scheduledDate < end && !task.isCompleted
            },
            sort: \TaskItem.createdAt,
            order: .reverse
        )
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                Text("What are you focusing on?")
                    .font(.appTitle2).fontWeight(.bold)
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 16)

                if todayTasks.isEmpty {
                    ContentUnavailableView(
                        "No Tasks Today",
                        systemImage: "checkmark.circle",
                        description: Text("Add tasks in the Tasks tab, or start without one.")
                    )
                    .frame(maxHeight: .infinity)
                } else {
                    List(todayTasks, id: \.persistentModelID) { task in
                        Button {
                            activeTask = task
                            shouldStart = true
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "circle")
                                    .foregroundStyle(.secondary)
                                Text(task.title)
                                    .foregroundStyle(.primary)
                                Spacer()
                                // Show streak flame if applicable
                                if task.focusStreak >= 2 {
                                    Label("\(task.focusStreak)", systemImage: "flame.fill")
                                        .font(.appCaption)
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }

                // Skip option
                Button {
                    activeTask = nil
                    shouldStart = true
                    dismiss()
                } label: {
                    Text("Start without a task")
                        .font(.appSubhead)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - POST-SESSION MOOD PROMPT
struct SessionMoodPromptView: View {
    let task: TaskItem?
    let durationMinutes: Int
    let onSelect: (String) -> Void
    let onSkip: () -> Void

    private let moodEmojis = ["🔥", "😊", "😤", "😐", "😫", "🧠", "⚡️", "😴"]

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 6) {
                Text("Session complete! 🎉")
                    .font(.appTitle3).fontWeight(.bold)
                if let title = task?.title {
                    Text("You focused on \"\(title)\" for \(durationMinutes) min")
                        .font(.appSubhead)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                } else {
                    Text("\(durationMinutes) minutes of focused work")
                        .font(.appSubhead)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 28)

            VStack(spacing: 12) {
                Text("How did that feel?")
                    .font(.appHeadline)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                    ForEach(moodEmojis, id: \.self) { emoji in
                        Button {
                            Haptics.impact(.light)
                            onSelect(emoji)
                        } label: {
                            Text(emoji)
                                .font(.system(size: 32))
                        }
                    }
                }
                .padding(.horizontal, 20)
            }

            Button(action: onSkip) {
                Text("Skip")
                    .font(.appSubhead)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Just 5 Minutes Nudge Card
struct JustFiveMinutesCard: View {
    let task: TaskItem
    let onLaunch: () -> Void
    let onDismiss: () -> Void

    private var daysSinceActivity: Int {
        let calendar = Calendar.current
        let referenceDate = task.lastFocusedDate ?? task.createdAt
        return max(calendar.dateComponents([.day], from: referenceDate, to: Date()).day ?? 0, 0)
    }

    private var overdueLabel: String {
        let days = daysSinceActivity
        if days == 1 { return "Untouched for 1 day" }
        return "Untouched for \(days) days"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(overdueLabel)
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(task.title)
                .font(.appHeadline)
                .fontWeight(.semibold)
                .lineLimit(2)

            Button(action: onLaunch) {
                Text("Just 5 min →")
                    .font(.appSubhead)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.cardinalRed)
                    .cornerRadius(12)
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}
