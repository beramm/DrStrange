import SwiftUI

/// Quick check that the red/cyan glasses separate the two eyes on this screen.
/// It is a setup aid only, not a vision test.
struct GlassesCheckView: View {
    let therapy: TherapyConfiguration

    @Environment(\.dismiss) private var dismiss

    private var renderer: AnaglyphRenderer {
        AnaglyphRenderer(glasses: therapy.glasses, backgroundLevel: therapy.anaglyphBackgroundLevel)
    }

    var body: some View {
        VStack(spacing: 32) {
            Text("Put the glasses on, then cover one eye at a time.")
                .font(.title2.weight(.semibold))

            HStack(spacing: 64) {
                shapeColumn(eye: .left) { Circle() }
                shapeColumn(eye: .right) { Rectangle() }
            }

            Text("With the right eye covered you should see only the circle. With the left eye covered, only the square. A faint copy of the other shape means some light leaks through the filters (crosstalk); try the other filter side or a different pair of glasses.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 640)

            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .tint(WhackAMolePalette.accent)
                .controlSize(.large)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(renderer.background.ignoresSafeArea())
    }

    private func shapeColumn<S: Shape>(eye: Eye, @ViewBuilder shape: () -> S) -> some View {
        VStack(spacing: 16) {
            shape()
                .fill(renderer.ink(for: .only(eye), standardColor: .black, contrast: 1))
                .frame(width: 180, height: 180)
                .eyeLayer(renderer)
            Text(eye.title)
                .font(.headline)
        }
    }
}
