//
//  AchievementsView.swift
//  Flowcus
//
//  Full achievements screen with category filters and progress ring.
//

import SwiftUI

struct AchievementsView: View {
    @AppStorage("unlockedMilestones") private var unlockedMilestones: String = ""
    @State private var selectedCategory: MilestoneCategory? = nil
    @State private var animate = false

    private var unlockedSet: Set<String> { RewardSystem.parseUnlocked(unlockedMilestones) }
    private var unlockedCount: Int { unlockedSet.count }
    private var totalCount: Int { RewardSystem.allMilestones.count }

    private var filteredMilestones: [Milestone] {
        let source: [Milestone]
        if let cat = selectedCategory {
            source = RewardSystem.allMilestones.filter { $0.category == cat }
        } else {
            source = RewardSystem.allMilestones
        }
        // Sort: unlocked first, then locked visible (hidden ones excluded until unlocked)
        let unlocked = source.filter { unlockedSet.contains($0.id) }.sorted { $0.xpReward < $1.xpReward }
        let lockedVisible = source.filter { !unlockedSet.contains($0.id) && !$0.isHidden }.sorted { $0.xpReward < $1.xpReward }
        return unlocked + lockedVisible
    }

    private func countFor(_ category: MilestoneCategory) -> (unlocked: Int, total: Int) {
        let all = RewardSystem.allMilestones.filter { $0.category == category }
        let done = all.filter { unlockedSet.contains($0.id) }.count
        return (done, all.count)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.sectionGap) {
                progressRing
                categoryPills
                milestoneGrid
            }
            .padding(.horizontal, Spacing.screenH)
            .padding(.bottom, 100)
        }
        .navigationTitle("Achievements")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if !animate {
                withAnimation { animate = true }
            }
        }
    }

    // MARK: - Progress Ring

    private var progressRing: some View {
        let progress = totalCount > 0 ? Double(unlockedCount) / Double(totalCount) : 0

        return ZStack {
            Circle()
                .stroke(Color(.systemGray5), lineWidth: 6)
            Circle()
                .trim(from: 0, to: animate ? progress : 0)
                .stroke(Color.cardinalRed, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.8).delay(0.2), value: animate)
            VStack(spacing: 2) {
                Text("\(unlockedCount)")
                    .font(.appTitle)
                Text("of \(totalCount)")
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 100, height: 100)
        .padding(.top, Spacing.md)
    }

    // MARK: - Category Filter Pills

    private var categoryPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.inline) {
                // "All" pill
                Button {
                    withAnimation(.appSnappy) { selectedCategory = nil }
                } label: {
                    Text("All \(unlockedCount)/\(totalCount)")
                }
                .buttonStyle(.flowcusPill(isSelected: selectedCategory == nil))

                ForEach(MilestoneCategory.allCases, id: \.self) { cat in
                    let counts = countFor(cat)
                    Button {
                        withAnimation(.appSnappy) { selectedCategory = cat }
                    } label: {
                        Text("\(cat.rawValue) \(counts.unlocked)/\(counts.total)")
                    }
                    .buttonStyle(.flowcusPill(isSelected: selectedCategory == cat))
                }
            }
            .padding(.horizontal, Spacing.xs)
        }
    }

    // MARK: - Milestone Grid

    private var milestoneGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Spacing.listItem) {
            ForEach(Array(filteredMilestones.enumerated()), id: \.element.id) { i, milestone in
                AchievementCardView(
                    milestone: milestone,
                    isUnlocked: unlockedSet.contains(milestone.id),
                    index: i,
                    animate: animate
                )
            }
        }
    }
}

// MARK: - Achievement Card

private struct AchievementCardView: View {
    let milestone: Milestone
    let isUnlocked: Bool
    let index: Int
    let animate: Bool

    private var isRevealed: Bool { isUnlocked || !milestone.isHidden }

    var body: some View {
        VStack(spacing: Spacing.inline) {
            (isRevealed ? milestone.icon : FlowcusIcon.lock)
                .sized(32)
                .foregroundStyle(
                    isUnlocked ? Color.cardinalRed : .gray.opacity(isRevealed ? 0.3 : 0.2)
                )

            Text(isRevealed ? milestone.name : "???")
                .font(.appSubhead)
                .foregroundStyle(isUnlocked ? .primary : .secondary)

            if isRevealed {
                Text(milestone.description)
                    .font(.appCaption)
                    .foregroundStyle(.secondary.opacity(isUnlocked ? 1 : 0.5))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }

            if isUnlocked {
                Text("+\(milestone.xpReward) XP")
                    .font(.appCaption)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.orange.opacity(0.15)))
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, minHeight: 120)
        .background(
            AppShape.md
                .fill(.ultraThinMaterial)
                .opacity(isUnlocked ? 1 : 0.3)
        )
        .opacity(animate ? 1 : 0)
        .offset(y: animate ? 0 : 12)
        .animation(
            .spring(response: 0.4, dampingFraction: 0.75).delay(0.3 + Double(index) * 0.05),
            value: animate
        )
    }
}
