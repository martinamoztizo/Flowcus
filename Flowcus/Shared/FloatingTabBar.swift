//
//  FloatingTabBar.swift
//  Flowcus
//

import SwiftUI

struct FloatingTabBar: View {
    @Binding var selectedTab: Int
    let isVisible: Bool

    @Namespace private var tabNamespace

    private let tabs: [(icon: FlowcusIcon, label: String, tag: Int)] = [
        (.tabTasks, "Tasks", 0),
        (.tabFocus, "Focus", 1),
        (.tabJournal, "Journal", 2),
        (.tabAura, "Aura", 3)
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.tag) { tab in
                Button {
                    Haptics.impact(.light)
                    withAnimation(.appSnappy) {
                        selectedTab = tab.tag
                    }
                } label: {
                    VStack(spacing: 6) {
                        tab.icon.sized(20)
                            .foregroundStyle(
                                selectedTab == tab.tag
                                    ? Color.cardinalRed
                                    : Color.secondary
                            )
                            .shadow(
                                color: selectedTab == tab.tag
                                    ? Color.cardinalRed.opacity(0.5) : .clear,
                                radius: 8
                            )

                        if selectedTab == tab.tag {
                            Capsule()
                                .fill(Color.cardinalRed)
                                .frame(width: 24, height: 3)
                                .matchedGeometryEffect(id: "indicator", in: tabNamespace)
                        } else {
                            Color.clear
                                .frame(width: 24, height: 3)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .accessibilityLabel(tab.label)
            }
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.vertical, Spacing.md)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
        )
        .padding(.horizontal, Spacing.tabBarH)
        .offset(y: isVisible ? 0 : 100)
        .opacity(isVisible ? 1 : 0)
        .animation(.appSnappy, value: isVisible)
    }
}
