//
//  ColorProfile.swift
//  Flowcus
//

import SwiftUI

// MARK: - COLORS
extension Color {
    static let cardinalRed = Color(red: 0.768, green: 0.118, blue: 0.227)
}

extension ShapeStyle where Self == Color {
    static var cardinalRed: Color { .cardinalRed }
}
