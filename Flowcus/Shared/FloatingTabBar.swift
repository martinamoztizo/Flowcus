//
//  FloatingTabBar.swift
//  Flowcus
//

import SwiftUI

struct FloatingTabBar: View {
    @Binding var selectedTab: Int
    let isVisible: Bool

    @Namespace private var tabNamespace

    private let tabs: [(icon: String, label: String, tag: Int)] = [
        ("checkmark.circle.fill", "Tasks", 0),
        ("timer", "Focus", 1),
        ("book.fill", "Journal", 2),
        ("flame.fill", "XP", 3)
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.tag) { tab in
                Button {
                    Haptics.impact(.light)
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        selectedTab = tab.tag
                    }
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 20, weight: .medium))
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
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
        )
        .padding(.horizontal, 32)
        .offset(y: isVisible ? 0 : 100)
        .opacity(isVisible ? 1 : 0)
        .animation(.easeInOut(duration: 0.3), value: isVisible)
    }
}
