import Foundation

final class ConfigurableExerciseTracker {
    let config: ExerciseConfig

    private(set) var reps: Int = 0
    private(set) var currentState: String
    private(set) var feedback: String = "ready"

    private var smoothedValues: [String: Double] = [:]
    private var frameVariableCache: [String: Double] = [:]
    private var holdCounters: [String: Int] = [:]
    private var lastRepTimeMs: Int = 0

    private static let landmarkMap: [String: PoseIndex] = [
        "nose": .nose,
        "leftShoulder": .leftShoulder,
        "rightShoulder": .rightShoulder,
        "leftElbow": .leftElbow,
        "rightElbow": .rightElbow,
        "leftWrist": .leftWrist,
        "rightWrist": .rightWrist,
        "leftHip": .leftHip,
        "rightHip": .rightHip,
        "leftKnee": .leftKnee,
        "rightKnee": .rightKnee,
        "leftAnkle": .leftAnkle,
        "rightAnkle": .rightAnkle
    ]

    init(config: ExerciseConfig) {
        self.config = config
        self.currentState = config.stateMachine.initialState
    }

    func reset() {
        reps = 0
        currentState = config.stateMachine.initialState
        feedback = "ready"
        smoothedValues.removeAll()
        holdCounters.removeAll()
        lastRepTimeMs = 0
    }

    // MARK: - Main per-frame entry point

    func update(points: [PosePoint], nowMs: Int) -> ExerciseProgress {
        guard hasRequiredLandmarks(points: points) else {
            return ExerciseProgress(reps: reps, feedback: feedbackEnum)
        }

        frameVariableCache.removeAll(keepingCapacity: true)
        computeVariables(points: points)

        let sm = config.stateMachine

        if let guardCond = sm.guard_ {
            if !evaluateCondition(guardCond, points: points) {
                let fb = sm.guardFeedback ?? "ready"
                feedback = fb
                return ExerciseProgress(reps: reps, feedback: feedbackEnum)
            }
        }

        guard let stateConfig = sm.states[currentState] else {
            return ExerciseProgress(reps: reps, feedback: feedbackEnum)
        }

        feedback = stateConfig.feedback ?? feedback

        for transition in stateConfig.transitions {
            if processTransition(transition, points: points, nowMs: nowMs) {
                break
            }
        }

        return ExerciseProgress(reps: reps, feedback: feedbackEnum)
    }

    // MARK: - Landmark availability check

    private func hasRequiredLandmarks(points: [PosePoint]) -> Bool {
        for name in config.requiredLandmarks {
            guard let idx = Self.landmarkMap[name] else { return false }
            let raw = idx.rawValue
            guard raw < points.count else { return false }
            guard points[raw].visibility >= 0.4 else { return false }
        }
        return true
    }

    // MARK: - Variable computation (with optional smoothing)

    private func computeVariables(points: [PosePoint]) {
        guard let variables = config.variables else { return }
        for (name, varConfig) in variables {
            let rawValue = evaluateNumeric(varConfig.expr, points: points)
            guard let rawValue else { continue }

            if let smoothing = varConfig.smoothing, smoothing.type == "ema" {
                let smoothed = PoseMath.ema(
                    previous: smoothedValues[name],
                    next: rawValue,
                    alpha: smoothing.alpha
                )
                smoothedValues[name] = smoothed
                frameVariableCache[name] = smoothed
            } else {
                frameVariableCache[name] = rawValue
            }
        }
    }

    // MARK: - Numeric expression evaluator

    func evaluateNumeric(_ expr: NumericExpr, points: [PosePoint]) -> Double? {
        switch expr {
        case .literal(let v):
            return v

        case .landmark(let pointName, let coord):
            return landmarkCoord(pointName, coord: coord, points: points)

        case .angle(let pointNames):
            guard pointNames.count == 3 else { return nil }
            guard let a = landmarkXY(pointNames[0], points: points),
                  let b = landmarkXY(pointNames[1], points: points),
                  let c = landmarkXY(pointNames[2], points: points) else {
                return nil
            }
            return PoseMath.angleDegrees(a: a, b: b, c: c)

        case .variable(let name):
            return frameVariableCache[name]

        case .abs(let inner):
            guard let v = evaluateNumeric(inner, points: points) else { return nil }
            return Swift.abs(v)

        case .min(let exprs):
            let values = exprs.compactMap { evaluateNumeric($0, points: points) }
            return values.min()

        case .max(let exprs):
            let values = exprs.compactMap { evaluateNumeric($0, points: points) }
            return values.max()

        case .add(let a, let b):
            guard let va = evaluateNumeric(a, points: points),
                  let vb = evaluateNumeric(b, points: points) else { return nil }
            return va + vb

        case .sub(let a, let b):
            guard let va = evaluateNumeric(a, points: points),
                  let vb = evaluateNumeric(b, points: points) else { return nil }
            return va - vb

        case .mul(let a, let b):
            guard let va = evaluateNumeric(a, points: points),
                  let vb = evaluateNumeric(b, points: points) else { return nil }
            return va * vb

        case .div(let a, let b):
            guard let va = evaluateNumeric(a, points: points),
                  let vb = evaluateNumeric(b, points: points) else { return nil }
            guard vb != 0 else { return 0 }
            return va / vb

        case .clamp01(let inner):
            guard let v = evaluateNumeric(inner, points: points) else { return nil }
            return PoseMath.clamp01(v)
        }
    }

    // MARK: - Condition expression evaluator

    func evaluateCondition(_ cond: ConditionExpr, points: [PosePoint]) -> Bool {
        switch cond {
        case .gt(let a, let b):
            guard let va = evaluateNumeric(a, points: points),
                  let vb = evaluateNumeric(b, points: points) else { return false }
            return va > vb

        case .lt(let a, let b):
            guard let va = evaluateNumeric(a, points: points),
                  let vb = evaluateNumeric(b, points: points) else { return false }
            return va < vb

        case .gte(let a, let b):
            guard let va = evaluateNumeric(a, points: points),
                  let vb = evaluateNumeric(b, points: points) else { return false }
            return va >= vb

        case .lte(let a, let b):
            guard let va = evaluateNumeric(a, points: points),
                  let vb = evaluateNumeric(b, points: points) else { return false }
            return va <= vb

        case .and(let conditions):
            return conditions.allSatisfy { evaluateCondition($0, points: points) }

        case .or(let conditions):
            return conditions.contains { evaluateCondition($0, points: points) }

        case .not(let inner):
            return !evaluateCondition(inner, points: points)
        }
    }

    // MARK: - State machine transition processing

    private func processTransition(_ transition: TransitionConfig, points: [PosePoint], nowMs: Int) -> Bool {
        let holdKey = "\(currentState)->\(transition.to)"

        if let enterCond = transition.enterCondition,
           let confirmCond = transition.confirmCondition,
           let confirmFrames = transition.confirmFrames {
            return processDebounced(
                transition: transition,
                enterCond: enterCond,
                confirmCond: confirmCond,
                confirmFrames: confirmFrames,
                holdKey: holdKey,
                points: points,
                nowMs: nowMs
            )
        }

        if let cond = transition.condition {
            guard evaluateCondition(cond, points: points) else { return false }
            applyTransition(transition, nowMs: nowMs)
            return true
        }

        return false
    }

    private func processDebounced(
        transition: TransitionConfig,
        enterCond: ConditionExpr,
        confirmCond: ConditionExpr,
        confirmFrames: Int,
        holdKey: String,
        points: [PosePoint],
        nowMs: Int
    ) -> Bool {
        let enterMet = evaluateCondition(enterCond, points: points)

        if !enterMet {
            holdCounters[holdKey] = 0
            return false
        }

        let confirmMet = evaluateCondition(confirmCond, points: points)
        let mode = transition.confirmMode ?? "strict"
        var counter = holdCounters[holdKey] ?? 0

        if mode == "soft" {
            counter = confirmMet ? counter + 1 : Swift.max(0, counter - 1)
        } else {
            counter = confirmMet ? counter + 1 : counter
        }

        holdCounters[holdKey] = counter

        if counter >= confirmFrames {
            holdCounters[holdKey] = 0
            applyTransition(transition, nowMs: nowMs)
            return true
        }

        return false
    }

    private func applyTransition(_ transition: TransitionConfig, nowMs: Int) {
        if transition.countRep == true {
            let cooldown = config.stateMachine.repCooldownMs ?? 0
            if nowMs - lastRepTimeMs > cooldown {
                reps += 1
                lastRepTimeMs = nowMs
            }
        }

        currentState = transition.to

        if let fb = transition.feedback {
            feedback = fb
        } else if let stateConfig = config.stateMachine.states[transition.to] {
            feedback = stateConfig.feedback ?? feedback
        }
    }

    // MARK: - Landmark helpers

    private func landmarkCoord(_ name: String, coord: String, points: [PosePoint]) -> Double? {
        guard let idx = Self.landmarkMap[name] else { return nil }
        let raw = idx.rawValue
        guard raw < points.count else { return nil }
        let p = points[raw]
        guard p.visibility >= 0.4 else { return nil }

        switch coord {
        case "x": return p.x
        case "y": return p.y
        case "z": return p.z
        default: return nil
        }
    }

    private func landmarkXY(_ name: String, points: [PosePoint]) -> (Double, Double)? {
        guard let idx = Self.landmarkMap[name] else { return nil }
        let raw = idx.rawValue
        guard raw < points.count else { return nil }
        let p = points[raw]
        guard p.visibility >= 0.4 else { return nil }
        return (p.x, p.y)
    }

    // MARK: - Feedback mapping

    private static let feedbackMap: [String: ExerciseFeedback] = [
        "ready": .ready,
        "raiseArms": .raiseArms,
        "lowerArms": .lowerArms,
        "goodRep": .goodRep,
        "keepElbowsComfortable": .keepElbowsComfortable,
        "complete": .complete
    ]

    var feedbackEnum: ExerciseFeedback {
        Self.feedbackMap[feedback] ?? .ready
    }
}

// MARK: - Progress type (matches ShoulderRoutineTracker.ExerciseProgress)

struct ExerciseProgress {
    var reps: Int = 0
    var feedback: ExerciseFeedback = .ready
}
