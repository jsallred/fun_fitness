import Foundation
import CoreGraphics
import UIKit

enum PoseModelVariant: String, CaseIterable, Identifiable {
    case lite
    case full
    case heavy

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }

    var bundledFileName: String {
        "pose_landmarker_\(rawValue)"
    }
}

enum ActivityType: String {
    case unknown
    case squat
    case jack
    case curl
}

struct PosePoint: Identifiable, Equatable {
    let id = UUID()
    let x: Double
    let y: Double
    let z: Double
    let visibility: Double
}

struct PoseFrame: Equatable {
    var points: [PosePoint] = []
    var timestampMs: Int = 0
    var imageSize: CGSize = .zero

    var isEmpty: Bool { points.isEmpty }
}

struct WorkoutSnapshot: Equatable {
    var activity: ActivityType = .unknown
    var squatReps: Int = 0
    var jackReps: Int = 0
    var kneeAngle: Double?
    var poseFrame: PoseFrame = PoseFrame()
    var multiPersonFrame: MultiPersonPoseFrame = MultiPersonPoseFrame()
    var trackedPeople: [TrackedPerson] = []
    var inferenceFPS: Double = 0
    var model: PoseModelVariant = .lite
}

enum PoseIndex: Int {
    case nose = 0
    case leftEyeInner = 1
    case leftEye = 2
    case leftEyeOuter = 3
    case rightEyeInner = 4
    case rightEye = 5
    case rightEyeOuter = 6
    case leftEar = 7
    case rightEar = 8
    case mouthLeft = 9
    case mouthRight = 10
    case leftShoulder = 11
    case rightShoulder = 12
    case leftElbow = 13
    case rightElbow = 14
    case leftWrist = 15
    case rightWrist = 16
    case leftPinky = 17
    case rightPinky = 18
    case leftIndex = 19
    case rightIndex = 20
    case leftThumb = 21
    case rightThumb = 22
    case leftHip = 23
    case rightHip = 24
    case leftKnee = 25
    case rightKnee = 26
    case leftAnkle = 27
    case rightAnkle = 28
    case leftHeel = 29
    case rightHeel = 30
    case leftFootIndex = 31
    case rightFootIndex = 32
}

enum PoseConnections {
    static let lines: [(Int, Int)] = [
        (11, 12),
        (11, 13), (13, 15),
        (12, 14), (14, 16),
        (11, 23), (12, 24), (23, 24),
        (23, 25), (25, 27), (27, 29), (29, 31),
        (24, 26), (26, 28), (28, 30), (30, 32)
    ]
}
