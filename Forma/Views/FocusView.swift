import SwiftUI

struct FocusView: View {
    @State private var total: Int = 5
    @State private var remaining: Int = 5
    @State private var running = false
    @State private var timer: Timer?
    @State private var completedPulse = false
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var store: TaskStore

    var body: some View {
        ZStack {
            Color.formaBackground.ignoresSafeArea()

            VStack(spacing: 24) {
                Text("Focus")
                    .font(.formaTitleL)
                
                if let title = appState.focusTitle, !title.isEmpty {
                    Text(title)
                        .font(.formaBody)
                        .foregroundStyle(Color.formaSubtext)
                }

                ZStack {
                    Circle()
                        .stroke(lineWidth: 16)
                        .foregroundStyle(Color.formaCard.opacity(0.9))
                        .scaleEffect(remaining == 0 ? 1.06 : 1.0)

                    Circle()
                        .trim(from: 0, to: CGFloat(progress))
                        .stroke(style: StrokeStyle(lineWidth: 16, lineCap: .round))
                        .foregroundStyle(Color.formaAccent)
                        .scaleEffect(remaining == 0 ? 1.06 : 1.0)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.2), value: progress)

                    Text(timeString(remaining))
                        .font(.system(size: 40, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.formaText)
                        .scaleEffect(completedPulse ? 1.06 : 1.0)
                        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: completedPulse)
                }
                .frame(width: 240, height: 240)

                HStack(spacing: 16) {
                    Button(running ? "Pause" : "Start") { toggle() }
                        .buttonStyle(.borderedProminent)
                    Button("Reset") { reset() }
                        .buttonStyle(.bordered)
                }

                Spacer()
            }
            .padding()
        }
        .onDisappear { stop() }
    }

    private var progress: Double { 1 - Double(remaining) / Double(total) }

    private func toggle() { running ? stop() : start() }

    private func start() {
        running = true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            remaining = max(remaining - 1, 0)
            if remaining == 0 {
                stop()
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                withAnimation {
                    completedPulse.toggle()
                }
                // Mark the focused task as done (if we have a valid index)
                            if let idx = appState.focusIndex, store.items.indices.contains(idx) {
                                store.items[idx].isDone = true
                            }
                            // Optional: clear focus context
                            appState.focusIndex = nil
                            appState.focusTitle = nil
            }
        }
    }

    private func stop() {
        running = false
        timer?.invalidate()
        timer = nil
    }

    private func reset() {
        stop()
        remaining = total
    }

    private func timeString(_ s: Int) -> String {
        let m = s / 60, ss = s % 60
        return String(format: "%02d:%02d", m, ss)
    }
}
