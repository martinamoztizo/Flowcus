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
    @StateObject private var timerManager = TimeManager()
    @Environment(\.scenePhase) var scenePhase
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

    let modes = TimerMode.allCases
    private let focusSessionXP = 25

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
                            // Show task picker first if in focus mode and no task selected
                            if selectedMode == .focus && activeTask == nil {
                                showTaskPicker = true
                            } else {
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                    timerManager.start()
                                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                                }
                            }
                        }
                    )
                }
            }
            .toolbar(timerManager.isRunning ? .hidden : .visible, for: .tabBar)
            .animation(.easeInOut, value: timerManager.isRunning)
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
                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
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
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active { timerManager.appMovedToForeground() }
                if newPhase == .background { timerManager.appMovedToBackground() }
            }
            .onChange(of: selectedMode) { _, newMode in
                 if !timerManager.isRunning { updateTimerForMode(newMode) }
            }
            .onAppear {
                if !timerManager.isRunning { updateTimerForMode(selectedMode) }
                loadActiveTaskFromStorage()
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
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
        } else if isPaused {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                timerManager.start()
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
        }
    }

    private func stopTimer() {
        withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
            timerManager.pause()
            updateTimerForMode(selectedMode)
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func completeSession() {
        timerManager.pause()
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()

        withAnimation {
            if selectedMode == .focus {
                totalXP += focusSessionXP
                sessionCount += 1

                // Capture task info for post-session prompt
                completedTask = activeTask
                completedDuration = Int(timerManager.initialTime / 60)

                // Update streak and cumulative focus time on the task
                if let task = activeTask {
                    updateTaskStreak(task, minutes: defaultWorkTime)
                }

                // Cycle to next mode
                if sessionCount >= 2 {
                    selectedMode = .longBreak
                    sessionCount = 0
                } else {
                    selectedMode = .shortBreak
                }

                // Tier XP bonuses — check if completing this task cleared a full runway tier
                awardRunwayBonuses()

                // Clear active task and show mood prompt
                activeTask = nil
                activeTaskID = ""
                showMoodPrompt = true
            } else {
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

    private func awardRunwayBonuses() {
        guard let task = completedTask, task.runwayTier != .none else { return }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        // Fetch today's runway tasks to check tier completion
        let tier = task.runwayTier
        let tierRaw = tier.rawValue
        let descriptor = FetchDescriptor<TaskItem>(predicate: #Predicate {
            $0.scheduledDate >= startOfDay && $0.scheduledDate < endOfDay
            && $0.runwayTierRaw == tierRaw
        })

        guard let tierTasks = try? modelContext.fetch(descriptor) else { return }
        let allDone = tierTasks.allSatisfy { $0.isCompleted }

        if allDone {
            switch tier {
            case .small: totalXP += 10
            case .medium: totalXP += 25
            case .big: totalXP += 50
            case .none: break
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
                totalXP += 100
            }
        }
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
                    .font(.subheadline)
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
                    .font(.headline)
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
                                .font(.title3).fontWeight(.semibold)
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
                                .font(.title3).fontWeight(.semibold)
                                .frame(maxWidth: .infinity).frame(height: 60)
                                .background(themeColor)
                                .foregroundColor(.white)
                                .cornerRadius(20)
                                .shadow(radius: 5)
                        }
                        .padding(.horizontal, 40)
                    }
                }
                .padding(.bottom, 50)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                Color.clear.contentShape(Rectangle()).frame(height: 150)
                    .onTapGesture { onTapRunning() }
                Text("Tap screen to pause")
                    .font(.caption).foregroundStyle(contentColor.opacity(0.6)).padding(.bottom, 50)
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
                    .font(.title2).fontWeight(.bold)
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
                                        .font(.caption)
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
                        .font(.subheadline)
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
                    .font(.title3).fontWeight(.bold)
                if let title = task?.title {
                    Text("You focused on \"\(title)\" for \(durationMinutes) min")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                } else {
                    Text("\(durationMinutes) minutes of focused work")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 28)

            VStack(spacing: 12) {
                Text("How did that feel?")
                    .font(.headline)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                    ForEach(moodEmojis, id: \.self) { emoji in
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity)
    }
}
