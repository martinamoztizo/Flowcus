//
//  Typography.swift
//  Flowcus
//
//  Inter — clean geometric sans-serif with Light (300) weight for a thin,
//  airy feel. Light for reading text, Regular for labels, Medium for emphasis.
//  All fonts use relativeTo: for Dynamic Type scaling.
//  Exception: timer countdown stays SF Pro Rounded (see FocusTimer.swift).
//

import SwiftUI

extension Font {
    private static let light   = "Inter-Light"
    private static let regular = "Inter-Regular"
    private static let medium  = "Inter-Medium"

    // Body & reading — thin/light for a clean, open feel
    static let appBody      = Font.custom(light,   size: 17, relativeTo: .body)
    static let appSubhead   = Font.custom(light,   size: 15, relativeTo: .subheadline)
    static let appCaption   = Font.custom(regular, size: 12, relativeTo: .caption)
    static let appCaption2  = Font.custom(regular, size: 11, relativeTo: .caption2)

    // Emphasis / labels — regular and medium for hierarchy
    static let appHeadline  = Font.custom(medium,  size: 17, relativeTo: .headline)
    static let appTitle3    = Font.custom(medium,  size: 20, relativeTo: .title3)
    static let appTitle2    = Font.custom(medium,  size: 22, relativeTo: .title2)
    static let appTitle     = Font.custom(medium,  size: 28, relativeTo: .title)

    // Large display (variable size)
    static func appDisplay(size: CGFloat) -> Font {
        Font.custom(medium, size: size)
    }

    // WEIGHT RULES — use these consistently across the app:
    //
    // .bold      → primary titles, hero text        (appTitle, appTitle2)
    // .semibold  → section headers, button labels   (appTitle3, appHeadline)
    // .medium    → secondary labels, metadata        (appSubhead, appBody)
    // (none)     → reading text, captions            (appBody, appCaption, appCaption2)
    //
    // Exceptions:
    //   Timer countdown — SF Pro Rounded (FocusTimer.swift)
    //   Emojis — system font at explicit size
    //   Heat map labels — system font at 8pt
}
