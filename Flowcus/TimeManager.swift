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

class TimeManager: ObservableObject {
    // These @Published markers are CRITICAL. They tell the UI to update.
    static let minDurationMinutes = 1
    static let maxDurationMinutes = 1440

    @Published var timeRemaining: TimeInterval = 25 * 60
    @Published var initialTime: TimeInterval = 25 * 60
    @Published var isRunning: Bool = false
    @Published private(set) var completionEvents: Int = 0
    
    var timer: Timer?
    var lastBackgroundDate: Date?

    deinit {
        timer?.invalidate()
    }
    
    // Function to set custom minutes (The feature you requested)
    func setDuration(minutes: Int) {
        pause()
        // Validation: Clamp between 1 minute and 24 hours (1440 mins)
        let clampedMinutes = min(max(minutes, Self.minDurationMinutes), Self.maxDurationMinutes)
        let newTime = TimeInterval(clampedMinutes * 60)
        timeRemaining = newTime
        initialTime = newTime
    }
    
    func start() {
        guard !isRunning else { return }
        isRunning = true
        scheduleTimer()
    }
    
    func pause() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    private func scheduleTimer() {
        timer?.invalidate()
        let newTimer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
    }
    
    private func tick() {
        guard timeRemaining > 0 else {
            completeTimer()
            return
        }

        timeRemaining = max(0, timeRemaining - 1)

        if timeRemaining <= 0 {
            completeTimer()
        }
    }
    
    private func completeTimer() {
        pause()
        completionEvents += 1
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    // Background handling logic
    func appMovedToBackground() {
        if isRunning {
            lastBackgroundDate = Date()
            timer?.invalidate()
            timer = nil
        }
    }
    
    func appMovedToForeground() {
        if isRunning, let backgroundDate = lastBackgroundDate {
            let timePassed = Date().timeIntervalSince(backgroundDate)
            timeRemaining = max(0, timeRemaining - timePassed)
            if timeRemaining <= 0 {
                completeTimer()
            } else {
                scheduleTimer()
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
