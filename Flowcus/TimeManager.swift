//
//  TimeManager.swift
//  Flowcus
//
//  Created by E on 2/3/26.
//

import SwiftUI
import Combine

enum TimerMode: String, CaseIterable, Identifiable {
    case focus = "Focus"
    case shortBreak = "Short Break"
    case longBreak = "Long Break"
    
    var id: String { self.rawValue }
    var displayTitle: String { self.rawValue }
}

// MARK: - IMMORTAL STATE MACHINE
enum TimerState: Codable {
    case idle(duration: TimeInterval)
    case running(targetEndTime: Date, duration: TimeInterval)
    case paused(timeRemaining: TimeInterval, duration: TimeInterval)
}

class TimeManager: ObservableObject {
    static let minDurationMinutes = 1
    static let maxDurationMinutes = 1440
    private let stateKey = "flowcus_timer_state"

    @Published var timeRemaining: TimeInterval = 25 * 60
    @Published var initialTime: TimeInterval = 25 * 60
    @Published var isRunning: Bool = false
    @Published private(set) var completionEvents: Int = 0
    
    private var timer: Timer?
    
    // The Single Source of Truth
    private var state: TimerState = .idle(duration: 25 * 60) {
        didSet {
            saveState()
            updateUIFromState()
        }
    }

    init() {
        loadState()
    }

    deinit {
        timer?.invalidate()
    }
    
    func setDuration(minutes: Int) {
        let clampedMinutes = min(max(minutes, Self.minDurationMinutes), Self.maxDurationMinutes)
        let newDuration = TimeInterval(clampedMinutes * 60)
        // Directly set to idle to avoid double-saving from a pause() call
        timer?.invalidate()
        timer = nil
        state = .idle(duration: newDuration)
    }
    
    func start() {
        switch state {
        case .idle(let duration), .paused(_, let duration):
            let target = Date().addingTimeInterval(timeRemaining)
            state = .running(targetEndTime: target, duration: duration)
            scheduleTimer()
        case .running:
            break
        }
    }
    
    func pause() {
        switch state {
        case .running(_, let duration):
            state = .paused(timeRemaining: timeRemaining, duration: duration)
            timer?.invalidate()
            timer = nil
        case .idle, .paused:
            break
        }
    }
    
    private func completeTimer() {
        let currentDuration = initialTime
        state = .paused(timeRemaining: 0, duration: currentDuration)
        timer?.invalidate()
        timer = nil
        
        completionEvents += 1
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    private func scheduleTimer() {
        timer?.invalidate()
        let newTimer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.tick()
        }
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
    }
    
    private func tick() {
        switch state {
        case .running(let targetEndTime, _):
            let remaining = targetEndTime.timeIntervalSinceNow
            if remaining <= 0 {
                completeTimer()
            } else {
                timeRemaining = remaining
            }
        case .idle, .paused:
            timer?.invalidate()
            timer = nil
        }
    }
    
    // MARK: - APP LIFECYCLE (Battery Optimization)
    
    func appMovedToBackground() {
        // Stop the ticking to save battery. The state is safe on disk.
        timer?.invalidate()
        timer = nil
    }
    
    func appMovedToForeground() {
        // When coming back, instantly refresh the UI and restart the ticker if running
        updateUIFromState()
    }
    
    // MARK: - STATE PERSISTENCE
    
    private func updateUIFromState() {
        switch state {
        case .idle(let duration):
            isRunning = false
            initialTime = duration
            timeRemaining = duration
        case .paused(let remaining, let duration):
            isRunning = false
            initialTime = duration
            timeRemaining = remaining
        case .running(let targetEndTime, let duration):
            isRunning = true
            initialTime = duration
            let remaining = targetEndTime.timeIntervalSinceNow
            timeRemaining = max(0, remaining)
            
            if remaining <= 0 {
                // Wait for the UI to fully mount before triggering the gamification
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.completeTimer()
                }
            } else if timer == nil {
                scheduleTimer()
            }
        }
    }
    
    private func saveState() {
        if let encoded = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(encoded, forKey: stateKey)
        }
    }
    
    private func loadState() {
        if let data = UserDefaults.standard.data(forKey: stateKey),
           let decoded = try? JSONDecoder().decode(TimerState.self, from: data) {
            self.state = decoded  // didSet handles saveState() + updateUIFromState()
        }
    }
    
    // MARK: - FORMATTING

    var timeString: String {
        let totalSeconds = Int(ceil(timeRemaining))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
