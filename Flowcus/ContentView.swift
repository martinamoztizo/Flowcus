//
//  ContentView.swift
//  Flowcus
//
//  Created by E on 2/3/26.
//

import SwiftUI

// MARK: - APP ENTRY POINT
struct ContentView: View {
    @State private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            TaskListView(switchToFocusTab: { selectedTab = 1 })
                .tabItem {
                    Label("Tasks", systemImage: "checkmark.circle.fill")
                }
                .tag(0)

            FocusTimerView()
                .tabItem {
                    Label("Focus", systemImage: "timer")
                }
                .tag(1)

            JournalView()
                .tabItem {
                    Label("Journal", systemImage: "book.fill")
                }
                .tag(2)
        }
        .tint(.cardinalRed)
    }
}
