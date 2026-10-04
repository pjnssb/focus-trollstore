import SwiftUI

struct TimerRingView: View {
    let progress: Double
    let remaining: String
    let isRunning: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.15), lineWidth: 18)

            Circle()
                .trim(from: 0, to: max(0.001, min(progress, 1)))
                .stroke(
                    AngularGradient(
                        colors: [Color.accentColor, Color.accentColor.opacity(0.55)],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 18, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.25), value: progress)

            VStack(spacing: 8) {
                Image(systemName: isRunning ? "hourglass" : "timer")
                    .font(.title2)
                    .foregroundStyle(.secondary)

                Text(remaining)
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .monospacedDigit()

                Text(isRunning ? "专注中" : "准备开始")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 260, height: 260)
        .padding(.vertical, 8)
    }
}
