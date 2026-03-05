//
//  EisenhowerMatrix.swift
//  Flowcus
//
//  Eisenhower Matrix view — a 2x2 grid that organizes tasks by urgency and importance.
//  Each quadrant is color-coded to reduce decision fatigue (ADHD-friendly).
//  Tasks without a quadrant appear in an "Unsorted" tray at the bottom.
//

import SwiftUI
import SwiftData

// MARK: - Eisenhower Matrix View

/// Main container for the Eisenhower Matrix.
/// Uses the same `init(date:)` @Query pattern as `DailyTaskList` to fetch
/// tasks for the selected calendar date, then partitions them into quadrants.
struct EisenhowerMatrixView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var tasks: [TaskItem]
    @AppStorage("activeTaskID") private var activeTaskID: String = ""

    let date: Date
    var switchToFocusTab: () -> Void = {}

    init(date: Date, switchToFocusTab: @escaping () -> Void = {}) {
        self.date = date
        self.switchToFocusTab = switchToFocusTab

        // Build date range for the selected day — same pattern as DailyTaskList
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        // Fetch all tasks scheduled for this day, sorted oldest-first
        _tasks = Query(filter: #Predicate {
            $0.scheduledDate >= startOfDay && $0.scheduledDate < endOfDay
        }, sort: \TaskItem.createdAt, order: .forward)
    }

    // MARK: Quadrant Filters

    /// Filter tasks into their assigned quadrant.
    /// Uses the computed `quadrant` property on TaskItem (reads from `quadrantRaw`).
    private func tasks(for quadrant: EisenhowerQuadrant) -> [TaskItem] {
        tasks.filter { $0.quadrant == quadrant }
    }

    /// Tasks that haven't been assigned to any quadrant yet
    private var unassignedTasks: [TaskItem] {
        tasks.filter { $0.quadrant == .unassigned }
    }

    private func launchIntoFocus(_ task: TaskItem) {
        activeTaskID = String(task.createdAt.timeIntervalSinceReferenceDate)
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        switchToFocusTab()
    }

    var body: some View {
        VStack(spacing: 0) {
            // MARK: 2x2 Quadrant Grid
            // Manual VStack+HStack layout (not LazyVGrid) for predictable sizing
            // when each cell contains a scrollable list + add button.
            VStack(spacing: 6) {
                // Top row: Q1 (Do First) | Q2 (Schedule)
                HStack(spacing: 6) {
                    QuadrantCellView(quadrant: .q1, tasks: tasks(for: .q1), date: date, onFocus: launchIntoFocus)
                    QuadrantCellView(quadrant: .q2, tasks: tasks(for: .q2), date: date, onFocus: launchIntoFocus)
                }

                // Bottom row: Q3 (Delegate) | Q4 (Eliminate)
                HStack(spacing: 6) {
                    QuadrantCellView(quadrant: .q3, tasks: tasks(for: .q3), date: date, onFocus: launchIntoFocus)
                    QuadrantCellView(quadrant: .q4, tasks: tasks(for: .q4), date: date, onFocus: launchIntoFocus)
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 12)

            // MARK: Unsorted Tray
            // Shows tasks that haven't been assigned to a quadrant.
            // Appears only when there are unassigned tasks — no empty state clutter.
            if !unassignedTasks.isEmpty {
                UnsortedTrayView(tasks: unassignedTasks)
                    .padding(.horizontal, 10)
                    .padding(.top, 10)
            }

            Spacer()
        }
        // Bottom padding so content isn't hidden behind calendar trigger / tab bar
        .padding(.bottom, 100)
    }
}

// MARK: - Quadrant Cell View

/// A single cell in the 2x2 grid — shows its header, scrollable task cards,
/// and a quick-add button. Each cell is color-coded by quadrant.
struct QuadrantCellView: View {
    let quadrant: EisenhowerQuadrant
    let tasks: [TaskItem]
    let date: Date
    var onFocus: ((TaskItem) -> Void)? = nil

    @Environment(\.modelContext) private var modelContext

    /// Controls the inline add-task text field visibility
    @State private var isAddingTask = false
    @State private var newTaskTitle = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {

            // MARK: Quadrant Header
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    // Main label (e.g. "Do First")
                    Text(quadrant.displayTitle)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(quadrant.color)

                    // Subtitle describing the axes (e.g. "Urgent & Important")
                    Text(quadrant.subtitle)
                        .font(.system(size: 8))
                        .foregroundStyle(quadrant.color.opacity(0.7))
                }

                Spacer()

                // Task count badge
                Text("\(tasks.count)")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(quadrant.color.opacity(0.6))

                // Quick-add button — opens inline text field inside the cell
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isAddingTask = true
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(quadrant.color)
                        .font(.callout)
                }
            }

            // MARK: Inline Add Task Field
            // Appears when user taps the "+" button — keeps interaction within the cell
            if isAddingTask {
                HStack(spacing: 6) {
                    TextField("New task...", text: $newTaskTitle)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray5))
                        .cornerRadius(8)
                        .submitLabel(.done)
                        .onSubmit { addTask() }

                    // Cancel button to dismiss without adding
                    Button {
                        withAnimation { isAddingTask = false }
                        newTaskTitle = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // MARK: Task Cards (Scrollable)
            // Each quadrant cell scrolls independently if it has many tasks
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(tasks) { task in
                        MatrixTaskCard(task: task, onFocus: onFocus.map { cb in { cb(task) } })
                    }
                }
            }
        }
        .padding(8)
        // Quadrant cell background — subtle fill + border using the quadrant's color
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(quadrant.color.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(quadrant.color.opacity(0.2), lineWidth: 1)
                )
        )
    }

    // MARK: - Add Task

    /// Creates a new task pre-assigned to this quadrant and for the selected date.
    /// The quadrant is set automatically so the user doesn't have to categorize after adding.
    private func addTask() {
        let trimmed = newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let task = TaskItem(title: trimmed, scheduledDate: date)
        task.quadrant = quadrant // Auto-assign to this cell's quadrant
        modelContext.insert(task)

        // Reset input state
        newTaskTitle = ""
        isAddingTask = false
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

// MARK: - Matrix Task Card

/// A compact task card designed to fit inside the tight quadrant cells.
/// Simpler than the full `TaskCardView` — no focus time pill or streak badge
/// to save vertical space. Supports toggle completion and context menu for reassignment.
struct MatrixTaskCard: View {
    let task: TaskItem
    var onFocus: (() -> Void)? = nil
    @Environment(\.modelContext) private var modelContext

    /// Tracks checkbox scale for the spring bounce animation (same pattern as TaskCardView)
    @State private var checkScale: CGFloat = 1.0

    var body: some View {
        HStack(spacing: 8) {
            // MARK: Compact Checkbox
            Button {
                // Spring bounce animation on toggle
                withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                    checkScale = 1.3
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                        checkScale = 1.0
                    }
                }
                task.isCompleted.toggle()
                if task.isCompleted {
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                }
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.caption)
                    .foregroundStyle(task.isCompleted ? task.quadrant.color : .gray)
                    .scaleEffect(checkScale)
            }
            .buttonStyle(.plain)

            // Task title — strikethrough when completed
            Text(task.title)
                .font(.caption2)
                .strikethrough(task.isCompleted)
                .foregroundStyle(task.isCompleted ? .gray : .primary)
                .lineLimit(2)

            Spacer()

            // Visible play button — Q1 only (one-tap focus for highest priority)
            if task.quadrant == .q1, let focus = onFocus {
                Button(action: focus) {
                    Image(systemName: "play.circle.fill")
                        .font(.caption)
                        .foregroundStyle(task.quadrant.color)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
        )
        // Dim completed tasks
        .opacity(task.isCompleted ? 0.5 : 1.0)
        // MARK: Context Menu — focus, reassign quadrant, or delete
        .contextMenu {
            // Send to Focus — available on all quadrants
            if let focus = onFocus {
                Button(action: focus) {
                    Label("Send to Focus", systemImage: "play.fill")
                }
            }

            Divider()

            // Show "Move to..." options for all quadrants except the current one
            ForEach(EisenhowerQuadrant.quadrants, id: \.self) { q in
                if q != task.quadrant {
                    Button {
                        withAnimation { task.quadrant = q }
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    } label: {
                        Label(q.displayTitle, systemImage: "arrow.right.circle")
                    }
                }
            }

            Divider()

            // Delete option
            Button(role: .destructive) {
                withAnimation { modelContext.delete(task) }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .animation(.default, value: task.isCompleted)
    }
}

// MARK: - Unsorted Tray View

/// Horizontal scrolling tray shown below the matrix grid for tasks
/// that haven't been assigned to any quadrant yet.
/// Each chip can be tapped to assign it to a quadrant via a context menu.
/// Framed as "Tap to sort" — curiosity-driven, no guilt (ADHD-friendly).
struct UnsortedTrayView: View {
    let tasks: [TaskItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Tray header — encourages action without pressure
            HStack {
                Image(systemName: "tray.full")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Unsorted — hold to assign")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                // Count indicator
                Text("\(tasks.count)")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }

            // Horizontal scrolling chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(tasks) { task in
                        UnsortedTaskChip(task: task)
                    }
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6).opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray4), style: StrokeStyle(lineWidth: 1, dash: [6]))
                )
        )
    }
}

// MARK: - Unsorted Task Chip

/// A single compact chip representing an unassigned task in the tray.
/// Long-press reveals a context menu to assign it to a quadrant.
struct UnsortedTaskChip: View {
    let task: TaskItem

    var body: some View {
        Text(task.title)
            .font(.caption2)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color(.systemGray5))
            )
            // Long-press to assign to a quadrant
            .contextMenu {
                ForEach(EisenhowerQuadrant.quadrants, id: \.self) { q in
                    Button {
                        withAnimation { task.quadrant = q }
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    } label: {
                        Label(q.displayTitle, systemImage: "arrow.right.circle")
                    }
                }
            }
    }
}
