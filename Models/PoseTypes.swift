//
//  PoseTypes.swift
//  fun_fitness
//
//  Created by Joseph Allred on 3/9/26.
//

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
    var inferenceFPS: Double = 0
    var model: PoseModelVariant = .lite
}

enum PoseIndex: Int {
    case nose = 0
    case leftShoulder = 11
    case rightShoulder = 12
    case leftElbow = 13
    case rightElbow = 14
    case leftWrist = 15
    case rightWrist = 16
    case leftHip = 23
    case rightHip = 24
    case leftKnee = 25
    case rightKnee = 26
    case leftAnkle = 27
    case rightAnkle = 28
}

enum PoseConnections {
    static let lines: [(Int, Int)] = [
        (11, 12),
        (11, 13), (13, 15),
        (12, 14), (14, 16),
        (11, 23), (12, 24), (23, 24),
        (23, 25), (25, 27),
        (24, 26), (26, 28)
    ]
}
