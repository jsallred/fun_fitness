import Foundation

enum RehabExerciseType: String, CaseIterable, Identifiable {
    case shoulderFlexion
    case shoulderAbduction
    case shoulderExternalRotation
    case shoulderScaption

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .shoulderFlexion:
            return "Shoulder Flexion"
        case .shoulderAbduction:
            return "Shoulder Abduction"
        case .shoulderExternalRotation:
            return "External Rotation"
        case .shoulderScaption:
            return "Scaption Raise"
        }
    }

    var instructions: String {
        switch self {
        case .shoulderFlexion:
            return "Raise both arms forward, then lower slowly."
        case .shoulderAbduction:
            return "Raise both arms out to the side, then lower slowly."
        case .shoulderExternalRotation:
            return "Bend elbows comfortably and rotate forearms outward."
        case .shoulderScaption:
            return "Raise both arms in a soft V between forward and side."
        }
    }
}

struct RehabExercise: Identifiable, Equatable {
    let id = UUID()
    let type: RehabExerciseType
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
