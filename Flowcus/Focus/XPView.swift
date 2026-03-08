//
//  XPView.swift
//  Flowcus
//
//  4th tab: Level hero, momentum card, stats row, milestone gallery.
//

import SwiftUI

struct XPView: View {
    @AppStorage("totalXP") private var totalXP = 0
    @AppStorage("momentumTier") private var momentumTier: Int = 0
    @AppStorage("lastSessionTimestamp") private var lastSessionTimestamp: Double = 0
    @AppStorage("sessionsToday") private var sessionsToday: Int = 0
    @AppStorage("sessionsTodayDate") private var sessionsTodayDate: String = ""
    @AppStorage("unlockedMilestones") private var unlockedMilestones: String = ""
    @AppStorage("totalFocusMinutes") private var totalFocusMinutes: Int = 0
    @AppStorage("totalFocusSessions") private var totalFocusSessions: Int = 0

    @State private var animate = false
    @State private var flamePulse = false

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private var levelInfo: LevelInfo { RewardSystem.levelInfo(for: totalXP) }
    private var unlockedSet: Set<String> { RewardSystem.parseUnlocked(unlockedMilestones) }
    private var todaySessions: Int {
        sessionsTodayDate == Self.dayFormatter.string(from: Date()) ? sessionsToday : 0
    }

    private var momentumDescription: String {
        switch momentumTier {
        case 1: return "Keep going — momentum builds with each session"
        case 2: return "Nice rhythm — your focus is picking up"
        case 3: return "Solid flow — you're in a groove"
        case 4: return "On fire — your consistency is paying off"
        case 5: return "Unstoppable — peak momentum achieved"
        default: return "Complete a session to start building momentum"
        }
    }

    private var sortedMilestones: [Milestone] {
        let unlocked = RewardSystem.allMilestones.filter { unlockedSet.contains($0.id) }
            .sorted { $0.name < $1.name }
        let lockedVisible = RewardSystem.allMilestones.filter { !unlockedSet.contains($0.id) && !$0.isHidden }
            .sorted { $0.name < $1.name }
        let lockedHidden = RewardSystem.allMilestones.filter { !unlockedSet.contains($0.id) && $0.isHidden }
        return unlocked + lockedVisible + lockedHidden
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    levelSection
                    momentumSection
                    statsSection
                    milestonesSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 100)
            }
            .navigationTitle("Progress")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if !animate { animate = true }
            }
        }
    }

    // MARK: - Level Hero

    private var levelSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "flame.fill")
                .font(.system(size: 44))
                .foregroundStyle(
                    LinearGradient(colors: [.orange, .cardinalRed], startPoint: .top, endPoint: .bottom)
                )
                .scaleEffect(animate ? 1 : 0.8)
                .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.1), value: animate)

            Text(levelInfo.name)
                .font(.appTitle)

            Text("Level \(levelInfo.level)")
                .font(.appSubhead)
                .foregroundStyle(.secondary)

            LevelBarView(info: levelInfo, animate: animate, delay: 0.3)
                .padding(.horizontal, 20)

            Text("\(totalXP) total XP")
                .font(.appCaption)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 20)
    }

    // MARK: - Momentum Card

    private var momentumSection: some View {
        HStack(spacing: 16) {
            Image(systemName: "flame.fill")
                .font(.system(size: CGFloat(12 + momentumTier * 2)))
                .foregroundStyle(momentumTier >= 3
                    ? AnyShapeStyle(LinearGradient(colors: [.orange, .cardinalRed], startPoint: .leading, endPoint: .trailing))
                    : AnyShapeStyle(Color.orange.opacity(0.4 + Double(momentumTier) * 0.1))
                )
                .opacity(momentumTier >= 3 ? (flamePulse ? 1 : 0.7) : 1)
                .animation(momentumTier >= 3 ? .easeInOut(duration: 1.2).repeatForever(autoreverses: true) : .default, value: flamePulse)
                .onAppear { flamePulse = true }

            VStack(alignment: .leading, spacing: 4) {
                Text(momentumTier > 0 ? RewardSystem.momentumName(for: momentumTier) : "No Momentum")
                    .font(.appHeadline)
                Text(momentumDescription)
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.ultraThinMaterial))
    }

    // MARK: - Stats Row

    private var statsSection: some View {
        HStack {
            StatItem(value: "\(totalFocusMinutes)", label: "Minutes", icon: "clock.fill")
            Divider().frame(height: 40)
            StatItem(value: "\(totalFocusSessions)", label: "Sessions", icon: "flame.fill")
            Divider().frame(height: 40)
            StatItem(value: "\(todaySessions)", label: "Today", icon: "sun.max.fill")
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.ultraThinMaterial))
    }

    // MARK: - Milestone Gallery

    private var milestonesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Milestones").font(.appHeadline)
                Spacer()
                Text("\(unlockedSet.count)/\(RewardSystem.allMilestones.count)")
                    .font(.appCaption).foregroundStyle(.secondary)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(Array(sortedMilestones.enumerated()), id: \.element.id) { i, milestone in
                    MilestoneCardView(
                        milestone: milestone,
                        isUnlocked: unlockedSet.contains(milestone.id),
                        index: i,
                        animate: animate
                    )
                }
            }
        }
    }
}

// MARK: - Stat Item

private struct StatItem: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.appTitle3)
            Text(label)
                .font(.appCaption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Milestone Card

private struct MilestoneCardView: View {
    let milestone: Milestone
    let isUnlocked: Bool
    let index: Int
    let animate: Bool

    private var isRevealed: Bool { isUnlocked || !milestone.isHidden }

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: isRevealed ? milestone.sfSymbol : "lock.fill")
                .font(.system(size: 28))
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
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.orange.opacity(0.15)))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 120)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
                .opacity(isUnlocked ? 1 : 0.3)
        )
        .opacity(animate ? 1 : 0)
        .offset(y: animate ? 0 : 12)
        .animation(
            .spring(response: 0.4, dampingFraction: 0.75).delay(0.5 + Double(index) * 0.08),
            value: animate
        )
    }
}
