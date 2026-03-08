//
//  RewardCardView.swift
//  Flowcus
//
//  Post-session celebration UI. Shows XP breakdown with staggered animations,
//  level bar, milestone badges, and optional level-up fanfare.
//

import SwiftUI

// MARK: - Data

struct RewardCardData {
    let taskName: String?
    let durationMinutes: Int
    let reward: RewardResult
    let milestones: [Milestone]
    let levelBefore: LevelInfo
    let levelAfter: LevelInfo
    let didLevelUp: Bool
}

// MARK: - Reward Card View

struct RewardCardView: View {
    let data: RewardCardData
    let onContinue: () -> Void

    @State private var animate = false

    private var lines: [RewardLine] { data.reward.lines }
    private var totalDelay: Double { Double(lines.count) * 0.3 + 0.2 }
    private var levelBarDelay: Double { totalDelay + 0.3 }
    private var levelUpDelay: Double { levelBarDelay + 0.5 }

    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 4) {
                Text("Session Complete")
                    .font(.appTitle2)

                Group {
                    if let name = data.taskName {
                        Text("\(name) - \(data.durationMinutes) min")
                    } else {
                        Text("\(data.durationMinutes) min session")
                    }
                }
                .font(.appSubhead)
                .foregroundStyle(.secondary)
            }
            .padding(.top, 8)

            // Line items
            VStack(spacing: 8) {
                ForEach(Array(lines.enumerated()), id: \.offset) { i, line in
                    lineRow(line, index: i)
                }

                Divider()

                // Total
                HStack {
                    Text("Total")
                        .font(.appHeadline)
                    Spacer()
                    Text("+\(data.reward.totalXP) XP")
                        .font(.appHeadline)
                        .foregroundStyle(Color.cardinalRed)
                }
                .opacity(animate ? 1 : 0)
                .offset(y: animate ? 0 : 8)
                .animation(.spring(response: 0.4, dampingFraction: 0.75).delay(totalDelay), value: animate)
                .modifier(HapticOnAppear(delay: totalDelay, style: .success))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
            )

            // Level bar
            LevelBarView(info: data.levelAfter, animate: animate, delay: levelBarDelay)

            // Milestone badges
            if !data.milestones.isEmpty {
                HStack(spacing: 12) {
                    ForEach(data.milestones) { milestone in
                        VStack(spacing: 4) {
                            Image(systemName: milestone.sfSymbol)
                                .font(.title2)
                                .foregroundStyle(Color.cardinalRed)
                            Text(milestone.name)
                                .font(.appCaption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .opacity(animate ? 1 : 0)
                .animation(.spring(response: 0.4, dampingFraction: 0.75).delay(levelBarDelay + 0.2), value: animate)
            }

            // Level up
            if data.didLevelUp {
                VStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.title)
                        .foregroundStyle(.orange)
                    Text("LEVEL UP")
                        .font(.appHeadline)
                        .foregroundStyle(Color.cardinalRed)
                    Text(data.levelAfter.name)
                        .font(.appTitle3)
                }
                .scaleEffect(animate ? 1 : 0.5)
                .opacity(animate ? 1 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(levelUpDelay), value: animate)
            }

            Spacer()

            // Continue button
            Button("Continue") { onContinue() }
                .font(.appHeadline)
                .foregroundStyle(Color.cardinalRed)
                .padding(.bottom, 8)
        }
        .padding(.horizontal, 20)
        .onAppear { animate = true }
        .task {
            try? await Task.sleep(for: .seconds(5))
            onContinue()
        }
    }

    @ViewBuilder
    private func lineRow(_ line: RewardLine, index: Int) -> some View {
        let delay = Double(index) * 0.3
        let isCritical = line.label == "Critical Focus!"

        HStack {
            Text(line.label)
                .font(.appBody)
            Spacer()
            Text("+\(line.xp) XP")
                .font(.appBody)
                .foregroundStyle(line.isBonus ? .orange : Color.cardinalRed)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, isCritical ? 8 : 0)
        .background(
            isCritical
                ? RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.cardinalRed.opacity(0.2))
                : nil
        )
        .opacity(animate ? 1 : 0)
        .offset(y: animate ? 0 : 8)
        .animation(.spring(response: 0.4, dampingFraction: 0.75).delay(delay), value: animate)
        .modifier(HapticOnAppear(delay: delay, style: isCritical ? .heavy : .light))
    }
}

// MARK: - Level Bar

struct LevelBarView: View {
    let info: LevelInfo
    let animate: Bool
    let delay: Double

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Lv \(info.level) - \(info.name)")
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(info.currentXP)/\(info.neededXP) XP")
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                Capsule()
                    .fill(Color.gray.opacity(0.2))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(LinearGradient(colors: [.cardinalRed, .orange], startPoint: .leading, endPoint: .trailing))
                            .frame(width: animate ? geo.size.width * fillFraction : 0)
                            .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(delay), value: animate)
                    }
                    .clipShape(Capsule())
            }
            .frame(height: 6)
        }
    }

    private var fillFraction: CGFloat {
        guard info.neededXP > 0 else { return 1 }
        return CGFloat(info.currentXP) / CGFloat(info.neededXP)
    }
}

// MARK: - Haptic Modifier

private struct HapticOnAppear: ViewModifier {
    let delay: Double
    let style: HapticStyle

    enum HapticStyle { case light, heavy, success }

    func body(content: Content) -> some View {
        content.task {
            try? await Task.sleep(for: .seconds(delay))
            switch style {
            case .light: Haptics.impact(.light)
            case .heavy: Haptics.impact(.heavy)
            case .success: Haptics.success()
            }
        }
    }
}

// MARK: - Mini Reward Card View

struct MiniRewardCardView: View {
    let xp: Int
    let levelInfo: LevelInfo
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Break Complete")
                .font(.appTitle3)

            Text("+\(xp) XP")
                .font(.appTitle2)
                .foregroundStyle(Color.cardinalRed)

            LevelBarView(info: levelInfo, animate: true, delay: 0.2)
        }
        .padding(24)
        .task {
            try? await Task.sleep(for: .seconds(2))
            onDismiss()
        }
    }
}
