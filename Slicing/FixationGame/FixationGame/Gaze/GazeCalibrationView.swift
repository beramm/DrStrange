//
//  GazeCalibrationView.swift
//  Copied from the Whack-a-Mole game (WhackAMoleGame/Views) on the development branch.
//  Setup screen: camera preview, then 9 pulsing circles to look at, one at a time
//  (the same 9-point calibration and look as Whack-a-Mole on development).
//

import DrStrangeGazeTracker
import SwiftUI
import UIKit

/// Pre-game calibration for the custom selected-right-eye tracker.
struct GazeCalibrationView: View {
    let controller: GazeInputController
    let onCalibrated: () -> Void
    let onCancel: () -> Void

    @State private var didComplete = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.white.ignoresSafeArea()

                if let target = controller.activeCalibrationTarget {
                    // Kept away from the screen edges; the game uses the same area.
                    CalibrationFixationTarget()
                        .position(GazeScreenArea.screenPoint(x: target.x, y: target.y, in: geometry.size))
                } else {
                    setupPanel
                }
            }
        }
        // Place the dots across the WHOLE screen, the same area the game uses for the
        // gaze point. Without this, the dots sit inside the safe area (a little smaller
        // than the screen), and the game's gaze point comes out shifted and squashed.
        .ignoresSafeArea()
        .preferredColorScheme(.light)
        .statusBarHidden()
        .onAppear { controller.startCamera() }
        .onChange(of: controller.isCalibrated) { _, calibrated in
            guard calibrated, !didComplete else { return }
            didComplete = true
            onCalibrated()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { controller.resumeForActiveScene() }
            else { controller.pauseForInactiveScene() }
        }
    }

    private var setupPanel: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 36)
            Text("Set up eye control")
                .font(.system(size: 42, weight: .heavy, design: .rounded))
            Text("Use the preview to centre your face. Keep the uncovered eye open and look at the centre of each pulsing circle.")
                .font(.title3)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 680)

            ZStack {
                VolatileGazeCameraPreview(view: controller.cameraPreview)
                if !controller.cameraStarted { Color.black }
            }
            .frame(width: 520, height: 390)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 20))

            Button(controller.isPreparingCalibration ? "Get ready…" : "Start calibration") {
                controller.startCalibration()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!controller.isReadyToCalibrate || controller.isPreparingCalibration)

            Button("Cancel") {
                controller.stop()
                onCancel()
            }
            .buttonStyle(.bordered)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .foregroundStyle(.black)
    }
}

private struct VolatileGazeCameraPreview: UIViewRepresentable {
    let view: UIView

    func makeUIView(context: Context) -> UIView { view }
    func updateUIView(_ uiView: UIView, context: Context) {}
}

private struct CalibrationFixationTarget: View {
    @State private var contracted = false

    var body: some View {
        ZStack {
            Circle().stroke(.black, lineWidth: 5).frame(width: 72, height: 72)
            Circle().fill(.orange).frame(width: 30, height: 30)
                .scaleEffect(contracted ? 0.35 : 1)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: contracted)
        }
        .onAppear { contracted = true }
        .accessibilityHidden(true)
    }
}
