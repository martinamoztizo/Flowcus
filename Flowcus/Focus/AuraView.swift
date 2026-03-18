//
//  AuraView.swift
//  Flowcus
//
//  5th tab: Thermal Core daily visualization + today's stats and wins.
//  Shows "how's my energy today" — complements XPView's all-time progress.
//

import SwiftUI
import SwiftData

// MARK: - Aura View

struct AuraView: View {
    @AppStorage("sessionsToday") private var sessionsToday: Int = 0
    @AppStorage("sessionsTodayDate") private var sessionsTodayDate: String = ""
    @AppStorage("momentumTier") private var momentumTier: Int = 1
    @AppStorage("focusHistory") private var focusHistory: String = ""
    @AppStorage("currentStreak") private var currentStreak: Int = 0

    @Query(filter: #Predicate<TaskItem> { $0.isCompleted })
    private var allCompletedTasks: [TaskItem]

    #if DEBUG
    @ObservedObject private var debugTime = DebugTime.shared
    #endif

    private var todayString: String {
        #if DEBUG
        RewardSystem.dayFormatter.string(from: DebugTime.now)
        #else
        RewardSystem.dayFormatter.string(from: Date())
        #endif
    }

    private var sessions: Int {
        sessionsTodayDate == todayString ? sessionsToday : 0
    }

    private var todayMinutes: Int {
        let history = RewardSystem.parseHistory(focusHistory)
        return history[todayString]?.minutes ?? 0
    }

    private var todayCompletedTasks: [TaskItem] {
        let calendar = Calendar.current
        #if DEBUG
        let today = calendar.startOfDay(for: DebugTime.now)
        #else
        let today = calendar.startOfDay(for: Date())
        #endif
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        return allCompletedTasks.filter { $0.scheduledDate >= today && $0.scheduledDate < tomorrow }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                // Thermal Core hero
                thermalCoreSection

                // Momentum + Streak
                momentumCard

                // Today's Wins
                if !todayCompletedTasks.isEmpty {
                    winsSection
                }
            }
            .padding(.horizontal, Spacing.screenH)
            .padding(.top, Spacing.xl)
            .padding(.bottom, 100)
        }
    }

    // MARK: - Thermal Core

    private var thermalCoreSection: some View {
        VStack(spacing: Spacing.xl) {
            Text("Aura")
                .font(.appTitle3)
                .foregroundStyle(.secondary)

            ThermalCoreView(sessions: sessions, momentumTier: momentumTier)
                .frame(width: 200, height: 200)

            // Stats row
            HStack(spacing: Spacing.sectionGap) {
                statItem(value: "\(todayMinutes)", label: "min")
                statItem(value: "\(sessions)", label: sessions == 1 ? "session" : "sessions")
                statItem(value: "\(todayCompletedTasks.count)", label: todayCompletedTasks.count == 1 ? "task" : "tasks")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.sectionGap)
        .background(
            AppShape.xl
                .fill(.ultraThinMaterial)
        )
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: Spacing.xs) {
            Text(value)
                .font(.appTitle3)
                .monospacedDigit()
            Text(label)
                .font(.appCaption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Momentum Card

    private var momentumCard: some View {
        HStack(spacing: Spacing.listItem) {
            FlowcusIcon.brandFlame.sized(24)
                .foregroundStyle(Color.cardinalRed)

            VStack(alignment: .leading, spacing: 2) {
                Text(RewardSystem.momentumName(for: momentumTier))
                    .font(.appHeadline)
                Text("Tier \(momentumTier)")
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if currentStreak > 0 {
                HStack(spacing: 4) {
                    FlowcusIcon.msSpark.sized(14)
                        .foregroundStyle(.orange)
                    Text("\(currentStreak)d")
                        .font(.appSubhead)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(Spacing.cardInner)
        .background(
            AppShape.lg
                .fill(.ultraThinMaterial)
        )
    }

    // MARK: - Today's Wins

    private var winsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.listItem) {
            Text("Today's Wins")
                .font(.appHeadline)

            VStack(spacing: Spacing.inline) {
                ForEach(todayCompletedTasks, id: \.createdAt) { task in
                    HStack(spacing: 10) {
                        FlowcusIcon.checkboxOn.sized(16)
                            .foregroundStyle(Color.cardinalRed)
                        Text(task.title)
                            .font(.appBody)
                            .lineLimit(1)
                        Spacer()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.cardInner)
        .background(
            AppShape.lg
                .fill(.ultraThinMaterial)
        )
    }
}

// MARK: - Thermal Core View

struct ThermalCoreView: View {
    let sessions: Int
    let momentumTier: Int

    @State private var pulse = false
    @State private var appeared = false

    /// 0.0 to 1.0 — how intense the core is
    private var intensity: Double {
        switch sessions {
        case 0:  return 0.08
        case 1:  return 0.25
        case 2:  return 0.40
        case 3:  return 0.55
        case 4:  return 0.70
        case 5:  return 0.85
        default: return 1.0
        }
    }

    /// Core radius as fraction of the view size
    private var coreRadius: CGFloat {
        0.15 + CGFloat(intensity) * 0.35
    }

    /// Outer glow radius based on momentum
    private var glowRadius: CGFloat {
        CGFloat(momentumTier) * 6 + CGFloat(intensity) * 10
    }

    /// Center color — shifts from warm orange to white-hot
    private var centerColor: Color {
        if intensity > 0.8 { return .white }
        if intensity > 0.5 { return Color(red: 1.0, green: 0.85, blue: 0.6) }
        return Color(red: 1.0, green: 0.7, blue: 0.4)
    }

    /// Middle color — always in the red/orange range
    private var midColor: Color {
        Color.cardinalRed.opacity(0.4 + intensity * 0.6)
    }

    /// Edge glow color
    private var edgeColor: Color {
        Color.orange.opacity(0.1 + intensity * 0.2)
    }

    var body: some View {
        ZStack {
            // Outer ambient glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [edgeColor, .clear],
                        center: .center,
                        startRadius: 30,
                        endRadius: 100
                    )
                )

            // Main thermal core
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            centerColor.opacity(intensity),
                            midColor,
                            edgeColor,
                            .clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 80 * coreRadius / 0.5
                    )
                )
                .shadow(color: Color.cardinalRed.opacity(intensity * 0.6), radius: glowRadius)

            // Inner bright spot
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            centerColor.opacity(intensity * 0.9),
                            .clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 30
                    )
                )
        }
        .scaleEffect(appeared ? (pulse ? 1.03 : 0.97) : 0.8)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.appSmooth) {
                appeared = true
            }
            withAnimation(
                .easeInOut(duration: 2.5)
                .repeatForever(autoreverses: true)
            ) {
                pulse = true
            }
        }
    }
}
