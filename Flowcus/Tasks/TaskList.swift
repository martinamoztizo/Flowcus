//
//  TaskList.swift
//  Flowcus
//

import SwiftUI
import SwiftData

// MARK: - View Mode

enum TaskViewMode: String, CaseIterable, Hashable {
    case list
    case matrix
    case runway

    var title: String {
        switch self {
        case .list: return "Simple List"
        case .matrix: return "Eisenhower Matrix"
        case .runway: return "Focus Runway"
        }
    }

    var description: String {
        switch self {
        case .list: return "Classic checklist"
        case .matrix: return "Urgent vs. important"
        case .runway: return "1 big + 3 medium + 5 small"
        }
    }

    var icon: FlowcusIcon {
        switch self {
        case .list: return .modeList
        case .matrix: return .modeMatrix
        case .runway: return .modeRunway
        }
    }

    var accentColor: Color {
        switch self {
        case .list: return .cardinalRed
        case .matrix: return .orange
        case .runway: return .cardinalRed
        }
    }
}

// MARK: - Task List View
struct TaskListView: View {
    var switchToFocusTab: () -> Void = {}
    @Binding var calendarRevealProgress: Double
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var navigationPath: [TaskViewMode] = []

    // Interaction State
    @State private var dragOffset: CGFloat = 0
    @State private var isCalendarOpen: Bool = false

    // Layout
    @State private var calendarHeight: CGFloat = 460
    let dragThreshold: CGFloat = 80

    var closedOffset: CGFloat { calendarHeight }

    var headerTitle: String {
        if Calendar.current.isDateInToday(selectedDate) {
            return "Today"
        } else {
            return selectedDate.formatted(date: .abbreviated, time: .omitted)
        }
    }

    var bottomDateString: String {
        selectedDate.formatted(date: .complete, time: .omitted)
    }

    var revealProgress: Double {
        let totalOffset = (isCalendarOpen ? 0 : closedOffset) + dragOffset
        let progress = 1.0 - (totalOffset / closedOffset)
        return min(max(progress, 0), 1)
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack(alignment: .bottom) {
                // 1. PICKER PAGE
                TaskViewPickerPage(navigationPath: $navigationPath)

                // 2. DIMMING LAYER
                if revealProgress > 0 {
                    Color.black
                        .opacity(revealProgress * 0.4)
                        .ignoresSafeArea()
                        .onTapGesture { closeCalendar() }
                }

                // 3. UNIFIED SLIDING PANEL (Text + Calendar)
                VStack(spacing: -10) {
                    ZStack {
                        Text(bottomDateString)
                            .font(.appHeadline)
                            .foregroundStyle(.primary)
                            .padding(.top, 20)
                            .padding(.bottom, 30)
                            .padding(.horizontal, 40)
                            .background(Color.white.opacity(0.001))
                            .opacity(pow(1.0 - revealProgress, 2))
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 10) {
                        Capsule()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 40, height: 5)
                            .padding(.top, 15)

                        DatePicker("", selection: Binding(
                            get: { selectedDate },
                            set: { selectedDate = Calendar.current.startOfDay(for: $0) }
                        ), displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .tint(.cardinalRed)
                            .padding(.horizontal)
                            .padding(.bottom, 20)
                    }
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(key: CalendarHeightKey.self, value: geo.size.height)
                        }
                    )
                    .onPreferenceChange(CalendarHeightKey.self) { calendarHeight = $0 }
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(25)
                    .shadow(radius: 20)
                    .opacity(revealProgress)
                }
                .offset(y: max((isCalendarOpen ? 0 : closedOffset) + dragOffset, 0) - 140 * (1.0 - revealProgress))
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let translation = value.translation.height
                            if isCalendarOpen {
                                if translation > 0 { dragOffset = translation }
                                else { dragOffset = translation * 0.1 }
                            } else {
                                if translation < 0 { dragOffset = translation }
                                else { dragOffset = translation * 0.1 }
                            }
                        }
                        .onEnded { value in
                            let translation = value.translation.height
                            let velocity = value.predictedEndTranslation.height

                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                if isCalendarOpen {
                                    if translation > dragThreshold || velocity > 200 {
                                        isCalendarOpen = false
                                    }
                                } else {
                                    if translation < -dragThreshold || velocity < -200 {
                                        isCalendarOpen = true
                                    }
                                }
                                dragOffset = 0
                            }
                        }
                )
            }
            .ignoresSafeArea(edges: .bottom)
            .onAppear { calendarRevealProgress = revealProgress }
            .onChange(of: dragOffset) { calendarRevealProgress = revealProgress }
            .onChange(of: isCalendarOpen) { calendarRevealProgress = revealProgress }
            .navigationTitle(headerTitle)
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: TaskViewMode.self) { mode in
                Group {
                    switch mode {
                    case .list:
                        DailyTaskList(date: selectedDate)
                    case .matrix:
                        EisenhowerMatrixView(date: selectedDate, switchToFocusTab: switchToFocusTab)
                    case .runway:
                        RunwayView(date: selectedDate, switchToFocusTab: switchToFocusTab)
                    }
                }
                .id(selectedDate)
                .navigationTitle(mode.title)
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }

    private func closeCalendar() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isCalendarOpen = false
            dragOffset = 0
        }
    }
}

// MARK: - Task View Picker Page

struct TaskViewPickerPage: View {
    @Binding var navigationPath: [TaskViewMode]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Pick your workflow")
                    .font(.appSubhead)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                ForEach(TaskViewMode.allCases, id: \.self) { mode in
                    TaskViewCard(mode: mode) {
                        navigationPath.append(mode)
                    }
                }
            }
            .padding(.bottom, 100)
        }
    }
}

// MARK: - Task View Card

struct TaskViewCard: View {
    let mode: TaskViewMode
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(mode.accentColor.opacity(0.15))
                    .frame(width: 50, height: 50)
                    .overlay(
                        mode.icon.sized(FlowcusIcon.titleSize)
                            .foregroundStyle(mode.accentColor)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.title)
                        .font(.appBody)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    Text(mode.description)
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.systemGray6))
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }
}

// MARK: - Daily Task List

struct DailyTaskList: View {
    @Environment(\.modelContext) private var modelContext
    // The query is dynamic based on the init
    @Query private var tasks: [TaskItem]
    
    let date: Date
    @State private var newTaskTitle: String = ""
    
    init(date: Date) {
        self.date = date
        
        // Calculate start and end of the selected day for filtering
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        // Predicate: scheduledDate >= start AND scheduledDate < end
        _tasks = Query(filter: #Predicate {
            $0.scheduledDate >= startOfDay && $0.scheduledDate < endOfDay
        }, sort: \TaskItem.createdAt, order: .reverse)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: Input Field
            HStack {
                TextField("Add task...", text: $newTaskTitle)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .submitLabel(.done)
                    .onSubmit(addTask)

                Button(action: addTask) {
                    Image(systemName: "plus")
                        .font(.title2).padding()
                        .background(Color.cardinalRed)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 10)

            // MARK: Task Cards (or Empty State)
            if tasks.isEmpty {

                // -- Empty State --
                // Custom replacement for ContentUnavailableView with friendlier messaging
                Spacer()
                VStack(spacing: 12) {
                    FlowcusIcon.checklist.sized(FlowcusIcon.heroSize)
                        .foregroundStyle(Color.cardinalRed.opacity(0.5))
                    Text("Nothing planned yet")
                        .font(.appHeadline)
                        .foregroundStyle(.secondary)
                    Text("Tap + to get started")
                        .font(.appSubhead)
                        .foregroundStyle(.tertiary)
                }
                Spacer()

            } else {

                // -- Card List --
                // ScrollView + LazyVStack replaces plain List for full card styling control
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(tasks) { task in
                            // Each task rendered as a styled card (see TaskCardView below)
                            TaskCardView(task: task, onToggle: { toggleTask(task) }, onDelete: { deleteTask(task) })
                        }
                    }
                    .padding(.horizontal, 16)
                    // Bottom padding so last card isn't hidden behind calendar trigger / tab bar
                    .padding(.bottom, 100)
                }
            }
        }
    }
    
    private func addTask() {
        let trimmedTitle = newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        // Create task specifically for the selected date
        let newTask = TaskItem(title: trimmedTitle, scheduledDate: date)
        modelContext.insert(newTask)
        newTaskTitle = ""
        Haptics.impact(.light)
    }
    
    private func toggleTask(_ task: TaskItem) {
        task.isCompleted.toggle()
        if task.isCompleted { Haptics.impact(.heavy) }
    }
    
    /// Delete a single task (used by card swipe-to-delete)
    private func deleteTask(_ task: TaskItem) {
        withAnimation {
            modelContext.delete(task)
        }
    }
}

// MARK: - Task Card View
// Individual card component for each task row.
// Replaces the old plain HStack with a rounded, padded card style.

struct TaskCardView: View {
    let task: TaskItem
    let onToggle: () -> Void
    let onDelete: () -> Void

    @State private var swipeOffset: CGFloat = 0

    var body: some View {
        HStack(spacing: 12) {
            AnimatedCheckbox(
                isCompleted: task.isCompleted,
                checkedIcon: "checkmark.square.fill",
                uncheckedIcon: "square",
                font: .title2,
                checkedColor: .cardinalRed,
                onToggle: onToggle
            )

            VStack(alignment: .leading, spacing: 3) {
                InlineEditableText(
                    text: task.title,
                    font: .appBody,
                    isCompleted: task.isCompleted,
                    onCommit: { task.title = $0 }
                )

                if task.totalFocusMinutes > 0 {
                    Label("\(task.totalFocusMinutes) min focused", systemImage: "clock")
                        .font(.appCaption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if task.focusStreak >= 2 {
                Label("\(task.focusStreak)", systemImage: "flame.fill")
                    .font(.appCaption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.orange)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemGray6))
        )
        .opacity(task.isCompleted ? 0.6 : 1.0)
        .offset(x: swipeOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.width < 0 {
                        swipeOffset = value.translation.width
                    }
                }
                .onEnded { value in
                    if value.translation.width < -120 {
                        withAnimation(.easeOut(duration: 0.2)) {
                            swipeOffset = -500
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            onDelete()
                        }
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            swipeOffset = 0
                        }
                    }
                }
        )
        .animation(.default, value: task.isCompleted)
    }
}

// MARK: - Preference Key

private struct CalendarHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 460
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
