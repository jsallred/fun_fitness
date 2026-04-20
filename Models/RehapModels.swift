import Foundation

struct RehabExercise: Identifiable, Equatable {
    let id = UUID()
    let configId: String
    let displayName: String
    let instructions: String
    let targetReps: Int
}

struct RehabRoutine: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let exercises: [RehabExercise]
}

enum SessionState: Equatable {
    case idle
    case active
    case transitioning
    case completed
}

enum ExerciseFeedback: String, Equatable {
    case ready = "Ready"
    case raiseArms = "Raise arms"
    case lowerArms = "Lower arms"
    case goodRep = "Good rep"
    case keepElbowsComfortable = "Relax elbows a bit"
    case complete = "Exercise complete"
}
