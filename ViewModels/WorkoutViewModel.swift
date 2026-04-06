import Foundation
import SwiftUI
import Combine
import AVFoundation
import UIKit

@MainActor
final class WorkoutViewModel: ObservableObject {
    @Published var snapshot = WorkoutSnapshot()
    @Published var selectedModel: PoseModelVariant = .lite {
        didSet {
            snapshot.model = selectedModel
            poseService.configure(model: selectedModel)
            tracker.reset()
            shoulderTracker.reset()
        }
    }

    let cameraService = CameraService()
    let sessionManager = SessionManager()

    private let poseService = PoseLandmarkerService()
    private let tracker = ExerciseTracker()
    private let shoulderTracker = ShoulderRoutineTracker()

    private var recentInferenceTimes: [CFAbsoluteTime] = []
    private let fpsWindowSize = 15
    private var cancellables = Set<AnyCancellable>()

    let betaShouldersRoutine = RehabRoutine(
        name: "Beta Shoulders 1.0",
        exercises: [
            RehabExercise(type: .shoulderFlexion, targetReps: 5),
            RehabExercise(type: .shoulderAbduction, targetReps: 5),
            RehabExercise(type: .shoulderExternalRotation, targetReps: 5)
        ]
    )

    let betaMobilityRoutine = RehabRoutine(
        name: "Beta Mobility 1.0",
        exercises: [
            RehabExercise(type: .shoulderFlexion, targetReps: 5),
            RehabExercise(type: .shoulderScaption, targetReps: 5),
            RehabExercise(type: .shoulderAbduction, targetReps: 5)
        ]
    )

    let betaRotatorCuffRoutine = RehabRoutine(
        name: "Beta Rotator Cuff 1.0",
        exercises: [
            RehabExercise(type: .shoulderExternalRotation, targetReps: 5),
            RehabExercise(type: .shoulderScaption, targetReps: 5),
            RehabExercise(type: .shoulderFlexion, targetReps: 5)
        ]
    )

    var availableRoutines: [RehabRoutine] {
        [
            betaShouldersRoutine,
            betaMobilityRoutine,
            betaRotatorCuffRoutine
        ]
    }

    init() {
        snapshot.model = selectedModel
        cameraService.delegate = self
        poseService.delegate = self
        poseService.configure(model: selectedModel)

        sessionManager.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    func startCamera() {
        cameraService.start()
    }

    func stopCamera() {
        cameraService.stop()
    }

    func startRoutine(_ routine: RehabRoutine) {
        tracker.reset()
        shoulderTracker.reset()
        sessionManager.start(routine: routine)
    }

    func endRoutine() {
        tracker.reset()
        shoulderTracker.reset()
        sessionManager.endSession()
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

        if let currentExercise = sessionManager.currentExercise,
           sessionManager.state == .active {
            let progress = shoulderTracker.update(for: currentExercise.type, points: frame.points)
            sessionManager.updateProgress(reps: progress.reps, feedback: progress.feedback)
        }
    }
}
