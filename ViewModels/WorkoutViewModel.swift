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
            resetTrackingState()
        }
    }

    @Published var settings = AppSettings()
    @Published var isShowingSettings = false

    let cameraService = CameraService()
    let sessionManager = SessionManager()

    private let poseService = PoseLandmarkerService()
    private let tracker = ExerciseTracker()
    private let multiPersonTracker = MultiPersonTracker()
    private let faceGallery = SessionFaceGallery()
    private let audioCueService = AudioCueService()

    private var recentInferenceTimes: [CFAbsoluteTime] = []
    private let fpsWindowSize = 15
    private var cancellables = Set<AnyCancellable>()

    var availableRoutines: [RehabRoutine] {
        RehabRoutineLibrary.all
    }

    var appVersionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        if let build, !build.isEmpty {
            return "v\(version) (\(build))"
        } else {
            return "v\(version)"
        }
    }

    var isDemoRoutineActive: Bool {
        sessionManager.routine?.isDemoRoutine == true
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

        settings.objectWillChange
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
        resetTrackingState()
        sessionManager.start(routine: routine)
    }

    func beginQuitRoutine(message: String = "Returning to Home Screen") {
        resetTrackingState()
        sessionManager.beginQuit(message: message)
    }

    func continuePastLogin() {
        sessionManager.continuePastLogin()
    }

    func openSettings() {
        isShowingSettings = true
    }

    private func resetTrackingState() {
        tracker.reset()
        multiPersonTracker.reset()
        faceGallery.reset()

        snapshot.activity = .unknown
        snapshot.squatReps = 0
        snapshot.jackReps = 0
        snapshot.kneeAngle = nil
        snapshot.poseFrame = PoseFrame()
        snapshot.multiPersonFrame = MultiPersonPoseFrame()
        snapshot.trackedPeople = []
    }

    private func updateFPS() {
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

        snapshot.inferenceFPS = fps
    }

    private func updateSinglePersonSnapshot(from frame: PoseFrame) {
        tracker.update(points: frame.points, nowMs: frame.timestampMs)
        snapshot.activity = tracker.activity
        snapshot.squatReps = tracker.squat.reps
        snapshot.jackReps = tracker.jack.reps
        snapshot.kneeAngle = tracker.kneeAngle
    }

    private func updateMultiPersonTracking(from multiFrame: MultiPersonPoseFrame) {
        let previousByID = Dictionary(uniqueKeysWithValues: snapshot.trackedPeople.map { ($0.id, $0) })

        let limitedDetections = Array(multiFrame.persons.prefix(settings.maxVisiblePeople))

        _ = multiPersonTracker.update(
            detections: limitedDetections,
            timestampMs: multiFrame.timestampMs,
            settings: settings,
            gallery: faceGallery
        )

        if let routine = sessionManager.routine, sessionManager.state == .active {
            for person in multiPersonTracker.sortedVisiblePeople() where person.isReadyForExercise {
                if routine.mode == .demo {
                    multiPersonTracker.updateDemoCounters(
                        for: person.id,
                        points: person.points,
                        timestampMs: multiFrame.timestampMs
                    )
                } else if let currentExercise = sessionManager.currentExercise {
                    multiPersonTracker.updateGuidedProgress(
                        for: person.id,
                        exercise: currentExercise,
                        points: person.points
                    )
                }
            }
        }

        let finalTracked = multiPersonTracker.sortedVisiblePeople()
        snapshot.trackedPeople = finalTracked

        playAudioCues(previous: previousByID, current: finalTracked)
    }

    private func playAudioCues(previous: [TrackedPersonID: TrackedPerson], current: [TrackedPerson]) {
        guard settings.audioCuesEnabled else { return }

        var playedReady = false
        var playedRep = false
        var playedInvalid = false

        for person in current {
            let old = previous[person.id]

            if person.isReadyForExercise && old?.isReadyForExercise != true && !playedReady {
                audioCueService.playReadyToBegin()
                playedReady = true
            }

            if old?.isReadyForExercise == true && !person.isReadyForExercise && !playedInvalid {
                audioCueService.playInvalidTracking()
                playedInvalid = true
            }

            if isDemoRoutineActive {
                let oldSquats = old?.exerciseState.demoCounters.squats ?? 0
                let oldJacks = old?.exerciseState.demoCounters.jumpingJacks ?? 0

                if (person.exerciseState.demoCounters.squats > oldSquats ||
                    person.exerciseState.demoCounters.jumpingJacks > oldJacks) && !playedRep {
                    audioCueService.playRepComplete()
                    playedRep = true
                }
            } else {
                let oldReps = old?.exerciseState.guidedProgress.currentReps ?? 0
                let newReps = person.exerciseState.guidedProgress.currentReps

                if newReps > oldReps && !playedRep {
                    audioCueService.playRepComplete()
                    playedRep = true
                }
            }
        }
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
                               multiPersonFrame: MultiPersonPoseFrame,
                               inferenceMs: Double) {
        snapshot.poseFrame = frame
        snapshot.multiPersonFrame = multiPersonFrame

        updateFPS()
        updateSinglePersonSnapshot(from: frame)
        updateMultiPersonTracking(from: multiPersonFrame)

        if !isDemoRoutineActive,
           sessionManager.state == .active,
           let currentExercise = sessionManager.currentExercise {
            let bestProgress = snapshot.trackedPeople
                .filter { $0.isReadyForExercise }
                .map { person in
                    (
                        reps: person.exerciseState.guidedProgress.currentReps,
                        feedback: person.exerciseState.guidedProgress.feedback
                    )
                }
                .max { lhs, rhs in
                    lhs.reps < rhs.reps
                }

            if let bestProgress {
                sessionManager.updateProgress(
                    reps: bestProgress.reps,
                    feedback: bestProgress.feedback
                )
            } else if currentExercise.targetReps == nil {
                sessionManager.updateProgress(reps: 0, feedback: .ready)
            }
        }

        let _ = inferenceMs
    }
}
