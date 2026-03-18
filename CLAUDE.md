# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build

Open `Flowcus.xcodeproj` in Xcode and press **Cmd+R**. No CLI build tool. No automated tests.

## Editing Rules

**Scope discipline** — Only modify files and lines directly related to the current task. Do not refactor, restyle, "clean up," or "improve" unrelated code. If a file must be touched, change only the specific lines the task requires. If a change to unrelated code seems necessary, explain why and ask for permission before proceeding.

## Critical Patterns

**Tab layout** — All 4 tabs live simultaneously in a ZStack (not a TabView switch). Visibility is `.opacity()` + `.allowsHitTesting()`. This preserves `TimeManager` state.

**TimeManager** — `@StateObject` in `ContentView`, passed as `@EnvironmentObject` everywhere. `@MainActor` class. `import Combine` is required even though it looks unused.

**Timer completion** — Detect via `.onChange(of: timerManager.completionEvents)`. The completed state is `.paused(timeRemaining: 0, duration:)`, not `.idle`.

**Persistence split** — SwiftData for `TaskItem` and `JournalEntry`. `@AppStorage` for everything XP/stats/timer-related. Adding SwiftData fields with default values (e.g., `= 0`) won't wipe the store.

**Enums** — All use `String` raw values. Computed properties (`runwayTier`, `quadrant`) unwrap stored strings back to enums — always go through these, never the raw fields.

**Custom icons** — `FlowcusIcon` enum in `FlowcusIcon.swift`. Use `.image` / `.sized(CGFloat)`. Context menu `Label`s need the closure form: `Label { Text("…") } icon: { icon.sized(17) }`. SF Symbols still used for `plus`, `xmark`, `chevron.*`, `trash`, `arrow.*`, `clock`, `circle`.

**`DailyTaskList`** — builds `@Query` inside `init(date:)`. This is intentional and required for SwiftData date filtering.

**XP logic** — `RewardSystem.swift` is pure logic, no SwiftUI. All XP writes go through a single AppStorage write at the end of `completeSession()` in `FocusTimer.swift`.
