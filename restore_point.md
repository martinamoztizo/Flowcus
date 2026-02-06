# Restore Point - February 5, 2026

This file contains the current state of the Flowcus app source code.

## Flowcus/ContentView.swift

```swift
//
//  ContentView.swift
//  Flowcus
//
//  Created by E on 2/3/26.
//

import SwiftUI
import SwiftData

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
        .tint(.indigo)
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
    
    // PERMANENT SETTINGS
    @AppStorage("workMinutes") private var defaultWorkTime = 25
    @AppStorage("shortBreakMinutes") private var shortBreakTime = 5
    @AppStorage("longBreakMinutes") private var longBreakTime = 15
    
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
    // Stopped (White BG) -> Black Text
    // Active (Black BG) -> White Text
    var contentColor: Color {
        return isSessionActive ? .white : .black
    }
    
    // MARK: - STATUS BAR LOGIC (USER REQUEST)
    // 0.965 is roughly the halfway point of the Notch/Battery area.
    var statusBarScheme: ColorScheme {
        if !isSessionActive {
            return .light // Stopped -> White BG -> Black Icons
        }
        // Active Session (Black BG):
        // If Liquid > 96.5% (Covering the battery) -> Black Icons (.light)
        // If Liquid < 96.5% (Revealing Black BG) -> White Icons (.dark)
        return liquidHeightPercentage > 0.965 ? .light : .dark
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // 1. BACKGROUND (Dynamic)
                // White when stopped. Black when running (The "Void" behind the liquid).
                (isSessionActive ? Color.black : Color.white)
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
                                    .colorScheme(isPaused ? .dark : .light)
                                    .onChange(of: selectedMode) { newMode in updateTimerForMode(newMode) }
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
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.fill")
                            .font(.caption)
                            .foregroundStyle(contentColor == .white ? .yellow : themeColors[0])
                        Text("\(timerManager.xpPoints) XP")
                            .font(.caption).fontWeight(.bold).foregroundStyle(contentColor)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(contentColor == .white ? Material.thin : Material.regular)
                    .cornerRadius(20)
                    .animation(.easeIn(duration: 0.3), value: contentColor)
                }
                
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
            .onChange(of: timerManager.timeRemaining) { timeLeft in
                if timeLeft == 0 && timerManager.isRunning {
                    completeSession()
                }
            }
            .onChange(of: scenePhase) { newPhase in
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
                selectedMode = "Short Break"
            } else if selectedMode == "Short Break" {
                selectedMode = "Focus"
            } else if selectedMode == "Long Break" {
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
                Section(header: Text("Tap to Edit")) {
                    Button(action: { activeSetting = .work }) {
                        HStack {
                            Text("Focus Duration").foregroundStyle(.primary)
                            Spacer()
                            Text("\(defaultWorkTime) min").foregroundStyle(.indigo)
                        }
                    }
                    Button(action: { activeSetting = .shortBreak }) {
                        HStack {
                            Text("Short Break").foregroundStyle(.primary)
                            Spacer()
                            Text("\(shortBreakTime) min").foregroundStyle(.indigo)
                        }
                    }
                    Button(action: { activeSetting = .longBreak }) {
                        HStack {
                            Text("Long Break").foregroundStyle(.primary)
                            Spacer()
                            Text("\(longBreakTime) min").foregroundStyle(.indigo)
                        }
                    }
                }
                Section {
                    Text("Your changes are saved automatically.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Timer Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .sheet(item: $activeSetting) { setting in
                TimePickerSheet(title: setting.title, value: binding(for: setting))
                    .presentationDetents([.height(350)])
                    .presentationCornerRadius(25)
            }
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
    @Environment(\.dismiss) var dismiss
    
    @State private var isCustomMode = false
    @State private var customInputText = ""
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 20) {
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
            
            if isCustomMode {
                VStack(spacing: 20) {
                    Text("Enter Minutes").font(.subheadline).foregroundStyle(.secondary)
                    TextField("e.g. 90", text: $customInputText)
                        .font(.system(size: 40, weight: .bold))
                        .multilineTextAlignment(.center)
                        .keyboardType(.numberPad)
                        .focused($isInputFocused)
                        .onAppear { isInputFocused = true }
                    Button("Switch to Wheel") { withAnimation { isCustomMode = false } }
                        .font(.caption).foregroundStyle(.indigo)
                }
                .padding(.top, 20).transition(.opacity)
            } else {
                Picker("Time", selection: $value) {
                    ForEach(1...60, id: \.self) { min in Text("\(min) min").tag(min) }
                }
                .pickerStyle(.wheel)
                .padding(.horizontal).transition(.opacity)
                
                Button("Enter Custom Amount") { withAnimation { isCustomMode = true } }
                    .font(.subheadline).foregroundStyle(.indigo).padding(.bottom, 20)
            }
            Spacer()
        }
    }
}

// MARK: - 2. TASK LIST VIEW
struct TaskListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskItem.createdAt, order: .reverse) private var tasks: [TaskItem]
    @State private var newTaskTitle: String = ""
    
    var body: some View {
        NavigationStack {
            VStack {
                HStack {
                    TextField("New task...", text: $newTaskTitle)
                        .padding().background(Color(.systemGray6)).cornerRadius(10)
                        .submitLabel(.done).onSubmit(addTask)
                    Button(action: addTask) {
                        Image(systemName: "plus").font(.title2).padding()
                            .background(Color.indigo).foregroundColor(.white).cornerRadius(10)
                    }
                }
                .padding()
                
                if tasks.isEmpty {
                    ContentUnavailableView("No Tasks", systemImage: "checkmark.circle", description: Text("Add a task to clear your mind."))
                } else {
                    List {
                        ForEach(tasks) { task in
                            HStack {
                                Button(action: { toggleTask(task) }) {
                                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(task.isCompleted ? .green : .gray).font(.title2)
                                }
                                .buttonStyle(.plain)
                                Text(task.title).strikethrough(task.isCompleted).foregroundStyle(task.isCompleted ? .gray : .primary)
                            }
                        }
                        .onDelete(perform: deleteTasks)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("To-Do")
        }
    }
    
    private func addTask() {
        guard !newTaskTitle.isEmpty else { return }
        modelContext.insert(TaskItem(title: newTaskTitle))
        newTaskTitle = ""
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    private func toggleTask(_ task: TaskItem) {
        task.isCompleted.toggle()
        if task.isCompleted { UIImpactFeedbackGenerator(style: .heavy).impactOccurred() }
    }
    
    private func deleteTasks(offsets: IndexSet) {
        withAnimation { for index in offsets { modelContext.delete(tasks[index]) } }
    }
}

// MARK: - 3. JOURNAL VIEW
struct JournalView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \JournalEntry.timestamp, order: .reverse) private var entries: [JournalEntry]
    @State private var showingAddSheet = false
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(entries) { entry in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Text(entry.mood).font(.caption).padding(4).background(Color(.systemGray6)).cornerRadius(5)
                        }
                        Text(entry.content).font(.body)
                    }
                }
                .onDelete(perform: deleteEntries)
            }
            .navigationTitle("Brain Dump")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingAddSheet = true }) { Image(systemName: "square.and.pencil") }
                }
            }
            .sheet(isPresented: $showingAddSheet) { AddJournalView() }
            .overlay {
                if entries.isEmpty { ContentUnavailableView("Empty Journal", systemImage: "book", description: Text("Write down your progress.")) }
            }
        }
    }
    
    private func deleteEntries(offsets: IndexSet) {
        withAnimation { for index in offsets { modelContext.delete(entries[index]) } }
    }
}

struct AddJournalView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    @State private var text: String = ""
    @State private var selectedMood: String = "Neutral"
    let moods = ["🔥", "🙂", "😐", "😫", "🧠"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Mood") {
                    Picker("Mood", selection: $selectedMood) {
                        ForEach(moods, id: \.self) { mood in Text(mood).tag(mood) }
                    }
                    .pickerStyle(.segmented)
                }
                Section("Log") {
                    TextEditor(text: $text).frame(minHeight: 150)
                }
            }
            .navigationTitle("New Entry")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        modelContext.insert(JournalEntry(content: text, mood: selectedMood))
                        dismiss()
                    }
                }
            }
        }
    }
}
```

## Flowcus/TimeManager.swift

```swift
//
//  TimeManager.swift
//  Flowcus
//
//  Created by E on 2/3/26.
//

import SwiftUI
import Combine

class TimerManager: ObservableObject {
    // These @Published markers are CRITICAL. They tell the UI to update.
    @Published var timeRemaining: TimeInterval = 25 * 60
    @Published var initialTime: TimeInterval = 25 * 60
    @Published var isRunning: Bool = false
    
    // XP Points - Stored permanently
    @Published var xpPoints: Int = UserDefaults.standard.integer(forKey: "user_xp") {
        didSet {
            UserDefaults.standard.set(xpPoints, forKey: "user_xp")
        }
    }
    
    var timer: Timer?
    var lastBackgroundDate: Date?
    
    // Function to set custom minutes (The feature you requested)
    func setDuration(minutes: Int) {
        pause()
        let newTime = TimeInterval(minutes * 60)
        timeRemaining = newTime
        initialTime = newTime
    }
    
    func start() {
        guard !isRunning else { return }
        isRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            self.tick()
        }
    }
    
    func pause() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }
    
    private func tick() {
        if timeRemaining > 0 {
            timeRemaining -= 1
        } else {
            completeTimer()
        }
    }
    
    private func completeTimer() {
        pause()
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        // Award XP only if the session was longer than 20 mins
        if initialTime >= 20 * 60 {
            xpPoints += 100
        }
    }
    
    // Background handling logic
    func appMovedToBackground() {
        if isRunning {
            lastBackgroundDate = Date()
            timer?.invalidate()
        }
    }
    
    func appMovedToForeground() {
        if isRunning, let backgroundDate = lastBackgroundDate {
            let timePassed = Date().timeIntervalSince(backgroundDate)
            timeRemaining -= timePassed
            if timeRemaining <= 0 {
                timeRemaining = 0
                completeTimer()
            } else {
                start()
            }
        }
        lastBackgroundDate = nil
    }
    
    var progress: Double {
        guard initialTime > 0 else { return 1.0 }
        return 1.0 - (timeRemaining / initialTime)
    }
    
    var timeString: String {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
```

## Flowcus/Models.swift

```swift
//
//  Models.swift
//  Flowcus
//
//  Created by E on 2/3/26.
//

import Foundation
import SwiftData

@Model
class TaskItem {
    var title: String
    var isCompleted: Bool
    var createdAt: Date
    
    init(title: String, isCompleted: Bool = false) {
        self.title = title
        self.isCompleted = isCompleted
        self.createdAt = Date()
    }
}

@Model
class JournalEntry {
    var content: String
    var timestamp: Date
    var mood: String // Simple "Good", "Neutral", "Bad" tracker
    
    init(content: String, mood: String = "Neutral") {
        self.content = content
        self.timestamp = Date()
        self.mood = mood
    }
}
```
