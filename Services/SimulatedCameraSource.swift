//
//  SimulatedCameraSource.swift
//  fun_fitness
//
//  Simulator-only video source that mirrors the AVCaptureSession output path.
//  Plays a bundled video on a loop (preferred), or falls back to a procedural
//  test pattern so the pose pipeline and on-screen preview both work without
//  a real camera device.
//

#if targetEnvironment(simulator)

import Foundation
import AVFoundation
import CoreImage
import CoreVideo
import QuartzCore
import UIKit

final class SimulatedCameraSource: NSObject {
    weak var delegate: CameraServiceDelegate?
    weak var owningService: CameraService?

    /// View that always reflects the current simulated frame. Hand this to SwiftUI/UIKit.
    let previewView: SimulatedCameraPreviewView = SimulatedCameraPreviewView()

    private let bundledBaseName: String
    private let supportedExtensions: [String] = ["mp4", "mov", "m4v"]

    /// Launch argument: `-SimCameraStreamURL http://...`
    /// Reads from UserDefaults (Apple's standard way to surface launch arguments).
    private let launchArgumentKey: String = "SimCameraStreamURL"
    /// Environment variable: `SIM_CAMERA_STREAM_URL=http://...`
    private let environmentKey: String = "SIM_CAMERA_STREAM_URL"

    private var player: AVPlayer?
    private var playerLooper: AVPlayerLooper?
    private var videoOutput: AVPlayerItemVideoOutput?
    private var playerLayer: AVPlayerLayer?

    private var syntheticPreviewLayer: CALayer?
    private var syntheticPool: CVPixelBufferPool?
    private let ciContext = CIContext(options: nil)

    private var displayLink: CADisplayLink?
    private let deliveryQueue = DispatchQueue(label: "simulator.camera.delivery.queue")

    private var startHostTime: CFTimeInterval = 0
    private var frameIndex: Int = 0
    private var isConfigured = false

    init(bundledBaseName: String = "simulator_sample") {
        self.bundledBaseName = bundledBaseName
        super.init()
    }

    func start() {
        if !isConfigured {
            configure()
            isConfigured = true
        }

        startHostTime = CACurrentMediaTime()
        player?.play()

        if displayLink == nil {
            let link = CADisplayLink(target: self, selector: #selector(handleDisplayLink(_:)))
            link.preferredFramesPerSecond = 30
            link.add(to: .main, forMode: .common)
            displayLink = link
        }
    }

    func stop() {
        player?.pause()
        displayLink?.invalidate()
        displayLink = nil
    }

    private func configure() {
        if let resolved = resolveSourceURL() {
            print("[SimulatedCameraSource] Using \(resolved.isFileURL ? "bundled video" : "live stream") at \(resolved.absoluteString)")
            configurePlayer(url: resolved, isLive: !resolved.isFileURL)
        } else {
            print("""
            [SimulatedCameraSource] No simulator video found. Falling back to a synthetic test pattern.

            Options to feed a real feed into the iOS Simulator:
              1. Drop fun_fitness/Resources/\(bundledBaseName).mp4 (or .mov / .m4v) for a looped recording.
              2. Run scripts/stream_mac_camera.sh and set the launch argument:
                   -SimCameraStreamURL http://127.0.0.1:8080/stream.m3u8
                 (Edit Scheme -> Run -> Arguments -> Arguments Passed On Launch)
              3. Or export SIM_CAMERA_STREAM_URL=http://... in the scheme's environment.
            """)
            configureSynthetic()
        }
    }

    /// Resolves the live/bundled video URL the simulator should play.
    /// Precedence:
    ///   1. `-SimCameraStreamURL <url>` launch argument (via UserDefaults).
    ///   2. `SIM_CAMERA_STREAM_URL` environment variable.
    ///   3. A bundled video named `simulator_sample.{mp4,mov,m4v}` in Resources/.
    private func resolveSourceURL() -> URL? {
        if let raw = UserDefaults.standard.string(forKey: launchArgumentKey)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !raw.isEmpty,
           let url = URL(string: raw) {
            return url
        }

        if let raw = ProcessInfo.processInfo.environment[environmentKey]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !raw.isEmpty,
           let url = URL(string: raw) {
            return url
        }

        return locateBundledVideo()
    }

    private func configurePlayer(url: URL, isLive: Bool) {
        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)

        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ]
        let output = AVPlayerItemVideoOutput(pixelBufferAttributes: pixelBufferAttributes)
        item.add(output)

        let activePlayer: AVPlayer
        if isLive {
            // Live HTTP / HLS stream: let AVPlayer handle buffering. Setting
            // `automaticallyWaitsToMinimizeStalling = false` here causes a permanent
            // stall the moment a segment boundary is hit, because the player drops
            // its rate to 0 and never resumes without an explicit `playImmediately`.
            let livePlayer = AVPlayer(playerItem: item)
            livePlayer.isMuted = true
            activePlayer = livePlayer
        } else {
            // Bundled file: loop seamlessly.
            let queuePlayer = AVQueuePlayer(playerItem: item)
            queuePlayer.isMuted = true
            queuePlayer.actionAtItemEnd = .advance
            self.playerLooper = AVPlayerLooper(player: queuePlayer, templateItem: item)
            activePlayer = queuePlayer
        }

        let layer = AVPlayerLayer(player: activePlayer)
        layer.videoGravity = .resizeAspect
        previewView.installLayer(layer)

        self.player = activePlayer
        self.videoOutput = output
        self.playerLayer = layer
    }

    private func configureSynthetic() {
        let layer = CALayer()
        layer.backgroundColor = UIColor.black.cgColor
        layer.contentsGravity = .resizeAspect
        previewView.installLayer(layer)
        syntheticPreviewLayer = layer
    }

    private func locateBundledVideo() -> URL? {
        for ext in supportedExtensions {
            if let url = Bundle.main.url(forResource: bundledBaseName, withExtension: ext) {
                return url
            }
        }
        return nil
    }

    @objc private func handleDisplayLink(_ link: CADisplayLink) {
        if let videoOutput {
            emitPlayerFrame(at: link.targetTimestamp, videoOutput: videoOutput)
        } else {
            emitSyntheticFrame()
        }
    }

    private func emitPlayerFrame(at hostTime: CFTimeInterval, videoOutput: AVPlayerItemVideoOutput) {
        let itemTime = videoOutput.itemTime(forHostTime: hostTime)
        guard videoOutput.hasNewPixelBuffer(forItemTime: itemTime) else { return }
        guard let pixelBuffer = videoOutput.copyPixelBuffer(forItemTime: itemTime, itemTimeForDisplay: nil) else { return }
        forwardFrame(pixelBuffer: pixelBuffer, presentationTime: itemTime)
    }

    private func emitSyntheticFrame() {
        frameIndex += 1
        guard let pixelBuffer = makeSyntheticPixelBuffer(frameIndex: frameIndex) else { return }

        if let syntheticPreviewLayer {
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            if let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                syntheticPreviewLayer.contents = cgImage
                CATransaction.commit()
            }
        }

        let presentationTime = CMTime(value: Int64(frameIndex), timescale: 30)
        forwardFrame(pixelBuffer: pixelBuffer, presentationTime: presentationTime)
    }

    private func forwardFrame(pixelBuffer: CVPixelBuffer, presentationTime: CMTime) {
        guard let sampleBuffer = makeSampleBuffer(from: pixelBuffer, presentationTime: presentationTime) else { return }
        let elapsedMs = Int(((CACurrentMediaTime() - startHostTime) * 1000.0).rounded())

        deliveryQueue.async { [weak self] in
            guard let self, let owningService = self.owningService else { return }
            self.delegate?.cameraService(owningService, didOutput: sampleBuffer, orientation: .up, timestampMs: elapsedMs)
        }
    }

    private func makeSampleBuffer(from pixelBuffer: CVPixelBuffer, presentationTime: CMTime) -> CMSampleBuffer? {
        var formatDescription: CMVideoFormatDescription?
        let formatStatus = CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescriptionOut: &formatDescription
        )
        guard formatStatus == noErr, let formatDescription else { return nil }

        var timing = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: 30),
            presentationTimeStamp: presentationTime,
            decodeTimeStamp: .invalid
        )

        var sampleBuffer: CMSampleBuffer?
        let status = CMSampleBufferCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: formatDescription,
            sampleTiming: &timing,
            sampleBufferOut: &sampleBuffer
        )
        guard status == noErr else { return nil }
        return sampleBuffer
    }

    private func makeSyntheticPixelBuffer(frameIndex: Int) -> CVPixelBuffer? {
        let width = 720
        let height = 1280

        if syntheticPool == nil {
            let attributes: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height,
                kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any]()
            ]
            var pool: CVPixelBufferPool?
            CVPixelBufferPoolCreate(kCFAllocatorDefault, nil, attributes as CFDictionary, &pool)
            syntheticPool = pool
        }
        guard let pool = syntheticPool else { return nil }

        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pixelBuffer)
        guard let pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue

        guard let context = CGContext(
            data: baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo
        ) else { return nil }

        // CVPixelBuffer rows are top-down; flip CGContext so drawing matches the on-screen orientation.
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)

        drawTestPattern(in: context, size: CGSize(width: width, height: height), frameIndex: frameIndex)

        return pixelBuffer
    }

    private func drawTestPattern(in context: CGContext, size: CGSize, frameIndex: Int) {
        let backgroundColors = [
            UIColor(red: 0.05, green: 0.06, blue: 0.18, alpha: 1).cgColor,
            UIColor(red: 0.20, green: 0.07, blue: 0.36, alpha: 1).cgColor
        ] as CFArray

        if let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: backgroundColors,
            locations: [0, 1]
        ) {
            context.drawLinearGradient(
                gradient,
                start: .zero,
                end: CGPoint(x: 0, y: size.height),
                options: []
            )
        }

        let stripeHeight: CGFloat = 12
        context.setFillColor(UIColor.white.withAlphaComponent(0.06).cgColor)
        var y: CGFloat = 0
        while y < size.height {
            context.fill(CGRect(x: 0, y: y, width: size.width, height: stripeHeight))
            y += stripeHeight * 4
        }

        let t = Double(frameIndex) / 30.0
        let cx = size.width / 2 + CGFloat(sin(t * 1.8)) * (size.width * 0.30)
        let cy = size.height / 2 + CGFloat(cos(t * 1.2)) * (size.height * 0.32)
        let radius: CGFloat = 90

        context.setFillColor(UIColor(red: 0.40, green: 0.85, blue: 0.95, alpha: 1).cgColor)
        context.fillEllipse(in: CGRect(x: cx - radius, y: cy - radius, width: radius * 2, height: radius * 2))

        UIGraphicsPushContext(context)
        defer { UIGraphicsPopContext() }

        let title = "Simulator preview"
        let subtitle = "Add fun_fitness/Resources/\(bundledBaseName).mp4 for a real video feed"
        let footer = "frame \(frameIndex)"

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 48, weight: .bold),
            .foregroundColor: UIColor.white
        ]
        let subtitleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 22, weight: .medium),
            .foregroundColor: UIColor.white.withAlphaComponent(0.80)
        ]
        let footerAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedDigitSystemFont(ofSize: 22, weight: .semibold),
            .foregroundColor: UIColor.white.withAlphaComponent(0.85)
        ]

        NSString(string: title).draw(at: CGPoint(x: 40, y: 60), withAttributes: titleAttrs)
        NSString(string: subtitle).draw(at: CGPoint(x: 40, y: 124), withAttributes: subtitleAttrs)
        NSString(string: footer).draw(at: CGPoint(x: 40, y: size.height - 56), withAttributes: footerAttrs)
    }

    deinit {
        displayLink?.invalidate()
    }
}

/// UIView that hosts whichever CALayer (AVPlayerLayer or plain CALayer) currently
/// represents the simulated camera frame.
final class SimulatedCameraPreviewView: UIView {
    private var hostedLayer: CALayer?

    func installLayer(_ newLayer: CALayer) {
        hostedLayer?.removeFromSuperlayer()
        layer.addSublayer(newLayer)
        newLayer.frame = bounds
        hostedLayer = newLayer
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        hostedLayer?.frame = bounds
        CATransaction.commit()
    }
}

#endif
