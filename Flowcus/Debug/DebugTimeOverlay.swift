//
//  DebugTimeOverlay.swift
//  Flowcus
//

#if DEBUG
import SwiftUI

struct DebugTimeOverlay: View {
    @EnvironmentObject private var timerManager: TimeManager
    @ObservedObject private var debugTime = DebugTime.shared
    @State private var position: CGPoint = CGPoint(x: 200, y: 80)
    @State private var collapsed = true
    @State private var showDebugPanel = false

    private var displayDate: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d, h:mm a"
        return fmt.string(from: DebugTime.now)
    }

    private var offsetLabel: String {
        let totalHours = Int(debugTime.offset / 3600)
        if totalHours == 0 { return "Real time" }
        let days = totalHours / 24
        let hours = totalHours % 24
        if days != 0 && hours != 0 { return "\(days)d \(hours)h" }
        if days != 0 { return "\(days)d" }
        return "\(hours)h"
    }

    var body: some View {
        Group {
            if collapsed {
                collapsedView
            } else {
                expandedView
            }
        }
        .position(position)
        .gesture(
            DragGesture()
                .onChanged { value in
                    position = value.location
                }
        )
    }

    private var collapsedView: some View {
        Button {
            withAnimation(.spring(response: 0.3)) { collapsed = false }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "clock.badge.questionmark")
                    .font(.caption2)
                if debugTime.offset != 0 {
                    Text(offsetLabel)
                        .font(.caption2)
                        .fontWeight(.medium)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Capsule().fill(.ultraThinMaterial))
            .overlay(Capsule().stroke(debugTime.offset != 0 ? Color.orange : Color.clear, lineWidth: 1))
        }
    }

    private var expandedView: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Time Travel")
                    .font(.caption)
                    .fontWeight(.bold)
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.3)) { collapsed = true }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(displayDate)
                .font(.caption2)
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                timeButton("-1d") { debugTime.advance(days: -1) }
                timeButton("+1h") { debugTime.advance(hours: 1) }
                timeButton("+1d") { debugTime.advance(days: 1) }
                timeButton("+7d") { debugTime.advance(days: 7) }
            }

            HStack(spacing: 8) {
                if timerManager.isRunning {
                    Button {
                        timerManager.debugComplete()
                    } label: {
                        Text("Skip Timer")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.red))
                    }
                }

                if debugTime.offset != 0 {
                    Button {
                        withAnimation { debugTime.reset() }
                    } label: {
                        Text("Reset")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(.orange)
                    }
                }
            }

            Button {
                showDebugPanel = true
            } label: {
                Text("Test Panel")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.purple))
            }
        }
        .padding(10)
        .frame(width: 200)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.ultraThinMaterial))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.orange.opacity(0.3), lineWidth: 1))
        .sheet(isPresented: $showDebugPanel) {
            DebugPanel()
        }
    }

    private func timeButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.caption2)
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color(.systemGray5)))
        }
    }
}
#endif
