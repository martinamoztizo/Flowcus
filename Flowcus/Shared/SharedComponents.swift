//
//  SharedComponents.swift
//  Flowcus
//
//  Reusable UI components shared across TaskList, EisenhowerMatrix, and RunwayView.
//

import SwiftUI

// MARK: - Haptics

enum Haptics {
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private static let notification = UINotificationFeedbackGenerator()

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator: UIImpactFeedbackGenerator
        switch style {
        case .light: generator = light
        case .medium: generator = medium
        case .heavy: generator = heavy
        default: generator = medium
        }
        generator.prepare()
        generator.impactOccurred()
    }

    static func success() {
        notification.prepare()
        notification.notificationOccurred(.success)
    }
}

// MARK: - Spacing

enum Spacing {
    // Scale
    static let xs:   CGFloat = 4
    static let sm:   CGFloat = 8
    static let md:   CGFloat = 12
    static let lg:   CGFloat = 16
    static let xl:   CGFloat = 20
    static let xxl:  CGFloat = 24
    static let xxxl: CGFloat = 32

    // Semantic
    static let screenH:    CGFloat = xl    // screen horizontal margin
    static let cardInner:  CGFloat = lg    // padding inside cards
    static let listItem:   CGFloat = md    // gap between list items
    static let sectionGap: CGFloat = xxl   // gap between sections
    static let inline:     CGFloat = sm    // icon-to-label, small gaps
    static let tabBarH:    CGFloat = xxxl  // tab bar horizontal padding
}

// MARK: - Corner Radii

enum AppShape {
    static let sm = RoundedRectangle(cornerRadius: 8, style: .continuous)   // chips, badges, text fields
    static let md = RoundedRectangle(cornerRadius: 12, style: .continuous)  // cards, rows, containers
    static let lg = RoundedRectangle(cornerRadius: 16, style: .continuous)  // sections, larger surfaces
    static let xl = RoundedRectangle(cornerRadius: 20, style: .continuous)  // hero elements, primary buttons
}

// MARK: - Animation

// USAGE:
//   .appSnappy  — small/fast: checkbox, tab switch, picker, emoji tap
//   .appSmooth  — medium: cards, sheets, calendar drag, reward card
//   .appWave    — liquid fill only (intentionally slow)

extension Animation {
    static let appSnappy = Animation.spring(response: 0.3, dampingFraction: 0.8)
    static let appSmooth = Animation.spring(response: 0.5, dampingFraction: 0.8)
    static let appWave   = Animation.spring(response: 2.0, dampingFraction: 1.0)
}

// MARK: - Button Styles

struct FlowcusPillButtonStyle: ButtonStyle {
    var isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.appCaption)
            .fontWeight(.medium)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(isSelected ? AnyShapeStyle(Color.cardinalRed) : AnyShapeStyle(.ultraThinMaterial))
            )
            .foregroundStyle(isSelected ? .white : .secondary)
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

extension ButtonStyle where Self == FlowcusPillButtonStyle {
    static func flowcusPill(isSelected: Bool) -> FlowcusPillButtonStyle {
        FlowcusPillButtonStyle(isSelected: isSelected)
    }
}

// MARK: - Animated Checkbox

struct AnimatedCheckbox: View {
    let isCompleted: Bool
    var checkedIcon: String = "checkmark.circle.fill"
    var uncheckedIcon: String = "circle"
    var font: Font = .body
    var checkedColor: Color = .green
    var uncheckedColor: Color = .gray
    let onToggle: () -> Void

    @State private var checkScale: CGFloat = 1.0

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                checkScale = 1.3
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                    checkScale = 1.0
                }
            }
            onToggle()
        } label: {
            Image(systemName: isCompleted ? checkedIcon : uncheckedIcon)
                .font(font)
                .foregroundStyle(isCompleted ? checkedColor : uncheckedColor)
                .scaleEffect(checkScale)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - XP Pill

struct XPPillView: View {
    let totalXP: Int
    let momentumTier: Int
    let onTap: () -> Void

    private var flameSize: CGFloat { CGFloat(10 + min(momentumTier, 5)) }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.system(size: flameSize))
                    .foregroundStyle(
                        LinearGradient(colors: [.orange, .cardinalRed],
                                       startPoint: .bottom, endPoint: .top)
                    )

                Text("\(totalXP)")
                    .font(.appCaption)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Capsule().fill(.ultraThinMaterial))
            .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Inline Editable Text

struct InlineEditableText: View {
    let text: String
    let font: Font
    var fontWeight: Font.Weight? = nil
    var isCompleted: Bool = false
    var completedColor: Color = .gray
    var lineLimit: Int? = nil
    let onCommit: (String) -> Void

    @State private var isEditing = false
    @State private var editText = ""
    @FocusState private var editFocused: Bool

    var body: some View {
        if isEditing {
            TextField("Task name", text: $editText)
                .font(font)
                .fontWeight(fontWeight)
                .focused($editFocused)
                .submitLabel(.done)
                .onSubmit { commitEdit() }
                .onChange(of: editFocused) { _, focused in
                    if !focused { commitEdit() }
                }
        } else {
            Text(text)
                .font(font)
                .fontWeight(fontWeight)
                .strikethrough(isCompleted)
                .foregroundStyle(isCompleted ? completedColor : .primary)
                .lineLimit(lineLimit)
                .onTapGesture { startEditing() }
        }
    }

    private func startEditing() {
        editText = text
        isEditing = true
        editFocused = true
    }

    private func commitEdit() {
        let trimmed = editText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { onCommit(trimmed) }
        isEditing = false
    }
}
