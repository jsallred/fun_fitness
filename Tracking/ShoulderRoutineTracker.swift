import Foundation

final class ShoulderRoutineTracker {

    struct ExerciseProgress {
        var reps: Int = 0
        var feedback: ExerciseFeedback = .ready
    }

    private enum Phase {
        case unknown
        case down
        case up
        case leftUp
        case rightUp
    }

    private struct BasicState {
        var phase: Phase = .unknown
        var reps: Int = 0
    }

    private struct HeelRaiseState {
        var phase: Phase = .unknown
        var reps: Int = 0
        var baselineAnkleY: Double?
    }

    private var flexion = BasicState()
    private var abduction = BasicState()
    private var scaption = BasicState()
    private var squat = BasicState()
    private var march = BasicState()
    private var hipAbduction = BasicState()
    private var heelRaise = HeelRaiseState()
    private var sitToStand = BasicState()

    func reset() {
        flexion = BasicState()
        abduction = BasicState()
        scaption = BasicState()
        squat = BasicState()
        march = BasicState()
        hipAbduction = BasicState()
        heelRaise = HeelRaiseState()
        sitToStand = BasicState()
    }

    func update(for exercise: RehabExerciseType, points: [PosePoint]) -> ExerciseProgress {
        switch exercise {
        case .shoulderFlexion:
            return updateFlexion(points: points)
        case .shoulderAbduction:
            return updateAbduction(points: points)
        case .shoulderScaption:
            return updateScaption(points: points)
        case .miniSquat:
            return updateMiniSquat(points: points)
        case .marchInPlace:
            return updateMarch(points: points)
        case .standingHipAbduction:
            return updateStandingHipAbduction(points: points)
        case .standingHeelRaise:
            return updateHeelRaise(points: points)
        case .sitToStand:
            return updateSitToStand(points: points)
        case .jumpingJack:
            return .init(reps: 0, feedback: .ready)
        }
    }

    private func point(_ points: [PosePoint], _ index: PoseIndex, minVisibility: Double = 0.4) -> PosePoint? {
        let raw = index.rawValue
        guard raw < points.count else { return nil }
        let p = points[raw]
        guard p.visibility >= minVisibility else { return nil }
        return p
    }

    private func average(_ a: Double, _ b: Double) -> Double {
        (a + b) / 2.0
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

        if flexion.phase == .unknown {
            flexion.phase = wristsAboveShoulders ? .up : .down
            return .init(reps: flexion.reps, feedback: wristsAboveShoulders ? .lowerArms : .raiseArms)
        }

        switch flexion.phase {
        case .down:
            if wristsAboveShoulders {
                flexion.phase = .up
                flexion.reps += 1
                return .init(reps: flexion.reps, feedback: .goodRep)
            }
            return .init(reps: flexion.reps, feedback: .raiseArms)

        case .up:
            if wristsDown {
                flexion.phase = .down
            }
            return .init(reps: flexion.reps, feedback: .lowerArms)

        case .unknown, .leftUp, .rightUp:
            flexion.phase = wristsAboveShoulders ? .up : .down
            return .init(reps: flexion.reps, feedback: .ready)
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

        if abduction.phase == .unknown {
            abduction.phase = reachedTop ? .up : .down
            return .init(reps: abduction.reps, feedback: reachedTop ? .lowerArms : .raiseArms)
        }

        switch abduction.phase {
        case .down:
            if reachedTop {
                abduction.phase = .up
                abduction.reps += 1
                return .init(reps: abduction.reps, feedback: .goodRep)
            }
            return .init(reps: abduction.reps, feedback: .raiseArms)

        case .up:
            if wristsDown {
                abduction.phase = .down
            }
            return .init(reps: abduction.reps, feedback: .lowerArms)

        case .unknown, .leftUp, .rightUp:
            abduction.phase = reachedTop ? .up : .down
            return .init(reps: abduction.reps, feedback: .ready)
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

        if scaption.phase == .unknown {
            scaption.phase = reachedTop ? .up : .down
            return .init(reps: scaption.reps, feedback: reachedTop ? .lowerArms : .raiseArms)
        }

        switch scaption.phase {
        case .down:
            if reachedTop {
                scaption.phase = .up
                scaption.reps += 1
                return .init(reps: scaption.reps, feedback: .goodRep)
            }
            return .init(reps: scaption.reps, feedback: .raiseArms)

        case .up:
            if wristsDown {
                scaption.phase = .down
            }
            return .init(reps: scaption.reps, feedback: .lowerArms)

        case .unknown, .leftUp, .rightUp:
            scaption.phase = reachedTop ? .up : .down
            return .init(reps: scaption.reps, feedback: .ready)
        }
    }

    private func updateMiniSquat(points: [PosePoint]) -> ExerciseProgress {
        guard let lHip = point(points, .leftHip),
              let lKnee = point(points, .leftKnee),
              let lAnkle = point(points, .leftAnkle),
              let rHip = point(points, .rightHip),
              let rKnee = point(points, .rightKnee),
              let rAnkle = point(points, .rightAnkle) else {
            return .init(reps: squat.reps, feedback: .ready)
        }

        let leftAngle = PoseMath.angleDegrees(a: (lHip.x, lHip.y), b: (lKnee.x, lKnee.y), c: (lAnkle.x, lAnkle.y))
        let rightAngle = PoseMath.angleDegrees(a: (rHip.x, rHip.y), b: (rKnee.x, rKnee.y), c: (rAnkle.x, rAnkle.y))
        let kneeAngle = min(leftAngle ?? 180, rightAngle ?? 180)

        let down = kneeAngle < 145
        let up = kneeAngle > 165

        if squat.phase == .unknown {
            squat.phase = up ? .up : .down
            return .init(reps: squat.reps, feedback: up ? .bendKnees : .standTall)
        }

        switch squat.phase {
        case .up:
            if down {
                squat.phase = .down
            }
            return .init(reps: squat.reps, feedback: .bendKnees)

        case .down:
            if up {
                squat.phase = .up
                squat.reps += 1
                return .init(reps: squat.reps, feedback: .goodRep)
            }
            return .init(reps: squat.reps, feedback: .standTall)

        case .unknown, .leftUp, .rightUp:
            squat.phase = up ? .up : .down
            return .init(reps: squat.reps, feedback: .ready)
        }
    }

    private func updateMarch(points: [PosePoint]) -> ExerciseProgress {
        guard let lh = point(points, .leftHip),
              let rh = point(points, .rightHip),
              let lk = point(points, .leftKnee),
              let rk = point(points, .rightKnee) else {
            return .init(reps: march.reps, feedback: .ready)
        }

        let leftLifted = lk.y < lh.y + 0.08
        let rightLifted = rk.y < rh.y + 0.08

        if march.phase == .unknown {
            if leftLifted {
                march.phase = .leftUp
            } else if rightLifted {
                march.phase = .rightUp
            } else {
                march.phase = .down
            }
            return .init(reps: march.reps, feedback: .liftKnees)
        }

        switch march.phase {
        case .down:
            if leftLifted {
                march.phase = .leftUp
                march.reps += 1
                return .init(reps: march.reps, feedback: .goodRep)
            } else if rightLifted {
                march.phase = .rightUp
                march.reps += 1
                return .init(reps: march.reps, feedback: .goodRep)
            }
            return .init(reps: march.reps, feedback: .liftKnees)

        case .leftUp:
            if !leftLifted {
                march.phase = .down
            }
            return .init(reps: march.reps, feedback: .liftKnees)

        case .rightUp:
            if !rightLifted {
                march.phase = .down
            }
            return .init(reps: march.reps, feedback: .liftKnees)

        case .up:
            march.phase = .down
            return .init(reps: march.reps, feedback: .liftKnees)

        case .unknown:
            march.phase = .down
            return .init(reps: march.reps, feedback: .liftKnees)
        }
    }

    private func updateStandingHipAbduction(points: [PosePoint]) -> ExerciseProgress {
        guard let lh = point(points, .leftHip),
              let rh = point(points, .rightHip),
              let la = point(points, .leftAnkle),
              let ra = point(points, .rightAnkle) else {
            return .init(reps: hipAbduction.reps, feedback: .ready)
        }

        let hipWidth = max(abs(rh.x - lh.x), 0.08)
        let leftOut = la.x < lh.x - hipWidth * 0.55
        let rightOut = ra.x > rh.x + hipWidth * 0.55
        let legOut = leftOut || rightOut
        let legsCentered = !leftOut && !rightOut

        if hipAbduction.phase == .unknown {
            hipAbduction.phase = legOut ? .up : .down
            return .init(reps: hipAbduction.reps, feedback: legOut ? .returnToStart : .moveLegOut)
        }

        switch hipAbduction.phase {
        case .down:
            if legOut {
                hipAbduction.phase = .up
                hipAbduction.reps += 1
                return .init(reps: hipAbduction.reps, feedback: .goodRep)
            }
            return .init(reps: hipAbduction.reps, feedback: .moveLegOut)

        case .up:
            if legsCentered {
                hipAbduction.phase = .down
            }
            return .init(reps: hipAbduction.reps, feedback: .returnToStart)

        case .unknown, .leftUp, .rightUp:
            hipAbduction.phase = legOut ? .up : .down
            return .init(reps: hipAbduction.reps, feedback: .ready)
        }
    }

    private func updateHeelRaise(points: [PosePoint]) -> ExerciseProgress {
        guard let la = point(points, .leftAnkle),
              let ra = point(points, .rightAnkle) else {
            return .init(reps: heelRaise.reps, feedback: .ready)
        }

        let avgAnkleY = average(la.y, ra.y)

        if heelRaise.baselineAnkleY == nil {
            heelRaise.baselineAnkleY = avgAnkleY
        }

        let baseline = heelRaise.baselineAnkleY ?? avgAnkleY
        let raised = avgAnkleY < baseline - 0.025
        let lowered = avgAnkleY > baseline - 0.010

        if heelRaise.phase == .unknown {
            heelRaise.phase = raised ? .up : .down
            return .init(reps: heelRaise.reps, feedback: raised ? .lowerHeels : .riseToToes)
        }

        switch heelRaise.phase {
        case .down:
            heelRaise.baselineAnkleY = PoseMath.ema(previous: heelRaise.baselineAnkleY, next: avgAnkleY, alpha: 0.08)

            if raised {
                heelRaise.phase = .up
                heelRaise.reps += 1
                return .init(reps: heelRaise.reps, feedback: .goodRep)
            }
            return .init(reps: heelRaise.reps, feedback: .riseToToes)

        case .up:
            if lowered {
                heelRaise.phase = .down
                heelRaise.baselineAnkleY = avgAnkleY
            }
            return .init(reps: heelRaise.reps, feedback: .lowerHeels)

        case .unknown, .leftUp, .rightUp:
            heelRaise.phase = raised ? .up : .down
            return .init(reps: heelRaise.reps, feedback: .ready)
        }
    }

    private func updateSitToStand(points: [PosePoint]) -> ExerciseProgress {
        guard let lHip = point(points, .leftHip),
              let lKnee = point(points, .leftKnee),
              let lAnkle = point(points, .leftAnkle),
              let rHip = point(points, .rightHip),
              let rKnee = point(points, .rightKnee),
              let rAnkle = point(points, .rightAnkle) else {
            return .init(reps: sitToStand.reps, feedback: .ready)
        }

        let leftAngle = PoseMath.angleDegrees(a: (lHip.x, lHip.y), b: (lKnee.x, lKnee.y), c: (lAnkle.x, lAnkle.y))
        let rightAngle = PoseMath.angleDegrees(a: (rHip.x, rHip.y), b: (rKnee.x, rKnee.y), c: (rAnkle.x, rAnkle.y))
        let kneeAngle = min(leftAngle ?? 180, rightAngle ?? 180)

        let seated = kneeAngle < 120
        let standing = kneeAngle > 160

        if sitToStand.phase == .unknown {
            sitToStand.phase = standing ? .up : .down
            return .init(reps: sitToStand.reps, feedback: standing ? .sitDown : .standUp)
        }

        switch sitToStand.phase {
        case .down:
            if standing {
                sitToStand.phase = .up
                sitToStand.reps += 1
                return .init(reps: sitToStand.reps, feedback: .goodRep)
            }
            return .init(reps: sitToStand.reps, feedback: .standUp)

        case .up:
            if seated {
                sitToStand.phase = .down
            }
            return .init(reps: sitToStand.reps, feedback: .sitDown)

        case .unknown, .leftUp, .rightUp:
            sitToStand.phase = standing ? .up : .down
            return .init(reps: sitToStand.reps, feedback: .ready)
        }
    }
}
