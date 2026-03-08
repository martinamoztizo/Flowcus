//
//  ContentView.swift
//  Flowcus
//
//  Created by E on 2/3/26.
//

import SwiftUI

// MARK: - APP ENTRY POINT
struct ContentView: View {
    @StateObject private var timerManager = TimeManager()
    @State private var selectedTab: Int = 0
    @State private var calendarProgress: Double = 0
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("momentumTier") private var momentumTier: Int = 0
    @AppStorage("lastSessionTimestamp") private var lastSessionTimestamp: Double = 0
    @AppStorage("totalXP") private var totalXP: Int = 0

    /// Only apply calendar fade to tab bar when Tasks tab is active
    private var tabBarCalendarEffect: Double {
        selectedTab == 0 ? calendarProgress : 0
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // All tabs stay alive so TimeManager and view state persist across switches
            ZStack {
                TaskListView(switchToFocusTab: { selectedTab = 1 }, calendarRevealProgress: $calendarProgress)
                    .opacity(selectedTab == 0 ? 1 : 0)
                    .allowsHitTesting(selectedTab == 0)

                FocusTimerView()
                    .opacity(selectedTab == 1 ? 1 : 0)
                    .allowsHitTesting(selectedTab == 1)

                JournalView()
                    .opacity(selectedTab == 2 ? 1 : 0)
                    .allowsHitTesting(selectedTab == 2)

                XPView()
                    .opacity(selectedTab == 3 ? 1 : 0)
                    .allowsHitTesting(selectedTab == 3)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            FloatingTabBar(selectedTab: $selectedTab, isVisible: !timerManager.isRunning)
                .opacity(1.0 - tabBarCalendarEffect)
                .offset(y: tabBarCalendarEffect * 60)
                .padding(.bottom, 20)

            // XP pill — top-left, always compact
            VStack {
                HStack {
                    XPPillView(totalXP: totalXP, momentumTier: max(momentumTier, 1)) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            selectedTab = 3
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                Spacer()
            }
            .opacity(selectedTab != 3 && !timerManager.isRunning ? 1 : 0)
            .animation(.easeInOut(duration: 0.3), value: selectedTab != 3 && !timerManager.isRunning)
        }
        .environmentObject(timerManager)
        .ignoresSafeArea(.keyboard)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                timerManager.appMovedToForeground()
                let decayed = RewardSystem.decayedMomentumTier(current: momentumTier, lastSessionTimestamp: lastSessionTimestamp)
                if decayed != momentumTier { momentumTier = decayed }
            }
            if newPhase == .background { timerManager.appMovedToBackground() }
        }
        .onChange(of: timerManager.completionEvents) { _, _ in
            // Switch to Focus tab so the user sees the completion UI
            if selectedTab != 1 { selectedTab = 1 }
        }
    }
}
