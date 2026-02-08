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
