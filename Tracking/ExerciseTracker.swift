//
//  ExerciseTracker.swift
//  fun_fitness
//
//  Created by Joseph Allred on 3/9/26.
//

import Foundation

final class ExerciseTracker {
    private(set) var activity: ActivityType = .unknown

    private let alpha = 0.25

    struct SquatState {
        var reps = 0
        var state = "UP"
        var downHold = 0
        var upHold = 0
        var kneeMin: Double?
        var lastRepTime = 0

        let downEnter = 155.0
        let downConfirm = 150.0
        let upEnter = 150.0
        let upConfirm = 160.0
        let confirmFrames = 4
        let minInterval = 450
    }

    struct JackState {
        var reps = 0
        var state = "CLOSED"
        var openHold = 0
        var closedHold = 0
        var handsHigh: Double?
        var feetWide: Double?
        var lastRepTime = 0

        let openHands = 0.7
        let openFeet = 0.65
        let closedHands = 0.45
        let closedFeet = 0.45
        let confirmFrames = 5
        let minInterval = 350
    }

    private(set) var squat = SquatState()
    private(set) var jack = JackState()

    private(set) var kneeAngle: Double?
    private var squatScore: Double?
    private var jackScore: Double?

    func reset() {
        activity = .unknown
        squat = SquatState()
        jack = JackState()
        kneeAngle = nil
        squatScore = nil
        jackScore = nil
    }

    func update(points: [PosePoint], nowMs: Int) {
        let squatInfo = computeSquat(points: points)
        let jackInfo = computeJack(points: points)

        updateSquatMachine(info: squatInfo, nowMs: nowMs)
        updateJackMachine(info: jackInfo, nowMs: nowMs)

        kneeAngle = squatInfo.knee

        if let score = squatInfo.score {
            squatScore = PoseMath.ema(previous: squatScore, next: score, alpha: 0.2)
        }

        if let score = jackInfo.score {
            jackScore = PoseMath.ema(previous: jackScore, next: score, alpha: 0.2)
        }

        let s = squatScore ?? 0
        let j = jackScore ?? 0

        if s > 0.55 && s > j + 0.15 {
            activity = .squat
        } else if j > 0.55 && j > s + 0.15 {
            activity = .jack
        } else if max(s, j) < 0.35 {
            activity = .unknown
        }
    }

    private func point(_ points: [PosePoint], _ index: PoseIndex, minVisibility: Double = 0.4) -> (Double, Double)? {
        let raw = index.rawValue
        guard raw < points.count else { return nil }
        let p = points[raw]
        guard p.visibility >= minVisibility else { return nil }
        return (p.x, p.y)
    }

    private func computeSquat(points: [PosePoint]) -> (score: Double?, knee: Double?) {
        let lHip = point(points, .leftHip)
        let lKnee = point(points, .leftKnee)
        let lAnkle = point(points, .leftAnkle)

        let rHip = point(points, .rightHip)
        let rKnee = point(points, .rightKnee)
        let rAnkle = point(points, .rightAnkle)

        var kneeMinRaw: Double?

        if let lHip, let lKnee, let lAnkle,
           let angle = PoseMath.angleDegrees(a: lHip, b: lKnee, c: lAnkle) {
            kneeMinRaw = angle
        }

        if let rHip, let rKnee, let rAnkle,
           let angle = PoseMath.angleDegrees(a: rHip, b: rKnee, c: rAnkle) {
            kneeMinRaw = kneeMinRaw == nil ? angle : min(kneeMinRaw!, angle)
        }

        if let kneeMinRaw {
            squat.kneeMin = PoseMath.ema(previous: squat.kneeMin, next: kneeMinRaw, alpha: alpha)
        }

        let knee = squat.kneeMin
        let score = knee.map { PoseMath.clamp01((170.0 - $0) / 70.0) }

        return (score, knee)
    }

    private func updateSquatMachine(info: (score: Double?, knee: Double?), nowMs: Int) {
        guard let knee = info.knee else { return }

        let enteringDown = knee < squat.downEnter
        let confirmedDown = knee < squat.downConfirm

        let enteringUp = knee > squat.upEnter
        let confirmedUp = knee > squat.upConfirm

        switch squat.state {
        case "UP":
            if enteringDown {
                squat.state = "DESCENDING"
                squat.downHold = 0
            }

        case "DESCENDING":
            if !enteringDown {
                squat.state = "UP"
                squat.downHold = 0
            } else {
                squat.downHold = confirmedDown ? squat.downHold + 1 : max(0, squat.downHold - 1)
                if squat.downHold >= squat.confirmFrames {
                    squat.state = "DOWN"
                    squat.downHold = 0
                }
            }

        case "DOWN":
            if enteringUp {
                squat.state = "ASCENDING"
                squat.upHold = 0
            }

        case "ASCENDING":
            if !enteringUp {
                squat.state = "DOWN"
                squat.upHold = 0
            } else {
                squat.upHold = confirmedUp ? squat.upHold + 1 : max(0, squat.upHold - 1)
                if squat.upHold >= squat.confirmFrames {
                    if nowMs - squat.lastRepTime > squat.minInterval {
                        squat.reps += 1
                        squat.lastRepTime = nowMs
                    }
                    squat.state = "UP"
                    squat.upHold = 0
                }
            }

        default:
            squat.state = "UP"
        }
    }

    private func computeJack(points: [PosePoint]) -> (score: Double?, hands: Double?, feet: Double?) {
        let lWrist = point(points, .leftWrist)
        let rWrist = point(points, .rightWrist)
        let lAnkle = point(points, .leftAnkle)
        let rAnkle = point(points, .rightAnkle)
        let lShoulder = point(points, .leftShoulder, minVisibility: 0.3)
        let rShoulder = point(points, .rightShoulder, minVisibility: 0.3)
        let lHip = point(points, .leftHip, minVisibility: 0.3)
        let rHip = point(points, .rightHip, minVisibility: 0.3)

        var handsHigh: Double?
        var feetWide: Double?

        if let lWrist, let rWrist, let lShoulder, let rShoulder {
            let midShoulderY = (lShoulder.1 + rShoulder.1) / 2.0
            let shoulderSpan = abs(lShoulder.0 - rShoulder.0)
            let safeShoulderSpan = shoulderSpan == 0 ? 1.0 : shoulderSpan
            let midWristY = (lWrist.1 + rWrist.1) / 2.0
            handsHigh = PoseMath.clamp01((midShoulderY - midWristY) / (0.9 * safeShoulderSpan))
        }

        if let lAnkle, let rAnkle, let lHip, let rHip {
            let hipWidth = abs(lHip.0 - rHip.0)
            let safeHipWidth = hipWidth == 0 ? 1.0 : hipWidth
            let ankleWidth = abs(lAnkle.0 - rAnkle.0)
            feetWide = PoseMath.clamp01((ankleWidth - 1.2 * safeHipWidth) / (1.8 * safeHipWidth))
        }

        if let handsHigh {
            jack.handsHigh = PoseMath.ema(previous: jack.handsHigh, next: handsHigh, alpha: alpha)
        }

        if let feetWide {
            jack.feetWide = PoseMath.ema(previous: jack.feetWide, next: feetWide, alpha: alpha)
        }

        let score = 0.55 * (jack.handsHigh ?? 0) + 0.45 * (jack.feetWide ?? 0)
        return (score, jack.handsHigh, jack.feetWide)
    }

    private func updateJackMachine(info: (score: Double?, hands: Double?, feet: Double?), nowMs: Int) {
        guard let h = info.hands, let f = info.feet else { return }

        let openCond = h > jack.openHands && f > jack.openFeet
        let closedCond = h < jack.closedHands && f < jack.closedFeet

        switch jack.state {
        case "CLOSED":
            if openCond {
                jack.state = "OPENING"
            }

        case "OPENING":
            if !openCond {
                jack.state = "CLOSED"
                jack.openHold = 0
            } else {
                jack.openHold += 1
                if jack.openHold >= jack.confirmFrames {
                    jack.state = "OPEN"
                    jack.openHold = 0
                }
            }

        case "OPEN":
            if closedCond {
                jack.state = "CLOSING"
            }

        case "CLOSING":
            if !closedCond {
                jack.state = "OPEN"
                jack.closedHold = 0
            } else {
                jack.closedHold += 1
                if jack.closedHold >= jack.confirmFrames {
                    if nowMs - jack.lastRepTime > jack.minInterval {
                        jack.reps += 1
                        jack.lastRepTime = nowMs
                    }
                    jack.state = "CLOSED"
                    jack.closedHold = 0
                }
            }

        default:
            jack.state = "CLOSED"
        }
    }
}
