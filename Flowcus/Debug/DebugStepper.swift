//
//  DebugStepper.swift
//  Flowcus
//
//  Guided step-by-step flow tester. Walks through multi-step workflows
//  one tap at a time via a floating overlay. Each tap executes one action
//  so you can inspect transitions, animations, and state at your own pace.
//
//  To remove: delete this file + remove the DebugStepperOverlay overlay in ContentView.

#if DEBUG
import SwiftUI
import SwiftData
import Combine

// MARK: - Step Model

struct DebugStep {
    let name: String
    let hint: String
    let action: (DebugStepContext) -> Void
}

struct DebugStepContext {
    let modelContext: ModelContext
    let timerManager: TimeManager
}

// MARK: - Stepper Engine

class DebugStepper: ObservableObject {
    static let shared = DebugStepper()

    @Published var isActive = false
    @Published var currentIndex = 0
    @Published var sequenceName = ""

    private(set) var steps: [DebugStep] = []

    var currentStep: DebugStep? {
        guard isActive, currentIndex < steps.count else { return nil }
        return steps[currentIndex]
    }

    var isLastStep: Bool { currentIndex + 1 >= steps.count }

    func start(name: String, steps: [DebugStep]) {
        self.sequenceName = name
        self.steps = steps
        self.currentIndex = 0
        self.isActive = true
    }

    func advance(context: DebugStepContext) {
        guard let step = currentStep else { return }
        step.action(context)
        if isLastStep {
            isActive = false
        } else {
            currentIndex += 1
        }
    }

    func stop() {
        isActive = false
        steps = []
        currentIndex = 0
        sequenceName = ""
    }
}

// MARK: - Predefined Sequences

enum DebugSequences {

    static let all: [(name: String, description: String, steps: [DebugStep])] = [
        ("Full Focus Flow",  "Task → Timer → Complete → Reward → Mood", fullFocusFlow),
        ("Milestone Storm",  "Trigger 3+ milestones in one session",    milestoneStorm),
        ("Level Up",         "Position XP then trigger level-up",       levelUpFlow),
        ("Runway Clear",     "Complete a full runway for bonus XP",     runwayClearFlow),
        ("3-Day Streak",     "Multi-day sim via time travel",           multiDayStreak),
    ]

    // MARK: Full Focus Flow

    static let fullFocusFlow: [DebugStep] = [
        DebugStep(name: "Seed Task", hint: "Creates a test task for today") { ctx in
            let task = TaskItem(title: "Debug: Ship the feature")
            task.runwayTier = .medium; task.runwayOrder = 0
            ctx.modelContext.insert(task)
            try? ctx.modelContext.save()
        },
        DebugStep(name: "Set Active Task", hint: "Picks seeded task as focus target") { ctx in
            let desc = FetchDescriptor<TaskItem>(
                predicate: #Predicate { $0.title == "Debug: Ship the feature" },
                sortBy: [SortDescriptor(\TaskItem.createdAt, order: .reverse)]
            )
            if let task = try? ctx.modelContext.fetch(desc).first {
                UserDefaults.standard.set(
                    String(task.createdAt.timeIntervalSinceReferenceDate),
                    forKey: "activeTaskID"
                )
            }
        },
        DebugStep(name: "Start 1-Min Timer", hint: "Starts a short timer — use Skip Timer to complete") { ctx in
            ctx.timerManager.setDuration(minutes: 1)
            ctx.timerManager.start()
        },
        DebugStep(name: "Complete Timer", hint: "Triggers completion → reward card") { ctx in
            ctx.timerManager.debugComplete()
        },
        DebugStep(name: "Check Reward Card", hint: "Reward card should be showing — dismiss it") { _ in
            // Observational: user inspects and dismisses
        },
        DebugStep(name: "Check Mood Prompt", hint: "Mood prompt should appear — pick an emoji") { _ in
            // Observational: user interacts
        },
        DebugStep(name: "Verify Journal", hint: "Switch to Journal tab — check auto-created entry") { _ in
            // Observational: user checks
        },
    ]

    // MARK: Milestone Storm

    static let milestoneStorm: [DebugStep] = [
        DebugStep(name: "Setup State", hint: "Clears milestones, sets stats near thresholds") { _ in
            DebugActions.setupMilestoneStorm()
        },
        DebugStep(name: "Seed + Activate Task", hint: "Creates and sets a focus target") { ctx in
            let task = TaskItem(title: "Debug: Milestone trigger")
            ctx.modelContext.insert(task)
            try? ctx.modelContext.save()
            UserDefaults.standard.set(
                String(task.createdAt.timeIntervalSinceReferenceDate),
                forKey: "activeTaskID"
            )
        },
        DebugStep(name: "Start & Complete", hint: "Quick session — milestones should fire") { ctx in
            ctx.timerManager.setDuration(minutes: 1)
            ctx.timerManager.start()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                ctx.timerManager.debugComplete()
            }
        },
        DebugStep(name: "Verify Milestones", hint: "Reward card should show 3+ milestone badges") { _ in },
    ]

    // MARK: Level Up

    static let levelUpFlow: [DebugStep] = [
        DebugStep(name: "Position XP", hint: "Sets XP to 5 below next level") { _ in
            DebugActions.setupNextLevelUp()
        },
        DebugStep(name: "Seed + Activate Task", hint: "Creates and sets a focus target") { ctx in
            let task = TaskItem(title: "Debug: Level-up trigger")
            ctx.modelContext.insert(task)
            try? ctx.modelContext.save()
            UserDefaults.standard.set(
                String(task.createdAt.timeIntervalSinceReferenceDate),
                forKey: "activeTaskID"
            )
        },
        DebugStep(name: "Start & Complete", hint: "Session should trigger level-up") { ctx in
            ctx.timerManager.setDuration(minutes: 1)
            ctx.timerManager.start()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                ctx.timerManager.debugComplete()
            }
        },
        DebugStep(name: "Verify Level Up", hint: "Reward card should show level-up celebration") { _ in },
    ]

    // MARK: Runway Clear

    static let runwayClearFlow: [DebugStep] = [
        DebugStep(name: "Seed Full Runway", hint: "All tasks done except one small") { ctx in
            DebugActions.setupFullRunwayDay(context: ctx.modelContext)
        },
        DebugStep(name: "Set Last Task Active", hint: "Picks the remaining incomplete task") { ctx in
            let calendar = Calendar.current
            let start = calendar.startOfDay(for: DebugTime.now)
            let end = calendar.date(byAdding: .day, value: 1, to: start)!
            let desc = FetchDescriptor<TaskItem>(predicate: #Predicate {
                $0.scheduledDate >= start && $0.scheduledDate < end && !$0.isCompleted
            })
            if let task = try? ctx.modelContext.fetch(desc).first {
                UserDefaults.standard.set(
                    String(task.createdAt.timeIntervalSinceReferenceDate),
                    forKey: "activeTaskID"
                )
            }
        },
        DebugStep(name: "Start & Complete", hint: "Should trigger runway clear bonuses") { ctx in
            ctx.timerManager.setDuration(minutes: 1)
            ctx.timerManager.start()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                ctx.timerManager.debugComplete()
            }
        },
        DebugStep(name: "Verify Bonuses", hint: "Reward card should show tier + full runway XP") { _ in },
    ]

    // MARK: 3-Day Streak

    static let multiDayStreak: [DebugStep] = [
        DebugStep(name: "Reset & Seed Day 1", hint: "Fresh state + task for day 1") { ctx in
            DebugActions.resetAllAppStorage()
            DebugActions.wipeAllTasks(context: ctx.modelContext)
            DebugTime.shared.reset()
            let task = TaskItem(title: "Debug: Day 1 task")
            ctx.modelContext.insert(task)
            try? ctx.modelContext.save()
            UserDefaults.standard.set(
                String(task.createdAt.timeIntervalSinceReferenceDate),
                forKey: "activeTaskID"
            )
        },
        DebugStep(name: "Complete Day 1", hint: "First session — streak starts") { ctx in
            ctx.timerManager.setDuration(minutes: 1)
            ctx.timerManager.start()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                ctx.timerManager.debugComplete()
            }
        },
        DebugStep(name: "Dismiss Day 1", hint: "Dismiss reward card + mood prompt") { _ in },
        DebugStep(name: "Travel to Day 2", hint: "Advance time by 1 day") { _ in
            DebugTime.shared.advance(days: 1)
        },
        DebugStep(name: "Day 2 Session", hint: "New task + quick session") { ctx in
            let task = TaskItem(title: "Debug: Day 2 task")
            ctx.modelContext.insert(task)
            try? ctx.modelContext.save()
            UserDefaults.standard.set(
                String(task.createdAt.timeIntervalSinceReferenceDate),
                forKey: "activeTaskID"
            )
            ctx.timerManager.setDuration(minutes: 1)
            ctx.timerManager.start()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                ctx.timerManager.debugComplete()
            }
        },
        DebugStep(name: "Dismiss Day 2", hint: "Streak should be 2 — dismiss cards") { _ in },
        DebugStep(name: "Travel to Day 3", hint: "Advance time by 1 day") { _ in
            DebugTime.shared.advance(days: 1)
        },
        DebugStep(name: "Day 3 Session", hint: "Should trigger 3-day Spark milestone") { ctx in
            let task = TaskItem(title: "Debug: Day 3 task")
            ctx.modelContext.insert(task)
            try? ctx.modelContext.save()
            UserDefaults.standard.set(
                String(task.createdAt.timeIntervalSinceReferenceDate),
                forKey: "activeTaskID"
            )
            ctx.timerManager.setDuration(minutes: 1)
            ctx.timerManager.start()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                ctx.timerManager.debugComplete()
            }
        },
        DebugStep(name: "Verify Streak", hint: "Reward card should show Spark milestone (3-day streak)") { _ in },
    ]
}

// MARK: - Stepper Overlay

struct DebugStepperOverlay: View {
    @ObservedObject private var stepper = DebugStepper.shared
    @EnvironmentObject private var timerManager: TimeManager
    @Environment(\.modelContext) private var modelContext

    @State private var position = CGPoint(x: 200, y: 160)

    var body: some View {
        if stepper.isActive, let step = stepper.currentStep {
            stepCard(step)
                .position(position)
                .gesture(DragGesture().onChanged { position = $0.location })
        }
    }

    private func stepCard(_ step: DebugStep) -> some View {
        VStack(spacing: 6) {
            // Header
            HStack {
                Text("\(stepper.currentIndex + 1)/\(stepper.steps.count)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(stepper.sequenceName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Button { stepper.stop() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Step info
            Text(step.name)
                .font(.caption)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(step.hint)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Action button
            Button {
                let ctx = DebugStepContext(modelContext: modelContext, timerManager: timerManager)
                stepper.advance(context: ctx)
                Haptics.impact(.light)
            } label: {
                Text(stepper.isLastStep ? "Finish" : "Next Step")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.green))
            }
        }
        .padding(10)
        .frame(width: 200)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.ultraThinMaterial))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.green.opacity(0.4), lineWidth: 1))
    }
}
#endif
