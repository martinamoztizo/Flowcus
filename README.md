# Flowcus

An aesthetic ADHD productivity app focused on "flow state" visualization.

## Core Features
- **Liquid Timer:** A custom-shaped sine wave timer that "drains" as time passes.
- **Dynamic Themes:** 
  - `Focus`: Energetic Red
  - `Short Break`: Calming Teal
  - `Long Break`: Refreshing Mint
- **Gamification:** XP system awarded for completed focus sessions.
- **Brain Dump:** A simple journal and task list for mental clarity.

## Technical Architecture
- **Language:** Swift / SwiftUI
- **Persistence:** SwiftData (Tasks & Journal), AppStorage (Settings), UserDefaults (XP)
- **Animation:** `TimelineView` for continuous wave rendering and `GeometryReader` for screen-filling liquid logic.

## Project History
- **2026-02-05:** Completed v1.0 of the Liquid Timer and dynamic status bar logic.
- **2026-02-06:** Established session recovery and automated documentation protocols.
