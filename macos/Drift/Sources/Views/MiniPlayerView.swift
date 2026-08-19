import SwiftUI

// MARK: - Mini Player View (200 x 72 pt compact floating timer)

struct MiniPlayerView: View {
    @ObservedObject var viewModel: StudyViewModel
    let onDismiss: () -> Void

    // Ring geometry
    private let ringSize: CGFloat = 32
    private let ringStroke: CGFloat = 3

    var body: some View {
        ZStack(alignment: .bottom) {
            // --- Card background ---
            Rectangle()
                .fill(Color.driftPanel)
                .overlay(
                    Rectangle().strokeBorder(Color.accent.opacity(0.72), lineWidth: 2)
                )

            // --- Content row ---
            HStack(spacing: Space.md) {
                // Progress ring with timer centred
                ZStack {
                    // Track
                    Rectangle()
                        .stroke(Color.accent.opacity(0.15), lineWidth: ringStroke)
                        .frame(width: ringSize, height: ringSize)

                    // Progress arc
                    Rectangle()
                        .trim(from: 0, to: viewModel.progress)
                        .stroke(
                            viewModel.ringColor,
                            style: StrokeStyle(lineWidth: ringStroke, lineCap: .round)
                        )
                        .frame(width: ringSize, height: ringSize)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.8), value: viewModel.progress)

                    // Centred time value
                    Text(formattedTime)
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.primary)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                        .contentTransition(.numericText())
                        .animation(Anim.count, value: viewModel.timeRemaining)
                }
                .frame(width: ringSize, height: ringSize)

                // Info column
                VStack(alignment: .leading, spacing: 1) {
                    Text(timerLabel)
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)
                        .contentTransition(.numericText())
                        .animation(Anim.count, value: viewModel.timeRemaining)

                    Text(subtitleLabel)
                        .font(.system(size: 9, weight: .regular, design: .default))
                        .foregroundStyle(Color.secondary)
                        .tracking(2)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                // Dismiss button
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.secondary)
                        .frame(width: 18, height: 18)
                        .background(
                            Rectangle()
                                .fill(Color.primary.opacity(0.07))
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close mini player")
            }
            .padding(.horizontal, Space.md)
            .padding(.vertical, Space.sm)

            // --- Bottom progress bar (thin accent capsule) ---
            GeometryReader { geo in
                Rectangle()
                    .fill(viewModel.ringColor)
                    .frame(
                        width: geo.size.width * viewModel.progress,
                        height: 2
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .animation(.linear(duration: 0.8), value: viewModel.progress)
                    .clipShape(
                        RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                    )
            }
            .frame(height: 2)
            // Inset from edges to sit just inside the card border
            .padding(.horizontal, Radius.xl * 0.5)
            .padding(.bottom, Radius.xl * 0.5 - 1)
        }
        .frame(width: 200, height: 72)
        // `.contain` (not `.ignore`) so the Close button stays reachable by
        // VoiceOver; the timer text is summarized as a labelled child group.
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityDescription)
    }

    // MARK: - Computed strings

    private var formattedTime: String {
        String(format: "%d:%02d", viewModel.timeRemaining / 60, viewModel.timeRemaining % 60)
    }

    private var timerLabel: String {
        formattedTime
    }

    private var subtitleLabel: String {
        "\(viewModel.modeLabel.uppercased()) \u{2022} \(viewModel.focusPercent)%"
    }

    private var accessibilityDescription: String {
        "\(viewModel.modeLabel) timer. \(viewModel.timeRemaining / 60) minutes and \(viewModel.timeRemaining % 60) seconds remaining. \(viewModel.focusPercent)% focus."
    }
}
