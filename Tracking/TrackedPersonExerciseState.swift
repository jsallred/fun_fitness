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
    var bicepCurls: Int = 0
}

struct DemoRepFlashTimes: Equatable {
    var squats: Int = 0
    var jumpingJacks: Int = 0
    var bicepCurls: Int = 0
}

struct TrackedPersonExerciseState: Equatable {
    var demoCounters = DemoCounters()
    var demoDebugInfo = DemoExerciseDebugInfo()
    var demoRepFlashTimes = DemoRepFlashTimes()
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

        return "Squats \(demoCounters.squats) • Jacks \(demoCounters.jumpingJacks) • Curls \(demoCounters.bicepCurls)"
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
        let oldCounters = state.demoCounters

        demoTracker.update(points: points, nowMs: timestampMs)

        state.demoCounters.squats = demoTracker.squat.reps
        state.demoCounters.jumpingJacks = demoTracker.jack.reps
        state.demoCounters.bicepCurls = demoTracker.curl.reps
        state.demoDebugInfo = demoTracker.debugInfo
        state.lastDetectedActivity = demoTracker.activity

        let wallClockMs = Int(Date().timeIntervalSince1970 * 1000)

        if state.demoCounters.squats > oldCounters.squats {
            state.demoRepFlashTimes.squats = wallClockMs
        }
        if state.demoCounters.jumpingJacks > oldCounters.jumpingJacks {
            state.demoRepFlashTimes.jumpingJacks = wallClockMs
        }
        if state.demoCounters.bicepCurls > oldCounters.bicepCurls {
            state.demoRepFlashTimes.bicepCurls = wallClockMs
        }
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

