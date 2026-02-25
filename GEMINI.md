# Flowcus - Project Context

## Project Overview
**Flowcus** is an aesthetic ADHD productivity iOS application built with **SwiftUI**. It focuses on "flow state" visualization using a liquid timer animation and incorporates gamification elements like XP.

### Core Features
1.  **Liquid Focus Timer:**
    -   Visualizes time as a draining liquid using a custom Sine Wave shape.
    -   **Dynamic Themes:** Cardinal Red (Focus), Teal (Short Break), Mint (Long Break).
    -   **Animation:** Uses `TimelineView` for continuous, smooth wave motion.
    -   **Status Bar:** Logic dynamically switches icon colors (Black/White) based on the liquid level to ensure visibility.
    -   **Smart Breaks:** Automatically triggers a Long Break after 2 completed Focus sessions.
2.  **Task Management (To-Do):**
    -   **Calendar Integration:** Tasks are linked to specific dates (`scheduledDate`).
    -   **Reachability UI:** Floating Action Button (FAB) at the bottom-left opens a swipe-up calendar sheet.
    -   **Unified Sliding Panel:** Combines the date display and calendar into a single interactive sheet.
3.  **Journaling (Brain Dump):**
    -   Supports mood tracking and text entries.
    -   **Editable Titles:** "New Entry" placeholder allows direct in-place editing.
4.  **Gamification:**
    -   XP system stored in `UserDefaults`.
    -   XP awarded upon session completion.

## Architecture & Technologies
-   **Language:** Swift 5+
-   **UI Framework:** SwiftUI
-   **Persistence:** `SwiftData` (`TaskItem`, `JournalEntry`)
    -   Includes auto-migration logic in `FlowcusApp.swift` to handle schema changes by resetting the store if needed during development.
-   **State Management:** `ObservableObject` (`TimerManager` in `TimeManager.swift`) and SwiftUI `@State`/`@Binding`.
-   **Configuration:** `AppStorage` used for persistent user settings (Timer durations).

## Key Files
-   **`Flowcus/FlowcusApp.swift`**: Application entry point. Sets up the `ModelContainer` for SwiftData.
-   **`Flowcus/ContentView.swift`**: The main hub containing the `TabView` navigation.
-   **`Flowcus/FocusTimer.swift`**: Implementation of `FocusTimerView`, custom `Wave` shape, and timer settings.
-   **`Flowcus/TaskList.swift`**: Implementation of `TaskListView` including the unified calendar and task lists.
-   **`Flowcus/Journal.swift`**: Implementation of `JournalView`, editable entries, and mood helpers.
-   **`Flowcus/ColorProfile.swift`**: Centralized shared color definitions (e.g., `cardinalRed`).
-   **`Flowcus/TimeManager.swift`**: `TimeManager` class logic for countdown timer, state management, and background/foreground transitions.
-   **`Flowcus/Models.swift`**: SwiftData model definitions.

## Development Workflow
-   **Building:** Open `Flowcus.xcodeproj` in Xcode and press **Run (Cmd+R)**.
-   **Version Control:** The project uses Git. `Flowcus/` is the sole source of truth. Use standard commits to save state and branches to experiment with new features, instead of manual archive folders.
-   **Design Philosophy:**
    -   **Aesthetic:** Clean, minimal, "Day/Night" mode shifts based on timer state.
    -   **Reachability:** Critical interactive elements (like the Calendar toggle) should be easily accessible (bottom of screen).
    -   **ADHD-Centric:** Low friction, visual feedback, guilt-free mechanics.
