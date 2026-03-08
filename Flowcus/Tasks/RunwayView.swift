//
//  RunwayView.swift
//  Flowcus
//
//  Focus Runway — ADHD-native 1-3-5 daily focus system.
//  Three modes: Planning (build runway), Doing (single-task hero), Review (summary).
//

import SwiftUI
import SwiftData

// MARK: - Runway View

struct RunwayView: View {
    let date: Date
    var switchToFocusTab: () -> Void = {}

    @Environment(\.modelContext) private var modelContext
    @Query private var tasks: [TaskItem]
    @AppStorage("activeTaskID") private var activeTaskID: String = ""
    @AppStorage("totalXP") private var totalXP: Int = 0

    @State private var showBacklogPicker = false
    @State private var backlogPickerTier: RunwayTier = .small

    // Ghost carryover: yesterday's unfinished runway tasks
    @Query private var ghostCandidates: [TaskItem]

    init(date: Date, switchToFocusTab: @escaping () -> Void = {}) {
        self.date = date
        self.switchToFocusTab = switchToFocusTab

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        _tasks = Query(filter: #Predicate {
            $0.scheduledDate >= startOfDay && $0.scheduledDate < endOfDay
        }, sort: \TaskItem.createdAt, order: .forward)

        // Yesterday's unfinished runway tasks
        let yesterdayStart = calendar.date(byAdding: .day, value: -1, to: startOfDay)!
        let noneRaw = RunwayTier.none.rawValue
        _ghostCandidates = Query(filter: #Predicate {
            $0.scheduledDate >= yesterdayStart && $0.scheduledDate < startOfDay
            && $0.runwayTierRaw != noneRaw
            && !$0.isCompleted
        }, sort: \TaskItem.createdAt, order: .forward)
    }

    // MARK: Computed

    private func runwayTasks(for tier: RunwayTier) -> [TaskItem] {
        tasks.filter { $0.runwayTier == tier }.sorted { $0.runwayOrder < $1.runwayOrder }
    }

    private var allRunwayTasks: [TaskItem] {
        tasks.filter { $0.runwayTier != .none }.sorted { a, b in
            let tierOrder: [RunwayTier] = [.small, .medium, .big] // momentum-first
            let ai = tierOrder.firstIndex(of: a.runwayTier) ?? 3
            let bi = tierOrder.firstIndex(of: b.runwayTier) ?? 3
            if ai != bi { return ai < bi }
            return a.runwayOrder < b.runwayOrder
        }
    }

    private var incompleteTasks: [TaskItem] {
        allRunwayTasks.filter { !$0.isCompleted }
    }

    private var completedRunwayTasks: [TaskItem] {
        allRunwayTasks.filter { $0.isCompleted }
    }

    private var isAllDone: Bool {
        let all = allRunwayTasks
        return !all.isEmpty && all.allSatisfy(\.isCompleted)
    }

    private var hasAnyRunwayTask: Bool {
        !allRunwayTasks.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if isAllDone {
                    // REVIEW MODE
                    reviewSection
                } else if hasAnyRunwayTask && incompleteTasks.count < allRunwayTasks.count {
                    // DOING MODE — at least one task completed
                    doingSection
                    planningSection
                } else {
                    // PLANNING MODE
                    planningSection
                }
            }
            .padding(.bottom, 100)
        }
        .sheet(isPresented: $showBacklogPicker) {
            BacklogPickerSheet(date: date, tier: backlogPickerTier)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Planning Section

    @ViewBuilder
    private var planningSection: some View {
        // Ghost carryover
        if !ghostCandidates.isEmpty {
            GhostCarryoverSection(ghosts: ghostCandidates, date: date)
                .padding(.horizontal, 16)
        }

        // THE BIG ONE (1 slot)
        RunwayTierSection(
            tier: .big,
            tasks: runwayTasks(for: .big),
            date: date,
            onBacklog: {
                backlogPickerTier = .big
                showBacklogPicker = true
            }
        )
        .padding(.horizontal, 16)

        // SUPPORTING CAST (3 slots)
        RunwayTierSection(
            tier: .medium,
            tasks: runwayTasks(for: .medium),
            date: date,
            onBacklog: {
                backlogPickerTier = .medium
                showBacklogPicker = true
            }
        )
        .padding(.horizontal, 16)

        // QUICK WINS (5 slots)
        RunwayTierSection(
            tier: .small,
            tasks: runwayTasks(for: .small),
            date: date,
            onBacklog: {
                backlogPickerTier = .small
                showBacklogPicker = true
            }
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Doing Section

    @ViewBuilder
    private var doingSection: some View {
        let current = incompleteTasks.first

        VStack(spacing: 16) {
            // Hero card
            if let task = current {
                RunwayHeroCard(task: task) {
                    launchIntoFocus(task: task)
                }
                .padding(.horizontal, 16)
            }

            // Up Next
            if incompleteTasks.count > 1 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Up Next")
                        .font(.appCaption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .padding(.horizontal, 16)

                    ForEach(Array(incompleteTasks.dropFirst())) { task in
                        RunwayUpNextCard(task: task) {
                            // Promote to current by reordering
                            task.runwayOrder = -1
                            Haptics.impact(.medium)
                        } onLaunch: {
                            launchIntoFocus(task: task)
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }

            // Completed so far
            if !completedRunwayTasks.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Done")
                        .font(.appCaption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .padding(.horizontal, 16)

                    ForEach(completedRunwayTasks) { task in
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.body)
                            Text(task.title)
                                .font(.appSubhead)
                                .strikethrough()
                                .foregroundStyle(.secondary)
                            Spacer()
                            if task.totalFocusMinutes > 0 {
                                Text("\(task.totalFocusMinutes)m")
                                    .font(.appCaption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemGray6).opacity(0.5)))
                        .padding(.horizontal, 16)
                    }
                }
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Review Section

    @ViewBuilder
    private var reviewSection: some View {
        VStack(spacing: 20) {
            // Summary card
            VStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.green)

                Text("Runway Complete!")
                    .font(.appTitle2)
                    .fontWeight(.bold)

                let totalMinutes = allRunwayTasks.reduce(0) { $0 + $1.totalFocusMinutes }
                Text("You launched \(completedRunwayTasks.count) of \(allRunwayTasks.count) tasks")
                    .font(.appSubhead)
                    .foregroundStyle(.secondary)

                if totalMinutes > 0 {
                    Text("\(totalMinutes) minutes of focused work")
                        .font(.appCaption)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemGray6)))
            .padding(.horizontal, 16)

            // Completed tasks list
            ForEach(allRunwayTasks) { task in
                HStack(spacing: 10) {
                    Image(systemName: task.runwayTier.icon)
                        .font(.caption)
                        .foregroundStyle(task.runwayTier.color)
                    Text(task.title)
                        .font(.appSubhead)
                        .strikethrough(task.isCompleted)
                        .foregroundStyle(task.isCompleted ? .secondary : .primary)
                    Spacer()
                    if task.totalFocusMinutes > 0 {
                        Text("\(task.totalFocusMinutes)m")
                            .font(.appCaption2)
                            .foregroundStyle(.tertiary)
                    }
                    if task.isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemGray6)))
                .padding(.horizontal, 16)
            }

            // Dump to Journal button
            Button {
                dumpToJournal()
                Haptics.impact(.medium)
            } label: {
                Label("Dump to Journal", systemImage: "book.fill")
                    .font(.appSubhead)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.cardinalRed)
                    .foregroundStyle(.white)
                    .cornerRadius(14)
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 8)
    }

    // MARK: - Actions

    private func launchIntoFocus(task: TaskItem) {
        activeTaskID = String(task.createdAt.timeIntervalSinceReferenceDate)
        Haptics.impact(.heavy)
        switchToFocusTab()
    }

    private func dumpToJournal() {
        let completed = completedRunwayTasks
        let total = allRunwayTasks.count
        let minutes = allRunwayTasks.reduce(0) { $0 + $1.totalFocusMinutes }

        var lines = ["Completed \(completed.count)/\(total) runway tasks."]
        if minutes > 0 { lines.append("Total focus: \(minutes) minutes.") }
        lines.append("")
        for task in allRunwayTasks {
            let check = task.isCompleted ? "[x]" : "[ ]"
            let mins = task.totalFocusMinutes > 0 ? " (\(task.totalFocusMinutes)m)" : ""
            lines.append("\(check) \(task.title)\(mins)")
        }

        let entry = JournalEntry(
            title: "Focus Runway",
            content: lines.joined(separator: "\n"),
            mood: isAllDone ? "🔥" : "😐"
        )
        modelContext.insert(entry)
    }
}

// MARK: - Runway Tier Section

struct RunwayTierSection: View {
    let tier: RunwayTier
    let tasks: [TaskItem]
    let date: Date
    var onBacklog: () -> Void = {}

    @Environment(\.modelContext) private var modelContext
    @State private var isAdding = false
    @State private var newTitle = ""

    private var isFull: Bool {
        tasks.count >= tier.maxCount
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: tier.icon)
                    .font(.caption)
                    .foregroundStyle(tier.color)
                VStack(alignment: .leading, spacing: 1) {
                    Text(tier.displayTitle)
                        .font(.appSubhead)
                        .fontWeight(.bold)
                        .foregroundStyle(tier.color)
                    Text(tierSubtitle)
                        .font(.appCaption2)
                        .foregroundStyle(tier.color.opacity(0.7))
                }
                Spacer()
                Text("\(tasks.count)/\(tier.maxCount)")
                    .font(.appCaption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(tier.color.opacity(0.6))
            }

            // Existing tasks
            ForEach(tasks) { task in
                RunwayTaskCard(task: task, tier: tier)
            }

            // Inline add field
            if isAdding {
                HStack(spacing: 6) {
                    TextField("New task...", text: $newTitle)
                        .font(.appSubhead)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray5))
                        .cornerRadius(8)
                        .submitLabel(.done)
                        .onSubmit { addTask() }

                    Button {
                        withAnimation { isAdding = false }
                        newTitle = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Action buttons
            if !isFull {
                HStack(spacing: 10) {
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) { isAdding = true }
                        Haptics.impact(.light)
                    } label: {
                        Label("Add", systemImage: "plus")
                            .font(.appCaption)
                            .foregroundStyle(tier.color)
                    }

                    Button(action: onBacklog) {
                        Label("From backlog", systemImage: "tray.and.arrow.up")
                            .font(.appCaption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 2)
            }

            // Empty slot indicators
            if tasks.isEmpty && !isAdding {
                emptySlotView
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(tier.color.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(tier.color.opacity(0.2), lineWidth: 1)
                )
        )
    }

    private var tierSubtitle: String {
        switch tier {
        case .big: return "What's the one thing today?"
        case .medium: return "What helps the big one happen?"
        case .small: return "What can you knock out fast?"
        case .none: return ""
        }
    }

    @ViewBuilder
    private var emptySlotView: some View {
        VStack(spacing: 6) {
            ForEach(0..<min(tier.maxCount, 3), id: \.self) { _ in
                RoundedRectangle(cornerRadius: 8)
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [6]))
                    .foregroundStyle(tier.color.opacity(0.2))
                    .frame(height: tier == .small ? 32 : 40)
            }
        }
    }

    private func addTask() {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let task = TaskItem(title: trimmed, scheduledDate: date)
        task.runwayTier = tier
        task.runwayOrder = tasks.count
        modelContext.insert(task)

        newTitle = ""
        if tasks.count + 1 >= tier.maxCount {
            isAdding = false
        }
        Haptics.impact(.light)
    }
}

// MARK: - Runway Task Card

struct RunwayTaskCard: View {
    let task: TaskItem
    let tier: RunwayTier
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        HStack(spacing: 10) {
            AnimatedCheckbox(
                isCompleted: task.isCompleted,
                font: tier == .big ? .title3 : .body,
                checkedColor: .green,
                uncheckedColor: tier.color.opacity(0.6),
                onToggle: {
                    task.isCompleted.toggle()
                    if task.isCompleted {
                        Haptics.impact(.heavy)
                    }
                }
            )

            InlineEditableText(
                text: task.title,
                font: tier == .big ? .appBody : .appSubhead,
                fontWeight: tier == .big ? .medium : .regular,
                isCompleted: task.isCompleted,
                completedColor: .secondary,
                lineLimit: 2,
                onCommit: { task.title = $0 }
            )

            Spacer()

            if task.totalFocusMinutes > 0 {
                Text("\(task.totalFocusMinutes)m")
                    .font(.appCaption2)
                    .foregroundStyle(.tertiary)
            }

            if task.focusStreak >= 2 {
                Label("\(task.focusStreak)", systemImage: "flame.fill")
                    .font(.appCaption2)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, tier == .big ? 14 : 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemGray6))
        )
        .opacity(task.isCompleted ? 0.6 : 1.0)
        .contextMenu {
            ForEach(RunwayTier.tiers, id: \.self) { t in
                if t != tier {
                    Button {
                        withAnimation { task.runwayTier = t }
                        Haptics.impact(.medium)
                    } label: {
                        Label("Move to \(t.displayTitle)", systemImage: t.icon)
                    }
                }
            }

            Button {
                withAnimation { task.runwayTier = .none }
                Haptics.impact(.medium)
            } label: {
                Label("Remove from Runway", systemImage: "arrow.uturn.backward")
            }

            Divider()

            Button(role: .destructive) {
                withAnimation { modelContext.delete(task) }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .animation(.default, value: task.isCompleted)
    }
}

// MARK: - Hero Card (Doing Mode)

struct RunwayHeroCard: View {
    let task: TaskItem
    let onLaunch: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Tier badge
            HStack(spacing: 6) {
                Image(systemName: task.runwayTier.icon)
                    .font(.caption)
                Text(task.runwayTier.displayTitle)
                    .font(.appCaption)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(task.runwayTier.color)

            // Task name
            Text(task.title)
                .font(.appTitle2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .lineLimit(3)

            if task.totalFocusMinutes > 0 {
                Label("\(task.totalFocusMinutes) min focused", systemImage: "clock")
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
            }

            // Launch button
            Button(action: onLaunch) {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Launch into Focus")
                        .fontWeight(.semibold)
                }
                .font(.appTitle3)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(task.runwayTier.color)
                .foregroundStyle(.white)
                .cornerRadius(16)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(task.runwayTier.color.opacity(0.3), lineWidth: 1.5)
                )
        )
    }
}

// MARK: - Up Next Card

struct RunwayUpNextCard: View {
    let task: TaskItem
    let onPromote: () -> Void
    let onLaunch: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: task.runwayTier.icon)
                .font(.caption2)
                .foregroundStyle(task.runwayTier.color)

            Text(task.title)
                .font(.appSubhead)
                .lineLimit(1)

            Spacer()

            Button {
                onLaunch()
            } label: {
                Image(systemName: "play.circle.fill")
                    .font(.title3)
                    .foregroundStyle(task.runwayTier.color)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemGray6)))
        .contextMenu {
            Button(action: onPromote) {
                Label("Focus on this next", systemImage: "arrow.up.circle")
            }
        }
    }
}

// MARK: - Ghost Carryover Section

struct GhostCarryoverSection: View {
    let ghosts: [TaskItem]
    let date: Date
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Yesterday's unfinished")
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
            }

            ForEach(ghosts) { ghost in
                HStack(spacing: 10) {
                    Image(systemName: ghost.runwayTier.icon)
                        .font(.caption2)
                        .foregroundStyle(ghost.runwayTier.color.opacity(0.5))

                    Text(ghost.title)
                        .font(.appSubhead)
                        .foregroundStyle(.primary.opacity(0.4))
                        .lineLimit(1)

                    Spacer()

                    Button {
                        relaunchGhost(ghost)
                        Haptics.impact(.medium)
                    } label: {
                        Text("Relaunch")
                            .font(.appCaption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Color(.systemGray5)))
                            .foregroundStyle(.primary)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemGray6).opacity(0.4))
                )
                .opacity(0.6)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [6]))
                .foregroundStyle(Color(.systemGray3))
        )
    }

    private func relaunchGhost(_ ghost: TaskItem) {
        let newTask = TaskItem(title: ghost.title, scheduledDate: date)
        newTask.runwayTier = ghost.runwayTier
        newTask.runwayOrder = 0
        modelContext.insert(newTask)
    }
}

// MARK: - Backlog Picker Sheet

struct BacklogPickerSheet: View {
    let date: Date
    let tier: RunwayTier
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var availableTasks: [TaskItem]

    init(date: Date, tier: RunwayTier) {
        self.date = date
        self.tier = tier

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        let noneRaw = RunwayTier.none.rawValue

        _availableTasks = Query(filter: #Predicate {
            $0.scheduledDate >= startOfDay && $0.scheduledDate < endOfDay
            && $0.runwayTierRaw == noneRaw
            && !$0.isCompleted
        }, sort: \TaskItem.createdAt, order: .reverse)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                Text("Add to \(tier.displayTitle)")
                    .font(.appTitle3).fontWeight(.bold)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 12)

                if availableTasks.isEmpty {
                    ContentUnavailableView(
                        "No Available Tasks",
                        systemImage: "tray",
                        description: Text("All today's tasks are already assigned or completed.")
                    )
                } else {
                    List(availableTasks, id: \.persistentModelID) { task in
                        Button {
                            task.runwayTier = tier
                            Haptics.impact(.light)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: tier.icon)
                                    .foregroundStyle(tier.color)
                                    .font(.caption)
                                Text(task.title)
                                    .foregroundStyle(.primary)
                                Spacer()
                            }
                        }
                    }
                    .listStyle(.plain)
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
