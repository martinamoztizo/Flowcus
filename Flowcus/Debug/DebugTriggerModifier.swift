//
//  DebugTriggerModifier.swift
//  Flowcus
//
//  ViewModifier that bridges DebugTrigger → FocusTimerView state.
//  Keeps all debug onChange logic in one place for easy removal:
//    1. Delete Flowcus/Debug/ folder
//    2. Delete the #if DEBUG .modifier(...) block in FocusTimer.swift
//    3. Delete the #if DEBUG overlay block in ContentView.swift
//

#if DEBUG
import SwiftUI

/// Gate that skips DebugTriggerModifier when debug is disabled.
struct DebugTriggerGate: ViewModifier {
    let enabled: Bool
    @Binding var showRewardCard: Bool
    @Binding var rewardCardData: RewardCardData?
    @Binding var showMiniRewardCard: Bool
    @Binding var miniRewardXP: Int
    @Binding var miniRewardLevel: LevelInfo

    func body(content: Content) -> some View {
        if enabled {
            content.modifier(DebugTriggerModifier(
                showRewardCard: $showRewardCard,
                rewardCardData: $rewardCardData,
                showMiniRewardCard: $showMiniRewardCard,
                miniRewardXP: $miniRewardXP,
                miniRewardLevel: $miniRewardLevel
            ))
        } else {
            content
        }
    }
}

struct DebugTriggerModifier: ViewModifier {
    @ObservedObject private var debugTrigger = DebugTrigger.shared
    @EnvironmentObject private var timerManager: TimeManager

    @Binding var showRewardCard: Bool
    @Binding var rewardCardData: RewardCardData?
    @Binding var showMiniRewardCard: Bool
    @Binding var miniRewardXP: Int
    @Binding var miniRewardLevel: LevelInfo

    func body(content: Content) -> some View {
        content
            .onChange(of: debugTrigger.rewardCardTrigger) { _, _ in
                guard let card = debugTrigger.pendingRewardCard else { return }
                rewardCardData = card
                showRewardCard = true
                debugTrigger.pendingRewardCard = nil
            }
            .onChange(of: debugTrigger.pendingMiniReward) { _, reward in
                guard let reward else { return }
                miniRewardXP = reward.xp
                miniRewardLevel = reward.level
                showMiniRewardCard = true
                debugTrigger.pendingMiniReward = nil
            }
            .onChange(of: debugTrigger.triggerCompletion) { _, fire in
                guard fire else { return }
                debugTrigger.triggerCompletion = false
                if !timerManager.isRunning {
                    timerManager.setDuration(minutes: 1)
                    timerManager.start()
                }
                // Delay so the timer is actually running before we complete it
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    timerManager.debugComplete()
                }
            }
    }
}
#endif
