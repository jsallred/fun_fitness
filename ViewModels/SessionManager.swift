import Foundation
import Combine

@MainActor
final class SessionManager: ObservableObject {
    @Published private(set) var routine: RehabRoutine?
    @Published private(set) var currentExerciseIndex: Int = 0
    @Published private(set) var currentReps: Int = 0
    @Published private(set) var feedback: ExerciseFeedback = .ready
    @Published private(set) var state: SessionState = .idle
    @Published private(set) var nextExerciseName: String?

    private var isAdvancing = false

    func start(routine: RehabRoutine) {
        self.routine = routine
        self.currentExerciseIndex = 0
        self.currentReps = 0
        self.feedback = .ready
        self.nextExerciseName = nil
        self.state = .active
        self.isAdvancing = false
    }

    func endSession() {
        routine = nil
        currentExerciseIndex = 0
        currentReps = 0
        feedback = .ready
        nextExerciseName = nil
        state = .idle
        isAdvancing = false
    }

    var currentExercise: RehabExercise? {
        guard let routine, currentExerciseIndex < routine.exercises.count else { return nil }
        return routine.exercises[currentExerciseIndex]
    }

    func updateProgress(reps: Int, feedback: ExerciseFeedback) {
        guard state == .active, let exercise = currentExercise else { return }

        currentReps = min(reps, exercise.targetReps)
        self.feedback = feedback

        if currentReps >= exercise.targetReps && !isAdvancing {
            completeCurrentExercise()
        }
    }

    private func completeCurrentExercise() {
        guard let routine else { return }

        if currentExerciseIndex < routine.exercises.count - 1 {
            isAdvancing = true
            state = .transitioning
            feedback = .complete
            nextExerciseName = routine.exercises[currentExerciseIndex + 1].type.displayName

            Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                await MainActor.run {
                    self.currentExerciseIndex += 1
                    self.currentReps = 0
                    self.feedback = .ready
                    self.nextExerciseName = nil
                    self.state = .active
                    self.isAdvancing = false
                }
            }
        } else {
            feedback = .complete
            state = .completed
        }
    }
}
