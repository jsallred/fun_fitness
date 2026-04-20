import Foundation
import CoreGraphics

final class MultiPersonTracker {
    private(set) var trackedPeople: [TrackedPersonID: TrackedPerson] = [:]

    private var nextID: Int = 1
    private let recognitionFrameThreshold = 8
    private let maxMissingFrames = 45

    private var exerciseEngines: [TrackedPersonID: TrackedPersonExerciseEngine] = [:]

    func reset() {
        trackedPeople.removeAll()
        exerciseEngines.removeAll()
        nextID = 1
    }

    func update(
        detections: [PersonPoseDetection],
        timestampMs: Int,
        settings: AppSettings,
        gallery: SessionFaceGallery? = nil
    ) -> [TrackedPerson] {
        if !settings.multiPersonTrackingEnabled {
            trackedPeople.removeAll()
            exerciseEngines.removeAll()

            if let first = detections.first {
                let id = TrackedPersonID(rawValue: 1)
                var person = makeNewTrackedPerson(from: first, id: id)
                person.visualState = .recognized
                trackedPeople[id] = person
                exerciseEngines[id] = TrackedPersonExerciseEngine()
                nextID = 2
            }

            return visibleTrackedPeople()
        }

        var unmatchedTrackIDs = Set(trackedPeople.keys)
        var matchedTrackIDs = Set<TrackedPersonID>()

        for detection in detections {
            if let matchedID = bestMatchingTrackID(for: detection, among: unmatchedTrackIDs) {
                updateExistingTrack(id: matchedID, with: detection, timestampMs: timestampMs)
                unmatchedTrackIDs.remove(matchedID)
                matchedTrackIDs.insert(matchedID)
            } else if settings.faceAssistedRecognitionEnabled,
                      let gallery,
                      let matchedID = matchUsingFaceHint(for: detection, gallery: gallery, excluding: matchedTrackIDs) {
                updateExistingTrack(id: matchedID, with: detection, timestampMs: timestampMs)
                unmatchedTrackIDs.remove(matchedID)
                matchedTrackIDs.insert(matchedID)
            } else {
                let newID = TrackedPersonID(rawValue: nextID)
                nextID += 1

                let newPerson = makeNewTrackedPerson(from: detection, id: newID)
                trackedPeople[newID] = newPerson
                exerciseEngines[newID] = TrackedPersonExerciseEngine()
                matchedTrackIDs.insert(newID)
            }
        }

        for id in unmatchedTrackIDs {
            guard var person = trackedPeople[id] else { continue }
            person.missingFrameCount += 1
            person.lastSeenMs = timestampMs
            person.readinessScore = max(0, person.readinessScore * 0.90)
            trackedPeople[id] = person
        }

        pruneLostTracks()
        return visibleTrackedPeople()
    }

    func updateDemoCounters(for trackedID: TrackedPersonID, points: [PosePoint], timestampMs: Int) {
        guard var person = trackedPeople[trackedID],
              let engine = exerciseEngines[trackedID],
              person.isReadyForExercise else { return }

        var state = person.exerciseState
        engine.updateDemo(points: points, timestampMs: timestampMs, state: &state)
        person.exerciseState = state
        trackedPeople[trackedID] = person
    }

    func updateGuidedProgress(for trackedID: TrackedPersonID, exercise: RehabExercise, points: [PosePoint]) {
        guard var person = trackedPeople[trackedID],
              let engine = exerciseEngines[trackedID],
              person.isReadyForExercise else { return }

        var progress = person.exerciseState.guidedProgress
        engine.updateGuided(points: points, exercise: exercise, progress: &progress)

        person.exerciseState.guidedProgress = progress
        person.exerciseState.currentExerciseName = exercise.type.displayName
        person.exerciseState.currentExerciseTarget = exercise.targetReps
        trackedPeople[trackedID] = person
    }

    func sortedVisiblePeople() -> [TrackedPerson] {
        visibleTrackedPeople().sorted { lhs, rhs in
            lhs.id.rawValue < rhs.id.rawValue
        }
    }

    private func visibleTrackedPeople() -> [TrackedPerson] {
        trackedPeople.values
            .filter { $0.missingFrameCount < maxMissingFrames }
            .sorted { $0.id.rawValue < $1.id.rawValue }
    }

    private func makeNewTrackedPerson(from detection: PersonPoseDetection, id: TrackedPersonID) -> TrackedPerson {
        let initialReadiness = readinessScore(for: detection.points)

        return TrackedPerson(
            id: id,
            visualState: .tentative,
            points: detection.points,
            timestampMs: detection.timestampMs,
            imageSize: detection.imageSize,
            firstSeenMs: detection.timestampMs,
            lastSeenMs: detection.timestampMs,
            stableFrameCount: 1,
            missingFrameCount: 0,
            faceProfileID: nil,
            lastKnownCentroid: detection.centroid,
            lastKnownBoundingRect: detection.boundingRectNormalized,
            readinessScore: initialReadiness * 0.45,
            exerciseState: TrackedPersonExerciseState()
        )
    }

    private func updateExistingTrack(id: TrackedPersonID, with detection: PersonPoseDetection, timestampMs: Int) {
        guard var person = trackedPeople[id] else { return }

        person.points = detection.points
        person.timestampMs = timestampMs
        person.imageSize = detection.imageSize
        person.lastSeenMs = timestampMs
        person.lastKnownCentroid = detection.centroid
        person.lastKnownBoundingRect = detection.boundingRectNormalized
        person.missingFrameCount = 0
        person.stableFrameCount += 1

        let rawReadiness = readinessScore(for: detection.points)

        if rawReadiness > person.readinessScore {
            person.readinessScore = person.readinessScore + (rawReadiness - person.readinessScore) * 0.22
        } else {
            person.readinessScore = person.readinessScore + (rawReadiness - person.readinessScore) * 0.30
        }

        if person.visualState == .tentative && person.stableFrameCount >= recognitionFrameThreshold {
            person.visualState = .recognized
        }

        trackedPeople[id] = person
    }

    private func pruneLostTracks() {
        let lostIDs = trackedPeople.values
            .filter { $0.missingFrameCount >= maxMissingFrames }
            .map(\.id)

        for id in lostIDs {
            trackedPeople.removeValue(forKey: id)
            exerciseEngines.removeValue(forKey: id)
        }
    }

    private func bestMatchingTrackID(
        for detection: PersonPoseDetection,
        among candidateIDs: Set<TrackedPersonID>
    ) -> TrackedPersonID? {
        let candidates = candidateIDs.compactMap { trackedPeople[$0] }
        guard !candidates.isEmpty else { return nil }

        let detectionCentroid = detection.centroid
        let detectionRect = detection.boundingRectNormalized

        let scored: [(TrackedPersonID, Double)] = candidates.map { person in
            let centroidDistance = hypot(
                Double(person.lastKnownCentroid.x - detectionCentroid.x),
                Double(person.lastKnownCentroid.y - detectionCentroid.y)
            )

            let widthDelta = abs(Double(person.lastKnownBoundingRect.width - detectionRect.width))
            let heightDelta = abs(Double(person.lastKnownBoundingRect.height - detectionRect.height))
            let sizeDelta = widthDelta + heightDelta

            let score = centroidDistance + (sizeDelta * 0.75)
            return (person.id, score)
        }

        guard let best = scored.min(by: { $0.1 < $1.1 }) else { return nil }
        return best.1 < 0.22 ? best.0 : nil
    }

    private func matchUsingFaceHint(
        for detection: PersonPoseDetection,
        gallery: SessionFaceGallery,
        excluding excluded: Set<TrackedPersonID>
    ) -> TrackedPersonID? {
        let _ = detection
        let _ = gallery
        let _ = excluded
        return nil
    }

    private func readinessScore(for points: [PosePoint]) -> Double {
        func visibility(_ index: PoseIndex) -> Double {
            let raw = index.rawValue
            guard raw < points.count else { return 0 }
            return points[raw].visibility
        }

        func average(_ values: [Double]) -> Double {
            guard !values.isEmpty else { return 0 }
            return values.reduce(0, +) / Double(values.count)
        }

        let headScore = average([
            visibility(.nose),
            visibility(.leftEar),
            visibility(.rightEar)
        ])

        let shoulderScore = average([
            visibility(.leftShoulder),
            visibility(.rightShoulder)
        ])

        let hipScore = average([
            visibility(.leftHip),
            visibility(.rightHip)
        ])

        let kneeScore = average([
            visibility(.leftKnee),
            visibility(.rightKnee)
        ])

        let ankleScore = average([
            visibility(.leftAnkle),
            visibility(.rightAnkle)
        ])

        let fullBodyMinimum = min(headScore, shoulderScore, hipScore, kneeScore, ankleScore)
        let visibleCount = points.filter { $0.visibility > 0.45 }.count
        let visibleCoverage = min(Double(visibleCount) / 18.0, 1.0)

        let weighted =
            (headScore * 0.15) +
            (shoulderScore * 0.20) +
            (hipScore * 0.22) +
            (kneeScore * 0.21) +
            (ankleScore * 0.16) +
            (visibleCoverage * 0.06)

        // Less punishing than before, but still requires all major regions.
        let gateBoost = 0.55 + (fullBodyMinimum * 0.45)
        let gated = weighted * gateBoost

        // Easier to reach green when the whole body is genuinely visible.
        let normalized = max(0, min(1, (gated - 0.22) / 0.48))

        return normalized
    }
}
