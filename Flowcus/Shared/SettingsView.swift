//
//  SettingsView.swift
//  Flowcus
//

import SwiftUI

// MARK: - Timer Presets

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

// MARK: - Settings View

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
                        .font(.appCaption).foregroundStyle(.secondary)
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

// MARK: - Custom Picker Sheet

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
                Text(title).font(.appHeadline)
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
                        Text("Enter Minutes").font(.appSubhead).foregroundStyle(.secondary)
                        TextField("e.g. 90", text: $customInputText)
                            .font(.appDisplay(size: 40))
                            .multilineTextAlignment(.center)
                            .keyboardType(.numberPad)
                                 .focused($isInputFocused)
                            .onAppear {
                                customInputText = "\(value)"
                                isInputFocused = true
                            }
                        Button("Switch to Wheel") { withAnimation { isCustomMode = false } }
                            .font(.appCaption).foregroundStyle(.cardinalRed)
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
                            .font(.appSubhead).foregroundStyle(.cardinalRed).padding(.bottom, 5)
                    }
                    .transition(.opacity)
                }
            }
            Spacer()
        }
    }
}
