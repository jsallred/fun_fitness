import Foundation

struct GuidedRoutineProgress: Equatable {
    var currentExerciseIndex: Int = 0
    var currentReps: Int = 0
    var feedback: ExerciseFeedback = .ready
    var isComplete: Bool = false
}

struct DemoCounters: Equatable {
    var squats: Int = 0
    var jumpingJacks: Int = 0
}

struct TrackedPersonExerciseState: Equatable {
    var demoCounters = DemoCounters()
    var guidedProgress = GuidedRoutineProgress()

    var lastDetectedActivity: ActivityType = .unknown
    var currentExerciseName: String?
    var currentExerciseTarget: Int?

    var hudSubtitle: String {
        if let currentExerciseName {
            if let target = currentExerciseTarget, target > 0 {
                return "\(currentExerciseName): \(guidedProgress.currentReps)/\(target)"
            } else {
                return currentExerciseName
            }
        }

        if demoCounters.squats > 0 || demoCounters.jumpingJacks > 0 {
            return "Squats \(demoCounters.squats) • Jacks \(demoCounters.jumpingJacks)"
        }

        return "Waiting"
    }
}

final class TrackedPersonExerciseEngine {
    private let demoTracker = ExerciseTracker()
    private let guidedTracker = ShoulderRoutineTracker()

    func reset() {
        demoTracker.reset()
        guidedTracker.reset()
    }

    func updateDemo(points: [PosePoint], timestampMs: Int, state: inout TrackedPersonExerciseState) {
        demoTracker.update(points: points, nowMs: timestampMs)
        state.demoCounters.squats = demoTracker.squat.reps
        state.demoCounters.jumpingJacks = demoTracker.jack.reps
        state.lastDetectedActivity = demoTracker.activity
    }

    func updateGuided(
        points: [PosePoint],
        exercise: RehabExercise,
        progress: inout GuidedRoutineProgress
    ) {
        let result = guidedTracker.update(for: exercise.type, points: points)
        progress.currentReps = result.reps
        progress.feedback = result.feedback

        if let target = exercise.targetReps, result.reps >= target {
            progress.currentReps = target
        }
    }
}

