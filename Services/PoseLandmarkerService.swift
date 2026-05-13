import Foundation
import UIKit
import AVFoundation
import MediaPipeTasksVision

protocol PoseLandmarkerServiceDelegate: AnyObject {
    func poseLandmarkerService(_ service: PoseLandmarkerService,
                               didOutput frame: PoseFrame,
                               multiPersonFrame: MultiPersonPoseFrame,
                               inferenceMs: Double)
}

final class PoseLandmarkerService: NSObject {
    weak var delegate: PoseLandmarkerServiceDelegate?

    private var poseLandmarker: PoseLandmarker?
    private var modelVariant: PoseModelVariant = .lite

    private let inflightQueue = DispatchQueue(label: "pose.landmarker.inflight.queue")
    private var inflightStartTimes: [Int: CFAbsoluteTime] = [:]
    private var inflightImageSizes: [Int: CGSize] = [:]

    private var isProcessingFrame = false

    func configure(model: PoseModelVariant) {
        modelVariant = model

        inflightQueue.sync {
            inflightStartTimes.removeAll()
            inflightImageSizes.removeAll()
            isProcessingFrame = false
        }

        guard let modelPath = Bundle.main.path(forResource: model.bundledFileName, ofType: "task") else {
            print("Missing bundled model: \(model.bundledFileName).task")
            poseLandmarker = nil
            return
        }

        let options = PoseLandmarkerOptions()
        options.runningMode = .liveStream
        options.numPoses = 8
        options.minPoseDetectionConfidence = 0.6
        options.minPosePresenceConfidence = 0.6
        options.minTrackingConfidence = 0.6
        options.baseOptions.modelAssetPath = modelPath
        options.poseLandmarkerLiveStreamDelegate = self

        do {
            poseLandmarker = try PoseLandmarker(options: options)
            print("PoseLandmarker configured with model: \(model.rawValue)")
        } catch {
            poseLandmarker = nil
            print("Failed to create PoseLandmarker: \(error)")
        }
    }

    func process(sampleBuffer: CMSampleBuffer, orientation: UIImage.Orientation, timestampMs: Int) {
        guard let poseLandmarker else { return }

        let shouldProcess: Bool = inflightQueue.sync {
            if isProcessingFrame {
                return false
            } else {
                isProcessingFrame = true
                return true
            }
        }

        guard shouldProcess else { return }

        let imageSize: CGSize
        if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            imageSize = CGSize(
                width: CVPixelBufferGetWidth(pixelBuffer),
                height: CVPixelBufferGetHeight(pixelBuffer)
            )
        } else {
            imageSize = .zero
        }

        do {
            inflightQueue.sync {
                inflightStartTimes[timestampMs] = CFAbsoluteTimeGetCurrent()
                inflightImageSizes[timestampMs] = imageSize
            }

            let image = try MPImage(sampleBuffer: sampleBuffer, orientation: orientation)
            try poseLandmarker.detectAsync(image: image, timestampInMilliseconds: timestampMs)
        } catch {
            inflightQueue.sync {
                inflightStartTimes.removeValue(forKey: timestampMs)
                inflightImageSizes.removeValue(forKey: timestampMs)
                isProcessingFrame = false
            }
            print("Pose detectAsync failed: \(error)")
        }
    }

    private func deduplicateDetections(_ detections: [PersonPoseDetection]) -> [PersonPoseDetection] {
        guard !detections.isEmpty else { return [] }

        let filtered = detections
            .filter { $0.visiblePointCount >= 10 }
            .sorted { $0.qualityScore > $1.qualityScore }

        var kept: [PersonPoseDetection] = []

        for candidate in filtered {
            let duplicate = kept.contains { existing in
                let iou = intersectionOverUnion(candidate.boundingRectNormalized, existing.boundingRectNormalized)

                let centroidDistance = hypot(
                    Double(candidate.centroid.x - existing.centroid.x),
                    Double(candidate.centroid.y - existing.centroid.y)
                )

                return iou > 0.35 || centroidDistance < 0.08
            }

            if !duplicate {
                kept.append(candidate)
            }
        }

        return Array(kept.prefix(8))
    }

    private func intersectionOverUnion(_ a: CGRect, _ b: CGRect) -> Double {
        let intersection = a.intersection(b)
        guard !intersection.isNull else { return 0 }

        let intersectionArea = Double(intersection.width * intersection.height)
        let unionArea = Double(a.width * a.height + b.width * b.height) - intersectionArea

        guard unionArea > 0 else { return 0 }
        return intersectionArea / unionArea
    }
}

extension PoseLandmarkerService: PoseLandmarkerLiveStreamDelegate {
    func poseLandmarker(_ poseLandmarker: PoseLandmarker,
                        didFinishDetection result: PoseLandmarkerResult?,
                        timestampInMilliseconds: Int,
                        error: Error?) {
        var startTime: CFAbsoluteTime?
        var imageSize: CGSize = .zero

        inflightQueue.sync {
            startTime = inflightStartTimes.removeValue(forKey: timestampInMilliseconds)
            imageSize = inflightImageSizes.removeValue(forKey: timestampInMilliseconds) ?? .zero
            isProcessingFrame = false
        }

        if let error {
            print("PoseLandmarker callback error: \(error)")
            return
        }

        let inferenceMs: Double
        if let startTime {
            inferenceMs = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
        } else {
            inferenceMs = 0
        }

        let allLandmarks = result?.landmarks ?? []

        let rawDetections: [PersonPoseDetection] = allLandmarks.map { landmarkList in
            let points = landmarkList.map {
                PosePoint(
                    x: Double($0.x),
                    y: Double($0.y),
                    z: Double($0.z),
                    visibility: $0.visibility?.doubleValue ?? 0.0
                )
            }

            return PersonPoseDetection(
                points: points,
                timestampMs: timestampInMilliseconds,
                imageSize: imageSize
            )
        }

        let dedupedDetections = deduplicateDetections(rawDetections)
        let primaryPoints = dedupedDetections.first?.points ?? []

        let singleFrame = PoseFrame(
            points: primaryPoints,
            timestampMs: timestampInMilliseconds,
            imageSize: imageSize
        )

        let multiFrame = MultiPersonPoseFrame(
            persons: dedupedDetections,
            timestampMs: timestampInMilliseconds,
            imageSize: imageSize
        )

        DispatchQueue.main.async {
            self.delegate?.poseLandmarkerService(
                self,
                didOutput: singleFrame,
                multiPersonFrame: multiFrame,
                inferenceMs: inferenceMs
            )
        }
    }
}
