import SwiftUI

struct AudioWaveformBars: View {
    let audioLevel: Float
    let isRecording: Bool

    private let barCount = 4
    private let barScales: [Float] = [0.6, 1.0, 0.8, 0.5]
    private let minBarHeight: CGFloat = 0.2
    private let maxBarHeight: CGFloat = 16

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(isRecording ? AppTheme.accent : Color.secondary.opacity(0.3))
                    .frame(
                        width: 3,
                        height: barHeight(for: index)
                    )
                    .animation(
                        .easeInOut(duration: 0.08),
                        value: audioLevel
                    )
            }
        }
        .frame(width: 20, height: maxBarHeight)
    }

    private func barHeight(for index: Int) -> CGFloat {
        if !isRecording {
            return maxBarHeight * minBarHeight * CGFloat(barScales[index])
        }

        let scale = CGFloat(barScales[index])
        let level = CGFloat(audioLevel)
        let height = max(minBarHeight, level * scale) * maxBarHeight
        return min(height, maxBarHeight)
    }
}
