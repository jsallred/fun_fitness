//
//  ExerciseTracker.swift
//  fun_fitness
//
//  Created by Joseph Allred on 3/9/26.
//

import Foundation

struct SquatDebugInfo: Equatable {
    var state: String = "UP"
    var minKneeAngle: Double?
    var averageKneeAngle: Double?
}

struct JumpingJackDebugInfo: Equatable {
    var state: String = "CLOSED"
    var ankleToShoulderRatio: Double?
    var wristsAboveShoulders: Bool = false
    var wristsBelowShoulders: Bool = false
    var feetWiderThanShoulders: Bool = false
    var feetCloserThanShoulders: Bool = false
}

struct CurlDebugInfo: Equatable {
    var state: String = "EXTENDED"
    var minElbowAngle: Double?
    var averageElbowAngle: Double?
}

struct DemoExerciseDebugInfo: Equatable {
    var squat = SquatDebugInfo()
    var jumpingJack = JumpingJackDebugInfo()
    var curl = CurlDebugInfo()
}

final class ExerciseTracker {
    private(set) var activity: ActivityType = .unknown

    private let alpha = 0.25

    struct SquatState {
        var reps = 0
        var state = "UP"
        var downHold = 0
        var upHold = 0
        var kneeMin: Double?
        var kneeAverage: Double?
        var lastRepTime = 0

        // Conservative defaults for demo debugging. Tune downConfirm around the user's recorded squat depth.
        let downEnter = 135.0
        let downConfirm = 120.0
        let upEnter = 145.0
        let upConfirm = 160.0
        let confirmFrames = 5
        let minInterval = 650
    }

    struct CurlState {
        var reps = 0
        var state = "EXTENDED"
        var curlHold = 0
        var extendHold = 0
        var elbowMin: Double?
        var elbowAverage: Double?
        var lastRepTime = 0

        // Conservative defaults for demo debugging. Tune curlConfirm around the user's recorded curl angle.
        let curlEnter = 115.0
        let curlConfirm = 80.0
        let extendEnter = 120.0
        let extendConfirm = 150.0
        let confirmFrames = 5
        let minInterval = 650
    }

    struct JackState {
        var reps = 0
        var state = "CLOSED"
        var openHold = 0
        var closedHold = 0
        var ankleToShoulderRatio: Double?
        var wristsAboveShoulders = false
        var wristsBelowShoulders = false
        var feetWiderThanShoulders = false
        var feetCloserThanShoulders = false
        var lastRepTime = 0

        let openConfirmFrames = 4
        let closedConfirmFrames = 4
        let minInterval = 350
        let widthHysteresis = 0.08
        let wristMargin = 0.02
    }

    private(set) var squat = SquatState()
    private(set) var jack = JackState()
    private(set) var curl = CurlState()

    private(set) var kneeAngle: Double?
    private(set) var debugInfo = DemoExerciseDebugInfo()

    private var squatScore: Double?
    private var jackScore: Double?
    private var curlScore: Double?

    func reset() {
        activity = .unknown
        squat = SquatState()
        jack = JackState()
        curl = CurlState()
        kneeAngle = nil
        debugInfo = DemoExerciseDebugInfo()
        squatScore = nil
        jackScore = nil
        curlScore = nil
    }

    func update(points: [PosePoint], nowMs: Int) {
        let squatInfo = computeSquat(points: points)
        let jackInfo = computeJack(points: points)
        let curlInfo = computeCurl(points: points)

        updateSquatMachine(info: squatInfo, nowMs: nowMs)
        updateJackMachine(info: jackInfo, nowMs: nowMs)
        updateCurlMachine(info: curlInfo, nowMs: nowMs)

        kneeAngle = squatInfo.minKnee
        debugInfo = DemoExerciseDebugInfo(
            squat: SquatDebugInfo(
                state: squat.state,
                minKneeAngle: squat.kneeMin,
                averageKneeAngle: squat.kneeAverage
            ),
            jumpingJack: JumpingJackDebugInfo(
                state: jack.state,
                ankleToShoulderRatio: jack.ankleToShoulderRatio,
                wristsAboveShoulders: jack.wristsAboveShoulders,
                wristsBelowShoulders: jack.wristsBelowShoulders,
                feetWiderThanShoulders: jack.feetWiderThanShoulders,
                feetCloserThanShoulders: jack.feetCloserThanShoulders
            ),
            curl: CurlDebugInfo(
                state: curl.state,
                minElbowAngle: curl.elbowMin,
                averageElbowAngle: curl.elbowAverage
            )
        )

        if let score = squatInfo.score {
            squatScore = PoseMath.ema(previous: squatScore, next: score, alpha: 0.2)
        }

        if let score = jackInfo.score {
            jackScore = PoseMath.ema(previous: jackScore, next: score, alpha: 0.2)
        }

        if let score = curlInfo.score {
            curlScore = PoseMath.ema(previous: curlScore, next: score, alpha: 0.2)
        }

        let s = squatScore ?? 0
        let j = jackScore ?? 0
        let c = curlScore ?? 0

        if s > 0.55 && s > j + 0.15 && s > c + 0.15 {
            activity = .squat
        } else if j > 0.55 && j > s + 0.15 && j > c + 0.15 {
            activity = .jack
        } else if c > 0.55 && c > s + 0.15 && c > j + 0.15 {
            activity = .curl
        } else if max(s, max(j, c)) < 0.35 {
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

    private func computeSquat(points: [PosePoint]) -> (score: Double?, minKnee: Double?, averageKnee: Double?) {
        let candidates: [Double] = [
            kneeAngle(points: points, hip: .leftHip, knee: .leftKnee, ankle: .leftAnkle),
            kneeAngle(points: points, hip: .rightHip, knee: .rightKnee, ankle: .rightAnkle)
        ].compactMap { $0 }

        guard !candidates.isEmpty else { return (nil, squat.kneeMin, squat.kneeAverage) }

        let rawMin = candidates.min()!
        let rawAverage = candidates.reduce(0, +) / Double(candidates.count)

        squat.kneeMin = PoseMath.ema(previous: squat.kneeMin, next: rawMin, alpha: alpha)
        squat.kneeAverage = PoseMath.ema(previous: squat.kneeAverage, next: rawAverage, alpha: alpha)

        let score = squat.kneeMin.map { PoseMath.clamp01((170.0 - $0) / 80.0) }
        return (score, squat.kneeMin, squat.kneeAverage)
    }

    private func kneeAngle(points: [PosePoint], hip: PoseIndex, knee: PoseIndex, ankle: PoseIndex) -> Double? {
        guard let hipPoint = point(points, hip),
              let kneePoint = point(points, knee),
              let anklePoint = point(points, ankle) else { return nil }

        return PoseMath.angleDegrees(a: hipPoint, b: kneePoint, c: anklePoint)
    }

    private func updateSquatMachine(info: (score: Double?, minKnee: Double?, averageKnee: Double?), nowMs: Int) {
        guard let knee = info.minKnee else { return }

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

    private func computeJack(points: [PosePoint]) -> (score: Double?, isOpen: Bool?, isClosed: Bool?) {
        guard let lWrist = point(points, .leftWrist),
              let rWrist = point(points, .rightWrist),
              let lAnkle = point(points, .leftAnkle),
              let rAnkle = point(points, .rightAnkle),
              let lShoulder = point(points, .leftShoulder, minVisibility: 0.3),
              let rShoulder = point(points, .rightShoulder, minVisibility: 0.3) else {
            return (nil, nil, nil)
        }

        let averageShoulderY = (lShoulder.1 + rShoulder.1) / 2.0
        let shoulderWidth = abs(lShoulder.0 - rShoulder.0)
        guard shoulderWidth > 0.001 else { return (nil, nil, nil) }

        let ankleWidth = abs(lAnkle.0 - rAnkle.0)
        let ratio = ankleWidth / shoulderWidth
        jack.ankleToShoulderRatio = PoseMath.ema(previous: jack.ankleToShoulderRatio, next: ratio, alpha: alpha)

        let wristsAbove = lWrist.1 < averageShoulderY - jack.wristMargin && rWrist.1 < averageShoulderY - jack.wristMargin
        let wristsBelow = lWrist.1 > averageShoulderY + jack.wristMargin && rWrist.1 > averageShoulderY + jack.wristMargin
        let wider = ratio > 1.0 + jack.widthHysteresis
        let closer = ratio < 1.0 - jack.widthHysteresis

        jack.wristsAboveShoulders = wristsAbove
        jack.wristsBelowShoulders = wristsBelow
        jack.feetWiderThanShoulders = wider
        jack.feetCloserThanShoulders = closer

        let isOpen = wider && wristsAbove
        let isClosed = closer && wristsBelow
        let score = isOpen ? 1.0 : (isClosed ? 0.0 : 0.35)

        return (score, isOpen, isClosed)
    }

    private func updateJackMachine(info: (score: Double?, isOpen: Bool?, isClosed: Bool?), nowMs: Int) {
        guard let openCond = info.isOpen, let closedCond = info.isClosed else { return }

        switch jack.state {
        case "CLOSED":
            if openCond {
                jack.state = "OPENING"
                jack.openHold = 1
            }

        case "OPENING":
            if !openCond {
                jack.state = closedCond ? "CLOSED" : "CLOSED"
                jack.openHold = 0
            } else {
                jack.openHold += 1
                if jack.openHold >= jack.openConfirmFrames {
                    jack.state = "OPEN"
                    jack.openHold = 0
                }
            }

        case "OPEN":
            if closedCond {
                jack.state = "CLOSING"
                jack.closedHold = 1
            }

        case "CLOSING":
            if !closedCond {
                jack.state = openCond ? "OPEN" : "OPEN"
                jack.closedHold = 0
            } else {
                jack.closedHold += 1
                if jack.closedHold >= jack.closedConfirmFrames {
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

    private func computeCurl(points: [PosePoint]) -> (score: Double?, minElbow: Double?, averageElbow: Double?) {
        let candidates: [Double] = [
            elbowAngle(points: points, shoulder: .leftShoulder, elbow: .leftElbow, wrist: .leftWrist),
            elbowAngle(points: points, shoulder: .rightShoulder, elbow: .rightElbow, wrist: .rightWrist)
        ].compactMap { $0 }

        guard !candidates.isEmpty else { return (nil, curl.elbowMin, curl.elbowAverage) }

        let rawMin = candidates.min()!
        let rawAverage = candidates.reduce(0, +) / Double(candidates.count)

        curl.elbowMin = PoseMath.ema(previous: curl.elbowMin, next: rawMin, alpha: alpha)
        curl.elbowAverage = PoseMath.ema(previous: curl.elbowAverage, next: rawAverage, alpha: alpha)

        let score = curl.elbowMin.map { PoseMath.clamp01((160.0 - $0) / 90.0) }
        return (score, curl.elbowMin, curl.elbowAverage)
    }

    private func elbowAngle(points: [PosePoint], shoulder: PoseIndex, elbow: PoseIndex, wrist: PoseIndex) -> Double? {
        guard let shoulderPoint = point(points, shoulder, minVisibility: 0.35),
              let elbowPoint = point(points, elbow, minVisibility: 0.35),
              let wristPoint = point(points, wrist, minVisibility: 0.35) else { return nil }

        return PoseMath.angleDegrees(a: shoulderPoint, b: elbowPoint, c: wristPoint)
    }

    private func updateCurlMachine(info: (score: Double?, minElbow: Double?, averageElbow: Double?), nowMs: Int) {
        guard let elbow = info.minElbow else { return }

        let enteringCurl = elbow < curl.curlEnter
        let confirmedCurl = elbow < curl.curlConfirm
        let enteringExtend = elbow > curl.extendEnter
        let confirmedExtend = elbow > curl.extendConfirm

        switch curl.state {
        case "EXTENDED":
            if enteringCurl {
                curl.state = "CURLING"
                curl.curlHold = 0
            }

        case "CURLING":
            if !enteringCurl {
                curl.state = "EXTENDED"
                curl.curlHold = 0
            } else {
                curl.curlHold = confirmedCurl ? curl.curlHold + 1 : max(0, curl.curlHold - 1)
                if curl.curlHold >= curl.confirmFrames {
                    curl.state = "CURLED"
                    curl.curlHold = 0
                }
            }

        case "CURLED":
            if enteringExtend {
                curl.state = "EXTENDING"
                curl.extendHold = 0
            }

        case "EXTENDING":
            if !enteringExtend {
                curl.state = "CURLED"
                curl.extendHold = 0
            } else {
                curl.extendHold = confirmedExtend ? curl.extendHold + 1 : max(0, curl.extendHold - 1)
                if curl.extendHold >= curl.confirmFrames {
                    if nowMs - curl.lastRepTime > curl.minInterval {
                        curl.reps += 1
                        curl.lastRepTime = nowMs
                    }
                    curl.state = "EXTENDED"
                    curl.extendHold = 0
                }
            }

        default:
            curl.state = "EXTENDED"
        }
    }
}
