//
//  TaskList.swift
//  Flowcus
//

import SwiftUI
import SwiftData

// MARK: - 2. TASK LIST VIEW
struct TaskListView: View {
    @State private var selectedDate: Date = Date()
    
    // Interaction State
    @State private var dragOffset: CGFloat = 0
    @State private var isCalendarOpen: Bool = false
    
    // Constants
    let calendarHeight: CGFloat = 460
    let closedOffset: CGFloat = 360 // Lifted so text is visible with tight gap
    let dragThreshold: CGFloat = 80
    
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
    
    // Calculate how much of the calendar is revealed (0.0 to 1.0)
    var revealProgress: Double {
        let totalOffset = (isCalendarOpen ? 0 : closedOffset) + dragOffset
        let progress = 1.0 - (totalOffset / closedOffset)
        return min(max(progress, 0), 1)
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // 1. TASK LIST
                DailyTaskList(date: selectedDate)
                    .id(selectedDate)
                
                // 2. DIMMING LAYER
                if revealProgress > 0 {
                    Color.black
                        .opacity(revealProgress * 0.4)
                        .ignoresSafeArea()
                        .onTapGesture { closeCalendar() }
                }
                
                // 3. UNIFIED SLIDING PANEL (Text + Calendar)
                VStack(spacing: -10) {
                    // A. TRIGGER TEXT (Sits on top of calendar)
                    ZStack {
                        Text(bottomDateString)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .padding(.top, 20)
                            .padding(.bottom, 30) // Tight gap
                            .padding(.horizontal, 40)
                            .background(Color.white.opacity(0.001)) // Hit test
                            // Fade out as we open
                            .opacity(1.0 - (revealProgress * 2)) 
                    }
                    .frame(maxWidth: .infinity)
                    
                    // B. CALENDAR
                    VStack(spacing: 10) {
                        // Handle
                        Capsule()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 40, height: 5)
                            .padding(.top, 15)
                        
                        // Explicit Month & Year Header
                        Text(selectedDate.formatted(.dateTime.month(.wide).year()))
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 24)
                            .padding(.top, 8)
                        
                        DatePicker("", selection: $selectedDate, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .padding(.horizontal)
                            .padding(.bottom, 20) // Give it some breathing room at the bottom
                    }
                    .frame(height: calendarHeight)
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(25)
                    .shadow(radius: 20)
                    // FADE IN as we drag up (Critical for "Invisible initially")
                    .opacity(revealProgress)
                }
                // OFFSETS
                // Base position: Open = 0, Closed = Push down by closedOffset
                .offset(y: isCalendarOpen ? 0 : closedOffset)
                // Interactive Drag
                .offset(y: dragOffset)
                // GESTURE
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let translation = value.translation.height
                            if isCalendarOpen {
                                // Dragging Down (Positive)
                                if translation > 0 { dragOffset = translation }
                                else { dragOffset = translation * 0.1 } // Rubber band up
                            } else {
                                // Dragging Up (Negative)
                                if translation < 0 { dragOffset = translation }
                                else { dragOffset = translation * 0.1 } // Rubber band down
                            }
                        }
                        .onEnded { value in
                            let translation = value.translation.height
                            let velocity = value.predictedEndTranslation.height
                            
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                if isCalendarOpen {
                                    // Close if dragged down far enough
                                    if translation > dragThreshold || velocity > 200 {
                                        isCalendarOpen = false
                                    }
                                } else {
                                    // Open if dragged up far enough
                                    if translation < -dragThreshold || velocity < -200 {
                                        isCalendarOpen = true
                                    }
                                }
                                dragOffset = 0
                            }
                        }
                )

            }
            .ignoresSafeArea(edges: .bottom) // Ensures panel slides completely off screen
            .navigationTitle(headerTitle)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // MARK: - HELPERS
    private func closeCalendar() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isCalendarOpen = false
            dragOffset = 0
        }
    }
}

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
            // INPUT FIELD
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
            
            // LIST
            if tasks.isEmpty {
                ContentUnavailableView(
                    "No Tasks",
                    systemImage: "checklist",
                    description: Text("Plan your day on \(date.formatted(date: .abbreviated, time: .omitted)).")
                )
            } else {
                List {
                    ForEach(tasks) { task in
                        HStack {
                            Button(action: { toggleTask(task) }) {
                                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(task.isCompleted ? .green : .gray)
                                    .font(.title2)
                            }
                            .buttonStyle(.plain)
                            
                            Text(task.title)
                                .strikethrough(task.isCompleted)
                                .foregroundStyle(task.isCompleted ? .gray : .primary)
                        }
                    }
                    .onDelete(perform: deleteTasks)
                }
                .listStyle(.plain)
                // Add bottom padding so the last item isn't covered by the Bottom Bar
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: 100)
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
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    private func toggleTask(_ task: TaskItem) {
        task.isCompleted.toggle()
        if task.isCompleted { UIImpactFeedbackGenerator(style: .heavy).impactOccurred() }
    }
    
    private func deleteTasks(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(tasks[index])
            }
        }
    }
}
