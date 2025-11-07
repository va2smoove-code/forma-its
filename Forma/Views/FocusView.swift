import SwiftUI

struct FocusView: View {
    @State private var total: Int = 25 * 60
    @State private var remaining: Int = 25 * 60
    @State private var running = false
    @State private var timer: Timer?

    var body: some View {
        ZStack {
            Color.formaBackground.ignoresSafeArea()

            VStack(spacing: 24) {
                Text("Focus")
                    .font(.formaTitleL)

                ZStack {
                    Circle()
                        .stroke(lineWidth: 16)
                        .foregroundStyle(Color.formaCard.opacity(0.9))

                    Circle()
                        .trim(from: 0, to: CGFloat(progress))
                        .stroke(style: StrokeStyle(lineWidth: 16, lineCap: .round))
                        .foregroundStyle(Color.formaAccent)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.2), value: progress)

                    Text(timeString(remaining))
                        .font(.system(size: 40, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.formaText)
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
            if remaining == 0 { stop() }
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
