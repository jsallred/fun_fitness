//
//  WorkoutViewModel.swift
//  fun_fitness
//
//  Created by Joseph Allred on 3/9/26.
//

import Foundation
import SwiftUI
import AVFoundation
import UIKit
import Combine

@MainActor
final class WorkoutViewModel: ObservableObject {
    @Published var snapshot = WorkoutSnapshot()
    @Published var selectedModel: PoseModelVariant = .lite {
        didSet {
            snapshot.model = selectedModel
            poseService.configure(model: selectedModel)
            tracker.reset()
        }
    }

    let cameraService = CameraService()

    private let poseService = PoseLandmarkerService()
    private let tracker = ExerciseTracker()
    private var recentInferenceTimes: [CFAbsoluteTime] = []
    private let fpsWindowSize = 15

    init() {
        snapshot.model = selectedModel
        cameraService.delegate = self
        poseService.delegate = self
        poseService.configure(model: selectedModel)
    }

    func start() {
        cameraService.start()
    }

    func stop() {
        cameraService.stop()
    }
}

extension WorkoutViewModel: CameraServiceDelegate {
    func cameraService(_ service: CameraService,
                       didOutput sampleBuffer: CMSampleBuffer,
                       orientation: UIImage.Orientation,
                       timestampMs: Int) {
        poseService.process(sampleBuffer: sampleBuffer, orientation: orientation, timestampMs: timestampMs)
    }
}

extension WorkoutViewModel: PoseLandmarkerServiceDelegate {
    func poseLandmarkerService(_ service: PoseLandmarkerService,
                               didOutput frame: PoseFrame,
                               inferenceMs: Double) {
        tracker.update(points: frame.points, nowMs: frame.timestampMs)

        let now = CFAbsoluteTimeGetCurrent()
        recentInferenceTimes.append(now)
        if recentInferenceTimes.count > fpsWindowSize {
            recentInferenceTimes.removeFirst()
        }

        var fps = 0.0
        if recentInferenceTimes.count >= 2 {
            let duration = recentInferenceTimes.last! - recentInferenceTimes.first!
            if duration > 0 {
                fps = Double(recentInferenceTimes.count - 1) / duration
            }
        }

        snapshot.poseFrame = frame
        snapshot.inferenceFPS = fps
        snapshot.activity = tracker.activity
        snapshot.squatReps = tracker.squat.reps
        snapshot.jackReps = tracker.jack.reps
        snapshot.kneeAngle = tracker.kneeAngle
    }
}
