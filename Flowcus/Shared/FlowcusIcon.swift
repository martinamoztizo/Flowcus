//
//  FlowcusIcon.swift
//  Flowcus
//
//  Custom icon system. Each case maps to an SVG asset in Assets.xcassets/Icons/.
//  Uses template rendering so SwiftUI tints them automatically.
//

import SwiftUI

enum FlowcusIcon: String, CaseIterable {
    // Tab Bar
    case tabTasks = "fc-tab-tasks"
    case tabFocus = "fc-tab-focus"
    case tabJournal = "fc-tab-journal"
    case tabXP = "fc-tab-xp"
    case tabAura = "fc-tab-aura"

    // Brand
    case brandFlame = "fc-brand-flame"
    case brandMomentum = "fc-brand-momentum"

    // Checkboxes
    case checkboxOn = "fc-status-checkbox-on"
    case checkboxOff = "fc-status-checkbox-off"

    // Status
    case completeSeal = "fc-status-complete-seal"
    case checklist = "fc-status-checklist"
    case done = "fc-status-done"
    case lock = "fc-status-lock"

    // Runway Tiers
    case tierBig = "fc-tier-big"
    case tierMedium = "fc-tier-medium"
    case tierSmall = "fc-tier-small"
    case tierNone = "fc-tier-none"

    // Task View Modes
    case modeList = "fc-mode-list"
    case modeMatrix = "fc-mode-matrix"
    case modeRunway = "fc-mode-runway"

    // Actions
    case actionSettings = "fc-action-settings"
    case actionPlay = "fc-action-play"
    case actionPlayCircle = "fc-action-play-circle"

    // Milestones
    case msSparkles = "fc-ms-sparkles"
    case msBolt = "fc-ms-bolt"
    case msShield = "fc-ms-shield"
    case msWaves = "fc-ms-waves"
    case msRunway = "fc-ms-runway"
    case msStar = "fc-ms-star"
    case msMoon = "fc-ms-moon"
    case msSunrise = "fc-ms-sunrise"
    case msTriple = "fc-ms-triple"
    case msComeback = "fc-ms-comeback"
    case msMarathon = "fc-ms-marathon"
    case msCheckmark = "fc-ms-checkmark"
    case msDiary = "fc-ms-diary"
    case msTomato = "fc-ms-tomato"
    case msZen = "fc-ms-zen"
    case msTimeLord = "fc-ms-time-lord"
    case msLevelUp = "fc-ms-level-up"
    case msExpert = "fc-ms-expert"
    case msGrandMaster = "fc-ms-grand-master"
    case msSpark = "fc-ms-spark"
    case msOnFire = "fc-ms-on-fire"
    case msKindling = "fc-ms-kindling"
    case msBlazing = "fc-ms-blazing"
    case msWildfire = "fc-ms-wildfire"
    case msInferno = "fc-ms-inferno"
    case msEternalFlame = "fc-ms-eternal-flame"
    case msTaskMaster = "fc-ms-task-master"
    case msTaskinator = "fc-ms-taskinator"
    case msTenADay = "fc-ms-ten-a-day"
    case msWeekend = "fc-ms-weekend"
    case msDeepBreath = "fc-ms-deep-breath"

    // Stats
    case statClock = "fc-stat-clock"
    case statSessions = "fc-stat-sessions"
    case statToday = "fc-stat-today"

    // Misc
    case ghostCarryover = "fc-misc-ghost-carryover"
    case compose = "fc-misc-compose"

    /// Returns the image loaded from the asset catalog with template rendering.
    var image: Image {
        Image(rawValue, bundle: nil).renderingMode(.template)
    }

    /// Returns a resizable, template-rendered image at the given point size.
    func sized(_ size: CGFloat) -> some View {
        image
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
    }

    // Named size presets
    static let captionSize: CGFloat = 12
    static let bodySize: CGFloat = 17
    static let titleSize: CGFloat = 28
    static let heroSize: CGFloat = 48
}
