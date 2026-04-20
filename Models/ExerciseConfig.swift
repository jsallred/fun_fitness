import Foundation

// MARK: - Top-level exercise definition

struct ExerciseConfig: Codable, Identifiable {
    let id: String
    let displayName: String
    let instructions: String
    let requiredLandmarks: [String]
    let variables: [String: VariableConfig]?
    let stateMachine: StateMachineConfig
}

// MARK: - Variables (named intermediate values computed per frame)

struct VariableConfig: Codable {
    let expr: NumericExpr
    let smoothing: SmoothingConfig?
}

struct SmoothingConfig: Codable {
    let type: String // "ema"
    let alpha: Double
}

// MARK: - Numeric expressions (recursive, evaluated against pose data)

enum NumericExpr: Codable {
    case literal(Double)
    case landmark(point: String, coord: String)
    case angle(points: [String])
    case variable(name: String)
    case abs(NumericExpr)
    case min([NumericExpr])
    case max([NumericExpr])
    case add(NumericExpr, NumericExpr)
    case sub(NumericExpr, NumericExpr)
    case mul(NumericExpr, NumericExpr)
    case div(NumericExpr, NumericExpr)
    case clamp01(NumericExpr)

    init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode(Double.self) {
            self = .literal(value)
            return
        }

        let container = try decoder.container(keyedBy: DynamicKey.self)

        if let point = try container.decodeIfPresent(String.self, forKey: .init("landmark")),
           let coord = try container.decodeIfPresent(String.self, forKey: .init("coord")) {
            self = .landmark(point: point, coord: coord)
            return
        }

        if let points = try container.decodeIfPresent([String].self, forKey: .init("angle")) {
            self = .angle(points: points)
            return
        }

        if let name = try container.decodeIfPresent(String.self, forKey: .init("var")) {
            self = .variable(name: name)
            return
        }

        if let inner = try container.decodeIfPresent(NumericExpr.self, forKey: .init("abs")) {
            self = .abs(inner)
            return
        }

        if let inner = try container.decodeIfPresent(NumericExpr.self, forKey: .init("clamp01")) {
            self = .clamp01(inner)
            return
        }

        if let pair = try container.decodeIfPresent([NumericExpr].self, forKey: .init("min")) {
            self = .min(pair)
            return
        }

        if let pair = try container.decodeIfPresent([NumericExpr].self, forKey: .init("max")) {
            self = .max(pair)
            return
        }

        if let pair = try container.decodeIfPresent([NumericExpr].self, forKey: .init("add")),
           pair.count == 2 {
            self = .add(pair[0], pair[1])
            return
        }

        if let pair = try container.decodeIfPresent([NumericExpr].self, forKey: .init("sub")),
           pair.count == 2 {
            self = .sub(pair[0], pair[1])
            return
        }

        if let pair = try container.decodeIfPresent([NumericExpr].self, forKey: .init("mul")),
           pair.count == 2 {
            self = .mul(pair[0], pair[1])
            return
        }

        if let pair = try container.decodeIfPresent([NumericExpr].self, forKey: .init("div")),
           pair.count == 2 {
            self = .div(pair[0], pair[1])
            return
        }

        throw DecodingError.dataCorrupted(
            .init(codingPath: decoder.codingPath, debugDescription: "Unrecognized numeric expression")
        )
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .literal(let v):
            var c = encoder.singleValueContainer()
            try c.encode(v)
        case .landmark(let point, let coord):
            var c = encoder.container(keyedBy: DynamicKey.self)
            try c.encode(point, forKey: .init("landmark"))
            try c.encode(coord, forKey: .init("coord"))
        case .angle(let points):
            var c = encoder.container(keyedBy: DynamicKey.self)
            try c.encode(points, forKey: .init("angle"))
        case .variable(let name):
            var c = encoder.container(keyedBy: DynamicKey.self)
            try c.encode(name, forKey: .init("var"))
        case .abs(let inner):
            var c = encoder.container(keyedBy: DynamicKey.self)
            try c.encode(inner, forKey: .init("abs"))
        case .clamp01(let inner):
            var c = encoder.container(keyedBy: DynamicKey.self)
            try c.encode(inner, forKey: .init("clamp01"))
        case .min(let exprs):
            var c = encoder.container(keyedBy: DynamicKey.self)
            try c.encode(exprs, forKey: .init("min"))
        case .max(let exprs):
            var c = encoder.container(keyedBy: DynamicKey.self)
            try c.encode(exprs, forKey: .init("max"))
        case .add(let a, let b):
            var c = encoder.container(keyedBy: DynamicKey.self)
            try c.encode([a, b], forKey: .init("add"))
        case .sub(let a, let b):
            var c = encoder.container(keyedBy: DynamicKey.self)
            try c.encode([a, b], forKey: .init("sub"))
        case .mul(let a, let b):
            var c = encoder.container(keyedBy: DynamicKey.self)
            try c.encode([a, b], forKey: .init("mul"))
        case .div(let a, let b):
            var c = encoder.container(keyedBy: DynamicKey.self)
            try c.encode([a, b], forKey: .init("div"))
        }
    }
}

// MARK: - Condition expressions (boolean, evaluated against pose data)

enum ConditionExpr: Codable {
    case gt(NumericExpr, NumericExpr)
    case lt(NumericExpr, NumericExpr)
    case gte(NumericExpr, NumericExpr)
    case lte(NumericExpr, NumericExpr)
    case and([ConditionExpr])
    case or([ConditionExpr])
    case not(ConditionExpr)

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicKey.self)

        if let pair = try container.decodeIfPresent([NumericExpr].self, forKey: .init("gt")),
           pair.count == 2 {
            self = .gt(pair[0], pair[1])
            return
        }

        if let pair = try container.decodeIfPresent([NumericExpr].self, forKey: .init("lt")),
           pair.count == 2 {
            self = .lt(pair[0], pair[1])
            return
        }

        if let pair = try container.decodeIfPresent([NumericExpr].self, forKey: .init("gte")),
           pair.count == 2 {
            self = .gte(pair[0], pair[1])
            return
        }

        if let pair = try container.decodeIfPresent([NumericExpr].self, forKey: .init("lte")),
           pair.count == 2 {
            self = .lte(pair[0], pair[1])
            return
        }

        if let inner = try container.decodeIfPresent(ConditionExpr.self, forKey: .init("not")) {
            self = .not(inner)
            return
        }

        if let list = try container.decodeIfPresent([ConditionExpr].self, forKey: .init("and")) {
            self = .and(list)
            return
        }

        if let list = try container.decodeIfPresent([ConditionExpr].self, forKey: .init("or")) {
            self = .or(list)
            return
        }

        throw DecodingError.dataCorrupted(
            .init(codingPath: decoder.codingPath, debugDescription: "Unrecognized condition expression")
        )
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: DynamicKey.self)
        switch self {
        case .gt(let a, let b):
            try c.encode([a, b], forKey: .init("gt"))
        case .lt(let a, let b):
            try c.encode([a, b], forKey: .init("lt"))
        case .gte(let a, let b):
            try c.encode([a, b], forKey: .init("gte"))
        case .lte(let a, let b):
            try c.encode([a, b], forKey: .init("lte"))
        case .and(let list):
            try c.encode(list, forKey: .init("and"))
        case .or(let list):
            try c.encode(list, forKey: .init("or"))
        case .not(let inner):
            try c.encode(inner, forKey: .init("not"))
        }
    }
}

// MARK: - State machine config

struct StateMachineConfig: Codable {
    let initialState: String
    let repCooldownMs: Int?
    let guard_: ConditionExpr?
    let guardFeedback: String?
    let states: [String: StateConfig]

    enum CodingKeys: String, CodingKey {
        case initialState, repCooldownMs, states, guardFeedback
        case guard_ = "guard"
    }
}

struct StateConfig: Codable {
    let feedback: String?
    let transitions: [TransitionConfig]
}

struct TransitionConfig: Codable {
    let to: String
    let condition: ConditionExpr?
    let enterCondition: ConditionExpr?
    let confirmCondition: ConditionExpr?
    let confirmFrames: Int?
    let confirmMode: String?
    let countRep: Bool?
    let feedback: String?
}

// MARK: - Routine config

struct RoutineConfig: Codable, Identifiable {
    let id: String
    let name: String
    let exercises: [RoutineExerciseRef]
}

struct RoutineExerciseRef: Codable {
    let exerciseId: String
    let targetReps: Int
}

// MARK: - Dynamic coding key for heterogeneous JSON

struct DynamicKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init(_ string: String) {
        self.stringValue = string
        self.intValue = nil
    }

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
}
