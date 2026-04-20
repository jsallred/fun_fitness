import Foundation

enum RehabBodyRegion: String, CaseIterable, Identifiable {
    case demo = "Demo"
    case shoulder = "Shoulder"
    case hip = "Hip"
    case kneeAnkle = "Knee & Ankle"
    case general = "General"

    var id: String { rawValue }
}

enum RehabRoutineMode: String, Equatable {
    case guided
    case demo
}

enum RehabExerciseType: String, CaseIterable, Identifiable {
    case shoulderFlexion
    case shoulderAbduction
    case shoulderScaption
    case miniSquat
    case marchInPlace
    case jumpingJack
    case standingHipAbduction
    case standingHeelRaise
    case sitToStand

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .shoulderFlexion:
            return "Shoulder Flexion"
        case .shoulderAbduction:
            return "Shoulder Abduction"
        case .shoulderScaption:
            return "Scaption Raise"
        case .miniSquat:
            return "Mini Squat"
        case .marchInPlace:
            return "March in Place"
        case .jumpingJack:
            return "Jumping Jack"
        case .standingHipAbduction:
            return "Standing Hip Abduction"
        case .standingHeelRaise:
            return "Standing Heel Raise"
        case .sitToStand:
            return "Sit-to-Stand"
        }
    }

    var instructions: String {
        switch self {
        case .shoulderFlexion:
            return "Raise both arms forward, then lower slowly."
        case .shoulderAbduction:
            return "Raise both arms out to the side, then lower slowly."
        case .shoulderScaption:
            return "Raise both arms in a soft V between forward and side."
        case .miniSquat:
            return "Bend knees into a mini squat, then stand tall."
        case .marchInPlace:
            return "Lift one knee at a time in a steady marching rhythm."
        case .jumpingJack:
            return "Open arms and feet together, then return to the starting stance."
        case .standingHipAbduction:
            return "Move one leg out to the side, then return to center."
        case .standingHeelRaise:
            return "Rise up onto your toes, then lower with control."
        case .sitToStand:
            return "Stand up from a seated position, then sit back down with control."
        }
    }

    var shortCue: String {
        switch self {
        case .shoulderFlexion:
            return "Forward arm raise"
        case .shoulderAbduction:
            return "Side arm raise"
        case .shoulderScaption:
            return "Soft V arm raise"
        case .miniSquat:
            return "Controlled squat"
        case .marchInPlace:
            return "Alternating knee lifts"
        case .jumpingJack:
            return "Open and close"
        case .standingHipAbduction:
            return "Leg out to side"
        case .standingHeelRaise:
            return "Rise to toes"
        case .sitToStand:
            return "Sit then stand"
        }
    }
}

struct RehabExercise: Identifiable, Equatable {
    let id = UUID()
    let type: RehabExerciseType
    let targetReps: Int?
}

struct RehabRoutine: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let bodyRegion: RehabBodyRegion
    let summary: String
    let estimatedMinutes: Int
    let mode: RehabRoutineMode
    let exercises: [RehabExercise]

    var isDemoRoutine: Bool {
        mode == .demo
    }
}

enum SessionState: Equatable {
    case login
    case home
    case active
    case transitioning
    case quitting
    case completed
}

enum ExerciseFeedback: String, Equatable {
    case ready = "Ready"
    case raiseArms = "Raise arms"
    case lowerArms = "Lower arms"
    case bendKnees = "Bend knees"
    case standTall = "Stand tall"
    case liftKnees = "Lift knees"
    case moveLegOut = "Move leg out"
    case returnToStart = "Return to start"
    case riseToToes = "Rise to toes"
    case lowerHeels = "Lower heels"
    case standUp = "Stand up"
    case sitDown = "Sit down"
    case goodRep = "Good rep"
    case complete = "Exercise complete"
}
