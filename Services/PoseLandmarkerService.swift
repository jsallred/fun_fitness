//
//  PoseLandmarkerService.swift
//  fun_fitness
//
//  Created by Joseph Allred on 3/9/26.
//

import Foundation
import UIKit
import AVFoundation
import MediaPipeTasksVision

protocol PoseLandmarkerServiceDelegate: AnyObject {
    func poseLandmarkerService(_ service: PoseLandmarkerService,
                               didOutput frame: PoseFrame,
                               inferenceMs: Double)
}

final class PoseLandmarkerService: NSObject {
    weak var delegate: PoseLandmarkerServiceDelegate?

    private var poseLandmarker: PoseLandmarker?
    private var modelVariant: PoseModelVariant = .lite
    private var inflightStartTime: CFAbsoluteTime = 0
    private var lastImageSize: CGSize = .zero

    func configure(model: PoseModelVariant) {
        modelVariant = model

        guard let modelPath = Bundle.main.path(forResource: model.bundledFileName, ofType: "task") else {
            print("Missing bundled model: \(model.bundledFileName).task")
            poseLandmarker = nil
            return
        }

        let options = PoseLandmarkerOptions()
        options.runningMode = .liveStream
        options.numPoses = 1
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

        if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            lastImageSize = CGSize(
                width: CVPixelBufferGetWidth(pixelBuffer),
                height: CVPixelBufferGetHeight(pixelBuffer)
            )
        }

        do {
            inflightStartTime = CFAbsoluteTimeGetCurrent()
            let image = try MPImage(sampleBuffer: sampleBuffer, orientation: orientation)
            try poseLandmarker.detectAsync(image: image, timestampInMilliseconds: timestampMs)
        } catch {
            print("Pose detectAsync failed: \(error)")
        }
    }
}

extension PoseLandmarkerService: PoseLandmarkerLiveStreamDelegate {
    func poseLandmarker(_ poseLandmarker: PoseLandmarker,
                        didFinishDetection result: PoseLandmarkerResult?,
                        timestampInMilliseconds: Int,
                        error: Error?) {
        if let error {
            print("PoseLandmarker callback error: \(error)")
            return
        }

        let inferenceMs = (CFAbsoluteTimeGetCurrent() - inflightStartTime) * 1000.0

        let landmarks = result?.landmarks.first ?? []
        let points = landmarks.map {
            PosePoint(
                x: Double($0.x),
                y: Double($0.y),
                z: Double($0.z),
                visibility: $0.visibility?.doubleValue ?? 0.0
            )
        }

        let frame = PoseFrame(
            points: points,
            timestampMs: timestampInMilliseconds,
            imageSize: lastImageSize
        )

        DispatchQueue.main.async {
            self.delegate?.poseLandmarkerService(self, didOutput: frame, inferenceMs: inferenceMs)
        }
    }
}
