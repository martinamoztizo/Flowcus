//
//  DebugTrigger.swift
//  Flowcus
//
//  ObservableObject singleton that bridges the debug panel to FocusTimerView's
//  private @State properties (reward cards, mini cards, timer completion).
//

#if DEBUG
import SwiftUI
import Combine

struct MiniRewardData: Equatable {
    let xp: Int
    let level: LevelInfo

    static func == (lhs: MiniRewardData, rhs: MiniRewardData) -> Bool {
        lhs.xp == rhs.xp && lhs.level.level == rhs.level.level
    }
}

class DebugTrigger: ObservableObject {
    static let shared = DebugTrigger()

    /// Set to show a full reward card preview in FocusTimerView.
    /// Store the card here and bump the counter to trigger onChange.
    var pendingRewardCard: RewardCardData? = nil
    @Published var rewardCardTrigger: Int = 0

    /// Set to show a mini break reward card.
    @Published var pendingMiniReward: MiniRewardData? = nil

    /// Toggle to fire a real timer completion via debugComplete().
    @Published var triggerCompletion: Bool = false
}
#endif
