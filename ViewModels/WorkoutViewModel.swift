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
            currentExerciseTracker?.reset()
        }
    }

    let cameraService = CameraService()
    let sessionManager = SessionManager()

    private let poseService = PoseLandmarkerService()
    private let tracker = ExerciseTracker()
    private let configLoader = ExerciseConfigLoader.shared

    private var currentExerciseTracker: ConfigurableExerciseTracker?

    private var recentInferenceTimes: [CFAbsoluteTime] = []
    private let fpsWindowSize = 15
    private var cancellables = Set<AnyCancellable>()

    private(set) var availableRoutines: [RehabRoutine] = []

    init() {
        snapshot.model = selectedModel
        cameraService.delegate = self
        poseService.delegate = self
        poseService.configure(model: selectedModel)

        configLoader.loadAll()
        availableRoutines = configLoader.buildRehabRoutines()

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
        sessionManager.start(routine: routine)
        loadTrackerForCurrentExercise()
    }

    func endRoutine() {
        tracker.reset()
        currentExerciseTracker = nil
        sessionManager.endSession()
    }

    private func loadTrackerForCurrentExercise() {
        guard let exercise = sessionManager.currentExercise,
              let config = configLoader.exerciseConfig(for: exercise.configId) else {
            currentExerciseTracker = nil
            return
        }
        currentExerciseTracker = ConfigurableExerciseTracker(config: config)
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

        if sessionManager.state == .active,
           let exerciseTracker = currentExerciseTracker {
            let progress = exerciseTracker.update(points: frame.points, nowMs: frame.timestampMs)
            let previousIndex = sessionManager.currentExerciseIndex
            sessionManager.updateProgress(reps: progress.reps, feedback: progress.feedback)

            if sessionManager.currentExerciseIndex != previousIndex ||
               sessionManager.state == .transitioning {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in
                    self?.loadTrackerForCurrentExercise()
                }
            }
        }
    }
}
