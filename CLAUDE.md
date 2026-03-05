# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Documentation
Use **CLAUDE.md** as the primary reference. Do not read `GEMINI.md` unless explicitly asked.

## Build & Run
Open `Flowcus.xcodeproj` in Xcode and press **Cmd+R**. Pure native iOS — no package managers.

CLI: `xcodebuild -project Flowcus.xcodeproj -scheme Flowcus -sdk iphonesimulator build`

## Architecture

**Flowcus** is an ADHD-friendly iOS productivity app (SwiftUI + SwiftData).

### Navigation — ContentView.swift
Three-tab `TabView` tinted `.cardinalRed`:
1. **Tasks** (`TaskListView`) — Date-linked tasks with swipe-up calendar panel
2. **Focus** (`FocusTimerView`) — Liquid wave Pomodoro timer
3. **Journal** (`JournalView`) — Mood-tracked brain dump entries

### State Management
- **`TimeManager`** (`TimeManager.swift`): `ObservableObject`. Always inject with `@StateObject` in `FocusTimerView` — never `@ObservedObject` (would reset on parent rerender).
- **`TimerState` enum** has three cases: `.idle(duration:)`, `.running(targetEndTime:duration:)`, `.paused(timeRemaining:duration:)`. Timer completion lands in `.paused(timeRemaining: 0, duration:)` — **not** `.idle`. Use `timeRemaining == 0 && !isRunning` to detect completion; `isPaused` returns false at completion because it checks `timeRemaining > 0`.
- **`completionEvents: Int`** (`@Published private(set)`) increments on each session finish. **Not persisted** — resets on app kill. The Pomodoro cycling logic (Focus → Short Break → Long Break after 2 sessions) lives in `FocusTimerView.completeSession()`, not in `TimeManager`.
- **`stopTimer()` in `FocusTimerView`** calls `timerManager.pause()` then `updateTimerForMode()` — there is no "stopped" state; stop = pause + duration reset.
- **`selectedMode`** in `FocusTimerView` is a computed property with a nonmutating setter over `@AppStorage("selectedModeRaw")` — do not replace with a plain `@AppStorage` var or `@State`.
- **AppStorage keys in use**: `workMinutes`, `shortBreakMinutes`, `longBreakMinutes`, `totalXP`, `sessionCount`, `selectedModeRaw`. Do not introduce duplicate keys.

### SwiftData — Critical Warning
`FlowcusApp.swift` handles schema mismatch by **deleting and recreating the entire store** (DEBUG only — Release `fatalError`s). Adding, removing, or renaming `@Model` fields wipes all local data during development.

`DailyTaskList` builds its `@Query` dynamically inside `init(date:)` using `_tasks = Query(filter:sort:)`. This is required for date-based predicate filtering in SwiftData — do not move the query to a property.

### Visual System
- `Color.cardinalRed` is defined in `ColorProfile.swift` as both a `Color` extension and a `ShapeStyle` extension. Do not redefine it elsewhere.
- The **focus wave** uses `Color.red` (not `.cardinalRed`) — intentional. The tab tint and UI accents use `.cardinalRed`. These are different values.
- Tab bar hides only when `timerManager.isRunning` — it reappears when paused.
- `preferredColorScheme(.dark)` is applied when `isSessionActive` (running or paused) to force white status bar icons.

## Key Patterns
- **Subview extraction**: `FocusTimerView` splits into `TimerDisplayView` + `TimerControlsView` for SwiftUI compiler optimization — keep this pattern when adding to that file.
- **Haptics**: `UIImpactFeedbackGenerator` for taps, `UINotificationFeedbackGenerator(.success)` for timer completion.
- **Emoji bar**: `displayEmojis` always places `selectedMood` first; an invisible zero-size `TextField` with `@FocusState` captures the first character typed as the new emoji.
- **Timer presets**: `timerPresets` is a file-level global constant in `SettingsView.swift`. Changing one duration in Settings auto-applies the full matching preset (all 3 durations update together).

## Design Constraints
- Interactive controls belong at the bottom of the screen (reachability).
- Minimal, clean aesthetic — day/night appearance is driven by timer active state, not system setting.
- ADHD-centric: low friction, no guilt mechanics, strong visual feedback.
