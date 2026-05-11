import Foundation
import AVFoundation
import UIKit

protocol CameraServiceDelegate: AnyObject {
    func cameraService(_ service: CameraService, didOutput sampleBuffer: CMSampleBuffer, orientation: UIImage.Orientation, timestampMs: Int)
}

final class CameraService: NSObject {
    let session = AVCaptureSession()

    weak var delegate: CameraServiceDelegate? {
        didSet {
            #if targetEnvironment(simulator)
            simulatorSource?.delegate = delegate
            #endif
        }
    }

    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private let videoOutput = AVCaptureVideoDataOutput()
    private let outputQueue = DispatchQueue(label: "camera.video.output.queue")

    private var isConfigured = false
    /// Updated when the capture session is configured; used for mirroring and MPImage orientation.
    private var activeCameraPosition: AVCaptureDevice.Position = .front

    #if targetEnvironment(simulator)
    /// On the iOS Simulator, AVCaptureDevice never exposes the Mac's camera, so we
    /// substitute a bundled video file (or a procedural test pattern) and emit the
    /// same CMSampleBuffer stream the real capture path would produce.
    private(set) var simulatorSource: SimulatedCameraSource?

    /// The UIView that should be embedded by `CameraPreviewView` on the Simulator.
    var simulatorPreviewView: UIView? {
        simulatorSource?.previewView
    }
    #endif

    override init() {
        super.init()
        #if targetEnvironment(simulator)
        let source = SimulatedCameraSource()
        source.owningService = self
        simulatorSource = source
        #endif
    }

    func start() {
        #if targetEnvironment(simulator)
        simulatorSource?.delegate = delegate
        simulatorSource?.start()
        #else
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            startSession()

        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard granted else { return }
                self?.startSession()
            }

        case .denied, .restricted:
            print("Camera access not granted.")
        @unknown default:
            print("Unknown camera authorization state.")
        }
        #endif
    }

    func stop() {
        #if targetEnvironment(simulator)
        simulatorSource?.stop()
        #else
        sessionQueue.async {
            guard self.session.isRunning else { return }
            self.session.stopRunning()
        }
        #endif
    }

    private func startSession() {
        sessionQueue.async {
            if !self.isConfigured {
                self.configureSession()
            }

            guard self.isConfigured, !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .high

        guard let device = Self.preferredVideoCaptureDevice(),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            print("Unable to configure camera input (no video device available).")
            return
        }

        activeCameraPosition = device.position
        session.addInput(input)

        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ]
        videoOutput.setSampleBufferDelegate(self, queue: outputQueue)

        guard session.canAddOutput(videoOutput) else {
            session.commitConfiguration()
            print("Unable to add video output.")
            return
        }

        session.addOutput(videoOutput)

        let mirrorPreview = device.position == .front
        if let connection = videoOutput.connection(with: .video) {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = currentVideoOrientation()
            }
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = mirrorPreview
            }
        }

        session.commitConfiguration()
        isConfigured = true
    }

    /// Prefer front camera (typical for pose / selfie framing); fall back for Simulator / Mac camera routing.
    private static func preferredVideoCaptureDevice() -> AVCaptureDevice? {
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
            return device
        }
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
            return device
        }
        var types: [AVCaptureDevice.DeviceType] = [.builtInWideAngleCamera, .builtInUltraWideCamera]
        if #available(iOS 17.0, *) {
            types.append(.external)
        }
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: types,
            mediaType: .video,
            position: .unspecified
        )
        return discovery.devices.first
    }

    private func currentInterfaceOrientation() -> UIInterfaceOrientation {
        DispatchQueue.main.sync {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first?
                .interfaceOrientation ?? .portrait
        }
    }

    private func currentVideoOrientation() -> AVCaptureVideoOrientation {
        switch currentInterfaceOrientation() {
        case .portrait:
            return .portrait
        case .portraitUpsideDown:
            return .portraitUpsideDown
        case .landscapeLeft:
            return .landscapeLeft
        case .landscapeRight:
            return .landscapeRight
        default:
            return .portrait
        }
    }

    private func currentUIImageOrientation() -> UIImage.Orientation {
        let isFront = activeCameraPosition == .front
        switch currentInterfaceOrientation() {
        case .portrait:
            return isFront ? .leftMirrored : .right
        case .portraitUpsideDown:
            return isFront ? .rightMirrored : .left
        case .landscapeLeft:
            return isFront ? .upMirrored : .down
        case .landscapeRight:
            return isFront ? .downMirrored : .up
        default:
            return isFront ? .leftMirrored : .right
        }
    }
}

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        if connection.isVideoOrientationSupported {
            connection.videoOrientation = currentVideoOrientation()
        }
        if connection.isVideoMirroringSupported {
            connection.isVideoMirrored = activeCameraPosition == .front
        }

        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let timestampMs = Int((timestamp.seconds * 1000.0).rounded())
        let orientation = currentUIImageOrientation()

        delegate?.cameraService(self, didOutput: sampleBuffer, orientation: orientation, timestampMs: timestampMs)
    }
}
