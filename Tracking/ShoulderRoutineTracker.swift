import Foundation

/// Legacy hardcoded tracker -- replaced by ConfigurableExerciseTracker + JSON configs.
/// Kept for reference; nothing in the app calls into this class anymore.
final class ShoulderRoutineTracker {

    private struct FlexionState {
        var phase: Phase = .down
        var reps: Int = 0
    }

    private struct AbductionState {
        var phase: Phase = .down
        var reps: Int = 0
    }

    private struct ExternalRotationState {
        var phase: Phase = .inward
        var reps: Int = 0
    }

    private struct ScaptionState {
        var phase: Phase = .down
        var reps: Int = 0
    }

    private enum Phase {
        case down
        case up
        case inward
        case outward
    }

    private var flexion = FlexionState()
    private var abduction = AbductionState()
    private var externalRotation = ExternalRotationState()
    private var scaption = ScaptionState()

    func reset() {
        flexion = FlexionState()
        abduction = AbductionState()
        externalRotation = ExternalRotationState()
        scaption = ScaptionState()
    }

    func update(for exerciseId: String, points: [PosePoint]) -> ExerciseProgress {
        switch exerciseId {
        case "shoulderFlexion":
            return updateFlexion(points: points)
        case "shoulderAbduction":
            return updateAbduction(points: points)
        case "shoulderExternalRotation":
            return updateExternalRotation(points: points)
        case "shoulderScaption":
            return updateScaption(points: points)
        default:
            return ExerciseProgress()
        }
    }

    private func point(_ points: [PosePoint], _ index: PoseIndex, minVisibility: Double = 0.4) -> PosePoint? {
        let raw = index.rawValue
        guard raw < points.count else { return nil }
        let p = points[raw]
        guard p.visibility >= minVisibility else { return nil }
        return p
    }

    private func updateFlexion(points: [PosePoint]) -> ExerciseProgress {
        guard let lw = point(points, .leftWrist),
              let rw = point(points, .rightWrist),
              let ls = point(points, .leftShoulder),
              let rs = point(points, .rightShoulder) else {
            return .init(reps: flexion.reps, feedback: .ready)
        }

        let wristsAboveShoulders = lw.y < ls.y && rw.y < rs.y
        let wristsDown = lw.y > ls.y + 0.18 && rw.y > rs.y + 0.18

        if flexion.phase == .down {
            if wristsAboveShoulders {
                flexion.phase = .up
                flexion.reps += 1
                return .init(reps: flexion.reps, feedback: .goodRep)
            } else {
                return .init(reps: flexion.reps, feedback: .raiseArms)
            }
        } else {
            if wristsDown {
                flexion.phase = .down
            }
            return .init(reps: flexion.reps, feedback: .lowerArms)
        }
    }

    private func updateAbduction(points: [PosePoint]) -> ExerciseProgress {
        guard let lw = point(points, .leftWrist),
              let rw = point(points, .rightWrist),
              let ls = point(points, .leftShoulder),
              let rs = point(points, .rightShoulder),
              let lh = point(points, .leftHip),
              let rh = point(points, .rightHip) else {
            return .init(reps: abduction.reps, feedback: .ready)
        }

        let leftArmOut = abs(lw.x - ls.x) > abs(lh.x - ls.x) * 1.4
        let rightArmOut = abs(rw.x - rs.x) > abs(rh.x - rs.x) * 1.4
        let wristsNearShoulderHeight = abs(lw.y - ls.y) < 0.16 && abs(rw.y - rs.y) < 0.16
        let wristsDown = lw.y > ls.y + 0.18 && rw.y > rs.y + 0.18

        let reachedTop = leftArmOut && rightArmOut && wristsNearShoulderHeight

        if abduction.phase == .down {
            if reachedTop {
                abduction.phase = .up
                abduction.reps += 1
                return .init(reps: abduction.reps, feedback: .goodRep)
            } else {
                return .init(reps: abduction.reps, feedback: .raiseArms)
            }
        } else {
            if wristsDown {
                abduction.phase = .down
            }
            return .init(reps: abduction.reps, feedback: .lowerArms)
        }
    }

    private func updateScaption(points: [PosePoint]) -> ExerciseProgress {
        guard let lw = point(points, .leftWrist),
              let rw = point(points, .rightWrist),
              let ls = point(points, .leftShoulder),
              let rs = point(points, .rightShoulder) else {
            return .init(reps: scaption.reps, feedback: .ready)
        }

        let shoulderWidth = max(abs(rs.x - ls.x), 0.08)

        let leftDx = abs(lw.x - ls.x)
        let rightDx = abs(rw.x - rs.x)

        let moderateAngle =
            leftDx > shoulderWidth * 0.35 &&
            leftDx < shoulderWidth * 1.15 &&
            rightDx > shoulderWidth * 0.35 &&
            rightDx < shoulderWidth * 1.15

        let wristsHigh = lw.y < ls.y + 0.02 && rw.y < rs.y + 0.02
        let wristsDown = lw.y > ls.y + 0.18 && rw.y > rs.y + 0.18

        let reachedTop = moderateAngle && wristsHigh

        if scaption.phase == .down {
            if reachedTop {
                scaption.phase = .up
                scaption.reps += 1
                return .init(reps: scaption.reps, feedback: .goodRep)
            } else {
                return .init(reps: scaption.reps, feedback: .raiseArms)
            }
        } else {
            if wristsDown {
                scaption.phase = .down
            }
            return .init(reps: scaption.reps, feedback: .lowerArms)
        }
    }

    private func updateExternalRotation(points: [PosePoint]) -> ExerciseProgress {
        guard let le = point(points, .leftElbow),
              let re = point(points, .rightElbow),
              let lw = point(points, .leftWrist),
              let rw = point(points, .rightWrist),
              let ls = point(points, .leftShoulder),
              let rs = point(points, .rightShoulder),
              let lh = point(points, .leftHip),
              let rh = point(points, .rightHip) else {
            return .init(reps: externalRotation.reps, feedback: .ready)
        }

        // Looser: elbows can float a bit away from torso, but should still stay in the general side corridor.
        let leftElbowComfortable = abs(le.x - lh.x) < 0.22
        let rightElbowComfortable = abs(re.x - rh.x) < 0.22
        let elbowsComfortable = leftElbowComfortable && rightElbowComfortable

        let elbowsNotTooHigh = abs(le.y - ls.y) > 0.06 && abs(re.y - rs.y) > 0.06

        guard elbowsComfortable && elbowsNotTooHigh else {
            return .init(reps: externalRotation.reps, feedback: .keepElbowsComfortable)
        }

        let leftForearmOut = lw.x < le.x - 0.04
        let rightForearmOut = rw.x > re.x + 0.04
        let opened = leftForearmOut && rightForearmOut

        let leftForearmIn = abs(lw.x - le.x) < 0.08
        let rightForearmIn = abs(rw.x - re.x) < 0.08
        let closed = leftForearmIn && rightForearmIn

        if externalRotation.phase == .inward {
            if opened {
                externalRotation.phase = .outward
                externalRotation.reps += 1
                return .init(reps: externalRotation.reps, feedback: .goodRep)
            } else {
                return .init(reps: externalRotation.reps, feedback: .raiseArms)
            }
        } else {
            if closed {
                externalRotation.phase = .inward
            }
            return .init(reps: externalRotation.reps, feedback: .lowerArms)
        }
    }
}
