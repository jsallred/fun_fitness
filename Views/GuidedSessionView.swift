import SwiftUI

struct GuidedSessionView: View {
    @ObservedObject var viewModel: WorkoutViewModel

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            CameraPreviewView(camera: viewModel.cameraService)
                .ignoresSafeArea()

            PoseOverlayView(frame: viewModel.snapshot.poseFrame)
                .ignoresSafeArea()

            VStack(spacing: 10) {
                topCard
                Spacer()
                bottomCard
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            if viewModel.sessionManager.state == .transitioning {
                transitionOverlay
            }
        }
        .onAppear {
            viewModel.startCamera()
        }
        .onDisappear {
            viewModel.stopCamera()
        }
    }

    private var topCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(viewModel.sessionManager.routine?.name ?? "Session")
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()

                Button(action: {
                    viewModel.endRoutine()
                }) {
                    Text("Quit")
                        .fontWeight(.semibold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.85))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }

            if let current = viewModel.sessionManager.currentExercise,
               let routine = viewModel.sessionManager.routine {
                Text("\(current.type.displayName) • \(viewModel.sessionManager.currentExerciseIndex + 1) of \(routine.exercises.count)")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.92))

                Text(current.type.instructions)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.82))
            }
        }
        .padding(12)
        .background(.black.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var bottomCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let current = viewModel.sessionManager.currentExercise {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Reps")
                        .foregroundStyle(.gray)

                    Text("\(viewModel.sessionManager.currentReps) / \(current.targetReps)")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }

            row("Feedback", viewModel.sessionManager.feedback.rawValue)
            row("FPS", fpsText)
            row("Model", viewModel.snapshot.model.displayName)

            if viewModel.sessionManager.state == .completed {
                Text("Routine Complete")
                    .font(.headline)
                    .foregroundStyle(.green)
                    .padding(.top, 6)

                Button(action: {
                    viewModel.endRoutine()
                }) {
                    Text("Back to Home")
                        .fontWeight(.semibold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(Color.blue.opacity(0.9))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.top, 4)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.black.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var transitionOverlay: some View {
        ZStack {
            Color.blue.opacity(0.88)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Text("Exercise Complete")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                if let nextName = viewModel.sessionManager.nextExerciseName {
                    Text("Next: \(nextName)")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.95))
                }
            }
            .padding(24)
        }
        .transition(.opacity)
    }

    private var fpsText: String {
        if viewModel.snapshot.inferenceFPS <= 0 {
            return "--"
        }
        return String(format: "%.1f", viewModel.snapshot.inferenceFPS)
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.gray)

            Spacer()

            Text(value)
                .foregroundStyle(.white)
                .fontWeight(.semibold)
        }
    }
}
