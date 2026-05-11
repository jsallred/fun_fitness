import SwiftUI

struct GuidedSessionView: View {
    @ObservedObject var viewModel: WorkoutViewModel

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            CameraPreviewView(camera: viewModel.cameraService)
                .ignoresSafeArea()

            PoseOverlayView(
                trackedPeople: viewModel.snapshot.trackedPeople,
                showHUDs: viewModel.settings.showPersonHUDs,
                showIDs: viewModel.settings.showPersonIDs,
                highlightTentativeTracks: viewModel.settings.highlightTentativeTracks
            )
            .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.black.opacity(0.55),
                    Color.clear,
                    Color.black.opacity(0.65)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
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

            if viewModel.sessionManager.state == .quitting {
                quittingOverlay
            }
        }
        .sheet(isPresented: $viewModel.isShowingSettings) {
            SettingsView(
                settings: viewModel.settings,
                selectedModel: $viewModel.selectedModel
            )
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
                    viewModel.openSettings()
                }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(Color.white.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                Button(action: {
                    viewModel.beginQuitRoutine(message: "Returning to Home Screen")
                }) {
                    Text("Quit")
                        .fontWeight(.semibold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.88))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }

            if viewModel.isDemoRoutineActive {
                Text("Live demo mode")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.92))

                Text("Your skeleton turns red to green based on how well your full body is visible. Reps only count when you are green and ready.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.82))
            } else if let current = viewModel.sessionManager.currentExercise,
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
        .background(.black.opacity(0.42))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var bottomCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            readinessSummary

            if viewModel.isDemoRoutineActive {
                demoSummary
            } else if let current = viewModel.sessionManager.currentExercise,
                      let target = current.targetReps {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Best visible progress")
                        .foregroundStyle(.gray)

                    Text("\(viewModel.sessionManager.currentReps) / \(target)")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }

            row("People visible", "\(viewModel.snapshot.trackedPeople.count)")
            row("Ready people", "\(viewModel.snapshot.trackedPeople.filter(\.isReadyForExercise).count)")
            row("FPS", fpsText)
            row("Model", viewModel.snapshot.model.displayName)

            if !viewModel.isDemoRoutineActive {
                row("Feedback", viewModel.sessionManager.feedback.rawValue)

                if viewModel.sessionManager.state == .completed {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Routine Complete")
                            .font(.headline)
                            .foregroundStyle(.green)

                        Button(action: {
                            viewModel.beginQuitRoutine(message: "Returning to Home Screen")
                        }) {
                            Text("Back to Home")
                                .fontWeight(.semibold)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity)
                                .background(Color.blue.opacity(0.92))
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.black.opacity(0.42))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var readinessSummary: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Tracking quality")
                .font(.headline)
                .foregroundStyle(.white)

            if viewModel.snapshot.trackedPeople.isEmpty {
                Text("Step fully into the camera frame until your skeleton turns green.")
                    .foregroundStyle(.white.opacity(0.82))
                    .font(.subheadline)
            } else if viewModel.snapshot.trackedPeople.contains(where: \.isReadyForExercise) {
                Text("Green people are ready and their reps can be counted.")
                    .foregroundStyle(.green)
                    .font(.subheadline.weight(.semibold))
            } else {
                Text("Move farther into frame until your skeleton becomes green.")
                    .foregroundStyle(.orange)
                    .font(.subheadline.weight(.semibold))
            }
        }
    }

    private var demoSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tracked People")
                .font(.headline)
                .foregroundStyle(.white)

            if viewModel.snapshot.trackedPeople.isEmpty {
                Text("No people tracked yet")
                    .foregroundStyle(.white.opacity(0.78))
            } else {
                ForEach(Array(viewModel.snapshot.trackedPeople.enumerated()), id: \.element.id) { index, person in
                    HStack {
                        Text(viewModel.settings.showPersonIDs ? person.displayName : "Person \(index + 1)")
                            .foregroundStyle(.white)
                            .fontWeight(.semibold)

                        Spacer()

                        Text(person.isReadyForExercise ? "Ready" : "Not ready")
                            .foregroundStyle(person.isReadyForExercise ? .green : .orange)

                        Text("•")
                            .foregroundStyle(.white.opacity(0.55))

                        Text("Squats \(person.exerciseState.demoCounters.squats)")
                            .foregroundStyle(.white.opacity(0.86))

                        Text("•")
                            .foregroundStyle(.white.opacity(0.55))

                        Text("Jacks \(person.exerciseState.demoCounters.jumpingJacks)")
                            .foregroundStyle(.white.opacity(0.86))
                    }
                    .font(.subheadline)
                }
            }
        }
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
    }

    private var quittingOverlay: some View {
        ZStack {
            Color.orange.opacity(0.90)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Text("Ending Session")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(viewModel.sessionManager.quitMessage ?? "Returning to Home Screen")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.95))
            }
            .padding(24)
        }
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
