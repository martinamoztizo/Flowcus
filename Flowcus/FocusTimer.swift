//
//  FocusTimer.swift
//  Flowcus
//

import SwiftUI
import SwiftData

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
    @StateObject private var timerManager = TimeManager()
    @Environment(\.scenePhase) var scenePhase
    @Environment(\.colorScheme) var colorScheme
    
    // PERMANENT SETTINGS
    @AppStorage("workMinutes") private var defaultWorkTime = 25
    @AppStorage("shortBreakMinutes") private var shortBreakTime = 5
    @AppStorage("longBreakMinutes") private var longBreakTime = 15
    @AppStorage("sessionCount") private var sessionCount = 0
    @AppStorage("totalXP") private var totalXP = 0
    
    // PERSIST MODE (Safe String Storage)
    @AppStorage("selectedModeRaw") private var selectedModeRaw: String = TimerMode.focus.rawValue
    
    var selectedMode: TimerMode {
        get { TimerMode(rawValue: selectedModeRaw) ?? .focus }
        nonmutating set { selectedModeRaw = newValue.rawValue }
    }
    
    @State private var showingSettings = false
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
    // We use preferredColorScheme to force Dark Mode (White Status Bar) when session is active
    var preferredScheme: ColorScheme? {
        if isSessionActive {
            return .dark // Forces white status bar text + black background
        }
        return nil // Follow system
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
                                // Wave 1 (Back Layer) - ALWAYS FULL
                                Wave(offset: Angle(degrees: time * 50), percent: 1.1)
                                    .fill(themeColors[1])
                                    .ignoresSafeArea()
                                
                                // Wave 2 (Front Layer) - ALWAYS FULL
                                Wave(offset: Angle(degrees: time * 70 + 90), percent: 1.1)
                                    .fill(themeColors[0])
                                    .ignoresSafeArea()
                            }
                        }
                    }
                    // ANIMATE POSITION instead of shape morphing
                    // When liquidHeightPercentage is 0, offset is full height (hidden at bottom)
                    // When liquidHeightPercentage is 1.1, offset is 0 (full screen)
                    .offset(y: geo.size.height * (1.1 - liquidHeightPercentage))
                    .animation(.spring(response: 2.0, dampingFraction: 1.0), value: liquidHeightPercentage)
                }
                .ignoresSafeArea(.all)
                
                // 3. CONTENT OVERLAY
                VStack(spacing: 0) {
                    Spacer()
                    
                    // TIMER TEXT
                    TimerDisplayView(
                        timeString: timerManager.timeString,
                        isPaused: isPaused,
                        contentColor: contentColor,
                        onTap: handleTap
                    )
                    
                    Spacer()
                    
                    // CONTROLS
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
                        onStop: stopTimer,
                        onStart: {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                timerManager.start()
                                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                            }
                        }
                    )
                }
            }
            // HIDES TAB BAR WHEN RUNNING
            .toolbar(timerManager.isRunning ? .hidden : .visible, for: .tabBar)
            .animation(.easeInOut, value: timerManager.isRunning)
            // FORCE DARK MODE WHEN ACTIVE (Fixes Status Bar to White)
            .preferredColorScheme(preferredScheme)

            
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
            .onChange(of: timerManager.completionEvents) { _, _ in
                completeSession()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active { timerManager.appMovedToForeground() }
                if newPhase == .background { timerManager.appMovedToBackground() }
            }
            // Sync logic when mode changes from controls
            .onChange(of: selectedMode) { _, newMode in
                 if !timerManager.isRunning { updateTimerForMode(newMode) }
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
            if selectedMode == .focus {
                totalXP += focusSessionXP
                sessionCount += 1
                if sessionCount >= 2 {
                    selectedMode = .longBreak
                    sessionCount = 0 // Reset after long break trigger
                } else {
                    selectedMode = .shortBreak
                }
            } else {
                // Return to Focus after any break
                selectedMode = .focus
            }
            updateTimerForMode(selectedMode)
        }
    }
    
    private func updateTimerForMode(_ mode: TimerMode) {
        guard !timerManager.isRunning else { return }
        switch mode {
        case .focus: timerManager.setDuration(minutes: defaultWorkTime)
        case .shortBreak: timerManager.setDuration(minutes: shortBreakTime)
        case .longBreak: timerManager.setDuration(minutes: longBreakTime)
        }
    }
}

// MARK: - SUBVIEWS FOR COMPILER OPTIMIZATION
struct TimerDisplayView: View {
    let timeString: String
    let isPaused: Bool
    let contentColor: Color
    let onTap: () -> Void
    
    var body: some View {
        VStack(spacing: 10) {
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
                // Tap Area while running
                Color.clear.contentShape(Rectangle()).frame(height: 150)
                    .onTapGesture { onTapRunning() }
                Text("Tap screen to pause")
                    .font(.caption).foregroundStyle(contentColor.opacity(0.6)).padding(.bottom, 50)
            }
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
            .onAppear {
                defaultWorkTime = clampedDuration(defaultWorkTime)
                shortBreakTime = clampedDuration(shortBreakTime)
                longBreakTime = clampedDuration(longBreakTime)
            }
            // AUTO-UPDATE LOGIC
            .onChange(of: defaultWorkTime) { _, newValue in
                defaultWorkTime = clampedDuration(newValue)
                if let preset = matchingPreset(for: .work, value: defaultWorkTime) {
                    applyPreset(preset)
                }
            }
            .onChange(of: shortBreakTime) { _, newValue in
                shortBreakTime = clampedDuration(newValue)
                if let preset = matchingPreset(for: .shortBreak, value: shortBreakTime) {
                    applyPreset(preset)
                }
            }
            .onChange(of: longBreakTime) { _, newValue in
                longBreakTime = clampedDuration(newValue)
                if let preset = matchingPreset(for: .longBreak, value: longBreakTime) {
                    applyPreset(preset)
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

    private func clampedDuration(_ value: Int) -> Int {
        min(max(value, TimeManager.minDurationMinutes), TimeManager.maxDurationMinutes)
    }

    private func applyPreset(_ preset: TimerPreset) {
        if defaultWorkTime != preset.focus { defaultWorkTime = preset.focus }
        if shortBreakTime != preset.short { shortBreakTime = preset.short }
        if longBreakTime != preset.long { longBreakTime = preset.long }
    }

    private func matchingPreset(for setting: SettingType, value: Int) -> TimerPreset? {
        switch setting {
        case .work:
            return timerPresets.first(where: { $0.focus == value })
        case .shortBreak:
            return timerPresets.first(where: { $0.short == value })
        case .longBreak:
            return timerPresets.first(where: { $0.long == value && ($0.focus == defaultWorkTime || $0.short == shortBreakTime) })
                ?? timerPresets.first(where: { $0.long == value })
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
                    if isCustomMode, let newValue = Int(customInputText) {
                        value = min(max(newValue, TimeManager.minDurationMinutes), TimeManager.maxDurationMinutes)
                    }
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
