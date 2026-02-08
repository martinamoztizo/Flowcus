//
//  ContentView.swift
//  Flowcus
//
//  Created by E on 2/3/26.
//

import SwiftUI
import SwiftData

// MARK: - COLORS
extension Color {
    static let cardinalRed = Color(red: 0.768, green: 0.118, blue: 0.227)
}

extension ShapeStyle where Self == Color {
    static var cardinalRed: Color { .cardinalRed }
}

// MARK: - APP ENTRY POINT
struct ContentView: View {
    var body: some View {
        TabView {
            FocusTimerView()
                .tabItem {
                    Label("Focus", systemImage: "timer")
                }
            
            TaskListView()
                .tabItem {
                    Label("Tasks", systemImage: "checkmark.circle.fill")
                }
            
            JournalView()
                .tabItem {
                    Label("Journal", systemImage: "book.fill")
                }
        }
        .tint(.cardinalRed)
    }
}

// MARK: - 1. CUSTOM WAVE SHAPE
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

// MARK: - 2. FOCUS TIMER VIEW (FINAL STATUS BAR LOGIC)
struct FocusTimerView: View {
    @StateObject private var timerManager = TimerManager()
    @Environment(\.scenePhase) var scenePhase
    @Environment(\.colorScheme) var colorScheme
    
    // PERMANENT SETTINGS
    @AppStorage("workMinutes") private var defaultWorkTime = 25
    @AppStorage("shortBreakMinutes") private var shortBreakTime = 5
    @AppStorage("longBreakMinutes") private var longBreakTime = 15
    @AppStorage("sessionCount") private var sessionCount = 0
    
    @State private var showingSettings = false
    @State private var selectedMode = "Focus"
    let modes = ["Focus", "Short Break", "Long Break"]
    
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
        case "Short Break":
            return [Color.teal.opacity(0.8), Color.cyan.opacity(0.6)]
        case "Long Break":
            return [Color(red: 0.4, green: 0.8, blue: 0.6).opacity(0.9), Color.mint.opacity(0.7)]
        default: // Focus
            return [Color.red.opacity(0.9), Color.red.opacity(0.7)]
        }
    }
    
    // Content Text Color (Timer numbers)
    // Session Active -> Always White (on Black BG)
    // Session Stopped -> Adaptive (Black in Light Mode, White in Dark Mode)
    var contentColor: Color {
        if isSessionActive {
            return .white
        } else {
            return colorScheme == .dark ? .white : .black
        }
    }
    
    // Background Color Logic
    // Session Active -> Always Black (The Void)
    // Session Stopped -> Adaptive (White in Light Mode, Black in Dark Mode)
    var backgroundColor: Color {
        if isSessionActive {
            return .black
        } else {
            return colorScheme == .dark ? .black : .white
        }
    }
    
    // MARK: - STATUS BAR LOGIC (USER REQUEST)
    var statusBarScheme: ColorScheme {
        if !isSessionActive {
            // Stopped: Adaptive
            return colorScheme == .dark ? .dark : .light
        }
        
        // Active Session (Always Black BG):
        // If Liquid > 96.5% (Covering the battery) -> Black Icons (.light)
        // If Liquid < 96.5% (Revealing Black BG) -> White Icons (.dark)
        return liquidHeightPercentage > 0.965 ? .light : .dark
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
                    TimelineView(.animation) { timeline in
                        let time = timeline.date.timeIntervalSinceReferenceDate
                        
                        ZStack(alignment: .bottom) {
                            
                            // Wave 1 (Back Layer)
                            Wave(offset: Angle(degrees: time * 50), percent: liquidHeightPercentage)
                                .fill(themeColors[1])
                                .ignoresSafeArea()
                                .animation(.spring(response: 2.0, dampingFraction: 1.0), value: liquidHeightPercentage)
                            
                            // Wave 2 (Front Layer)
                            Wave(offset: Angle(degrees: time * 70 + 90), percent: liquidHeightPercentage)
                                .fill(themeColors[0])
                                .ignoresSafeArea()
                                .animation(.spring(response: 1.5, dampingFraction: 0.8), value: liquidHeightPercentage)
                        }
                    }
                }
                .ignoresSafeArea(.all)
                
                // 3. CONTENT OVERLAY
                VStack(spacing: 0) {
                    Spacer()
                    
                    // TIMER TEXT
                    VStack(spacing: 10) {
                        Text(timerManager.timeString)
                            .font(.system(size: 95, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(contentColor)
                            .contentTransition(.numericText())
                            // Add shadow if text is white (on liquid) for readability
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
                    .onTapGesture { handleTap() }
                    
                    Spacer()
                    
                    // CONTROLS
                    ZStack(alignment: .bottom) {
                        if !timerManager.isRunning {
                            VStack(spacing: 30) {
                                if !isPaused {
                                    Picker("Mode", selection: $selectedMode) {
                                        ForEach(modes, id: \.self) { mode in Text(mode) }
                                    }
                                    .pickerStyle(.segmented)
                                    .padding(.horizontal, 40)
                                    // Adapt picker text to background
                                    .colorScheme(contentColor == .white ? .dark : .light)
                                    .onChange(of: selectedMode) { _, newMode in updateTimerForMode(newMode) }
                                    .transition(.move(edge: .bottom).combined(with: .opacity))
                                }
                                
                                if isPaused {
                                    Button(action: stopTimer) {
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
                                    Button(action: {
                                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                            timerManager.start()
                                            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                                        }
                                    }) {
                                        Text("Start \(selectedMode)")
                                            .font(.title3).fontWeight(.semibold)
                                            .frame(maxWidth: .infinity).frame(height: 60)
                                            .background(themeColors[0])
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
                            // Tap Area while running
                            Color.clear.contentShape(Rectangle()).frame(height: 150)
                                .onTapGesture { handleTap() }
                            Text("Tap screen to pause")
                                .font(.caption).foregroundStyle(contentColor.opacity(0.6)).padding(.bottom, 50)
                        }
                    }
                }
            }
            // --- STATUS BAR MAGIC ---
            // Applies the exact logic: Black icons when covered, White icons when draining on black bg
            .toolbarColorScheme(statusBarScheme, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            
            // HIDES TAB BAR WHEN RUNNING
            .toolbar(timerManager.isRunning ? .hidden : .visible, for: .tabBar)
            .animation(.easeInOut, value: timerManager.isRunning)
            
            // TOOLBAR
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
            .onChange(of: timerManager.timeRemaining) { _, timeLeft in
                if timeLeft == 0 && timerManager.isRunning {
                    completeSession()
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active { timerManager.appMovedToForeground() }
                if newPhase == .background { timerManager.appMovedToBackground() }
            }
            .onAppear {
                if !timerManager.isRunning { updateTimerForMode(selectedMode) }
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
            if selectedMode == "Focus" {
                sessionCount += 1
                if sessionCount >= 2 {
                    selectedMode = "Long Break"
                    sessionCount = 0 // Reset after long break trigger
                } else {
                    selectedMode = "Short Break"
                }
            } else {
                // Return to Focus after any break
                selectedMode = "Focus"
            }
            updateTimerForMode(selectedMode)
        }
    }
    
    private func updateTimerForMode(_ mode: String) {
        guard !timerManager.isRunning else { return }
        switch mode {
        case "Focus": timerManager.setDuration(minutes: defaultWorkTime)
        case "Short Break": timerManager.setDuration(minutes: shortBreakTime)
        case "Long Break": timerManager.setDuration(minutes: longBreakTime)
        default: break
        }
    }
}

// MARK: - SETTINGS VIEW
struct TimerPreset: Identifiable {
    let id = UUID()
    let name: String
    let focus: Int
    let short: Int
    let long: Int
}

let timerPresets = [
    TimerPreset(name: "Classic", focus: 25, short: 5, long: 15),
    TimerPreset(name: "Extended", focus: 50, short: 10, long: 20),
    TimerPreset(name: "Science", focus: 52, short: 17, long: 20),
    TimerPreset(name: "Deep", focus: 90, short: 20, long: 30)
]

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    
    @AppStorage("workMinutes") private var defaultWorkTime = 25
    @AppStorage("shortBreakMinutes") private var shortBreakTime = 5
    @AppStorage("longBreakMinutes") private var longBreakTime = 15
    
    @State private var activeSetting: SettingType?
    
    enum SettingType: Identifiable {
        case work, shortBreak, longBreak
        var id: Self { self }
        var title: String {
            switch self {
            case .work: return "Focus Duration"
            case .shortBreak: return "Short Break"
            case .longBreak: return "Long Break"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button(action: { activeSetting = .work }) {
                        HStack {
                            Text("Focus Duration").foregroundStyle(.primary)
                            Spacer()
                            Text("\(defaultWorkTime) min").foregroundStyle(.cardinalRed)
                        }
                    }
                    Button(action: { activeSetting = .shortBreak }) {
                        HStack {
                            Text("Short Break").foregroundStyle(.primary)
                            Spacer()
                            Text("\(shortBreakTime) min").foregroundStyle(.cardinalRed)
                        }
                    }
                    Button(action: { activeSetting = .longBreak }) {
                        HStack {
                            Text("Long Break").foregroundStyle(.primary)
                            Spacer()
                            Text("\(longBreakTime) min").foregroundStyle(.cardinalRed)
                        }
                    }
                }
                
                Section {
                    Text("Selecting a standard duration will automatically update your setup.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Timer Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .sheet(item: $activeSetting) { setting in
                TimePickerSheet(title: setting.title, value: binding(for: setting), presetValues: getPresets(for: setting))
                    .presentationDetents([.height(250)])
                    .presentationCornerRadius(25)
            }
            // AUTO-UPDATE LOGIC
            .onChange(of: defaultWorkTime) { _, newValue in
                if let preset = timerPresets.first(where: { $0.focus == newValue }) {
                    shortBreakTime = preset.short
                    longBreakTime = preset.long
                }
            }
            .onChange(of: shortBreakTime) { _, newValue in
                // Reverse update for Short Break (Unique values allow this)
                if let preset = timerPresets.first(where: { $0.short == newValue }) {
                    defaultWorkTime = preset.focus
                    longBreakTime = preset.long
                }
            }
        }
    }
    
    private func getPresets(for setting: SettingType) -> [Int] {
        switch setting {
        case .work: return timerPresets.map(\.focus)
        case .shortBreak: return timerPresets.map(\.short)
        case .longBreak: return Array(Set(timerPresets.map(\.long))).sorted()
        }
    }
    
    private func binding(for setting: SettingType) -> Binding<Int> {
        switch setting {
        case .work: return $defaultWorkTime
        case .shortBreak: return $shortBreakTime
        case .longBreak: return $longBreakTime
        }
    }
}

// MARK: - CUSTOM PICKER SHEET
struct TimePickerSheet: View {
    let title: String
    @Binding var value: Int
    let presetValues: [Int]
    @Environment(\.dismiss) var dismiss
    
    @State private var isCustomMode = false
    @State private var customInputText = ""
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                Button("Done") {
                    if isCustomMode, let newValue = Int(customInputText) { value = newValue }
                    dismiss()
                }
                .fontWeight(.bold)
            }
            .padding().background(Color(.systemGray6))
            
            VStack(spacing: 10) {
                if isCustomMode {
                    // CUSTOM TEXT INPUT
                    VStack(spacing: 20) {
                        Text("Enter Minutes").font(.subheadline).foregroundStyle(.secondary)
                        TextField("e.g. 90", text: $customInputText)
                            .font(.system(size: 40, weight: .bold))
                            .multilineTextAlignment(.center)
                            .keyboardType(.numberPad)
                                 .focused($isInputFocused)
                            .onAppear { 
                                customInputText = "\(value)"
                                isInputFocused = true 
                            }
                        Button("Switch to Wheel") { withAnimation { isCustomMode = false } }
                            .font(.caption).foregroundStyle(.cardinalRed)
                    }
                    .padding(.top, 20).transition(.opacity)
                } else {
                    // RESTRICTED WHEEL
                    VStack(spacing: 0) {
                        Picker("Time", selection: $value) {
                            ForEach(presetValues, id: \.self) { min in 
                                Text("\(min) min").tag(min) 
                            }
                        }
                        .pickerStyle(.wheel)
                        .padding(.horizontal)
                        
                        Button("Enter Custom Amount") { withAnimation { isCustomMode = true } }
                            .font(.subheadline).foregroundStyle(.cardinalRed).padding(.bottom, 5)
                    }
                    .transition(.opacity)
                }
            }
            Spacer()
        }
    }
}

// MARK: - 2. TASK LIST VIEW
struct TaskListView: View {
    @State private var selectedDate: Date = Date()
    
    // Interaction State
    @State private var dragOffset: CGFloat = 0
    @State private var isCalendarOpen: Bool = false
    
    // Constants
    let calendarHeight: CGFloat = 400
    let closedOffset: CGFloat = 300 // Lifted so text is visible with tight gap
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
                    VStack(spacing: 20) {
                        // Handle
                        Capsule()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 40, height: 5)
                            .padding(.top, 15)
                        
                        DatePicker("", selection: $selectedDate, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .padding(.horizontal)
                        
                        Spacer()
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
        guard !newTaskTitle.isEmpty else { return }
        // Create task specifically for the selected date
        let newTask = TaskItem(title: newTaskTitle, scheduledDate: date)
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

// MARK: - 3. JOURNAL VIEW (TITLE SUPPORT)
struct JournalView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \JournalEntry.timestamp, order: .reverse) private var entries: [JournalEntry]
    
    @State private var showingAddSheet = false
    @State private var editingEntry: JournalEntry? // Tracks selection
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(entries) { entry in
                    // Make the row tappable to Edit
                    Button(action: { editingEntry = entry }) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                // Title is now prominent
                                if !entry.title.isEmpty {
                                    Text(entry.title)
                                        .font(.headline)
                                        .lineLimit(1)
                                } else {
                                    Text("Untitled Entry")
                                        .font(.headline)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                Text(entry.mood)
                                    .font(.caption).padding(4)
                                    .background(Color(.systemGray6)).cornerRadius(5)
                            }
                            
                            HStack {
                                Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            
                            Text(entry.content)
                                .font(.body)
                                .multilineTextAlignment(.leading)
                                .lineLimit(3)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .onDelete(perform: deleteEntries)
            }
            .navigationTitle("Brain Dump")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingAddSheet = true }) { Image(systemName: "square.and.pencil") }
                }
            }
            // Sheet for ADDING (entry is nil)
            .sheet(isPresented: $showingAddSheet) {
                JournalEditorView(entry: nil)
            }
            // Sheet for EDITING (entry is passed)
            .sheet(item: $editingEntry) { entry in
                JournalEditorView(entry: entry)
            }
            .overlay {
                if entries.isEmpty { ContentUnavailableView("Empty Journal", systemImage: "book", description: Text("Write down your progress.")) }
            }
        }
    }
    
    private func deleteEntries(offsets: IndexSet) {
        withAnimation { for index in offsets { modelContext.delete(entries[index]) } }
    }
}

// MARK: - JOURNAL EDITOR VIEW (Formerly AddJournalView)
struct JournalEditorView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    
    // Optional Entry for Editing Mode
    var entry: JournalEntry?
    
    @State private var title: String = ""
    @State private var text: String = ""
    @State private var selectedMood: String = "Neutral"
    @FocusState private var isTitleFocused: Bool // Track focus for the title
    
    let moods = ["🔥", "🙂", "😐", "😫", "🧠"]
    
    var body: some View {
        NavigationStack {
            Form {
                // Editable Large Title Area
                ZStack(alignment: .leading) {
                    if title.isEmpty && !isTitleFocused {
                        Text("New Entry")
                            .font(.largeTitle.bold())
                            .foregroundStyle(.primary) // 100% Opacity
                    }
                    
                    TextField("", text: $title)
                        .font(.largeTitle.bold())
                        .focused($isTitleFocused)
                        .foregroundStyle(.primary)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 20))
                
                Section("Mood") {
                    Picker("Mood", selection: $selectedMood) {
                        ForEach(moods, id: \.self) { mood in Text(mood).tag(mood) }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Log") {
                    TextEditor(text: $text)
                        .frame(minHeight: 250)
                        .overlay(alignment: .topLeading) {
                            if text.isEmpty {
                                Text("Write your thoughts here...")
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                            }
                        }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let entry = entry {
                    title = entry.title
                    text = entry.content
                    selectedMood = entry.mood
                } else {
                    // Start empty so the placeholder "New Entry" shows and disappears on type
                    title = ""
                }
            }
        }
    }
    
    private func save() {
        if let entry = entry {
            // Update Existing
            entry.title = title
            entry.content = text
            entry.mood = selectedMood
        } else {
            // Create New
            modelContext.insert(JournalEntry(title: title, content: text, mood: selectedMood))
        }
    }
}
