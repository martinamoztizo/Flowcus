//
//  DebugTime.swift
//  Flowcus
//

#if DEBUG
import SwiftUI
import Combine

/// Time-travel helper for testing date-dependent features (streaks, momentum, milestones, scheduling).
///
/// USE `DebugTime.now` for: "What date/day is it?" — calendar lookups, day strings, date comparisons.
/// NEVER use for: interval timing, countdowns, or anything later compared to real `Date()` / `timeIntervalSinceNow`.
/// Timer countdowns must always use `Date()` directly — the offset breaks interval math.
class DebugTime: ObservableObject {
    static let shared = DebugTime()
    @Published var offset: TimeInterval = 0

    /// Returns `Date()` shifted by the debug offset. Only for date-based lookups, NOT interval timing.
    static var now: Date { Date().addingTimeInterval(shared.offset) }

    func advance(days: Int) { offset += Double(days) * 86400 }
    func advance(hours: Int) { offset += Double(hours) * 3600 }
    func reset() { offset = 0 }
}
#endif
