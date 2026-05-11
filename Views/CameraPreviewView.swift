//
//  CameraPreviewView.swift
//  fun_fitness
//
//  Created by Joseph Allred on 3/9/26.
//

import SwiftUI
import AVFoundation
import UIKit

struct CameraPreviewView: View {
    let camera: CameraService

    var body: some View {
        #if targetEnvironment(simulator)
        SimulatorCameraPreviewRepresentable(camera: camera)
        #else
        DeviceCameraPreviewRepresentable(session: camera.session)
        #endif
    }
}

#if !targetEnvironment(simulator)
private struct DeviceCameraPreviewRepresentable: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> DevicePreviewView {
        let view = DevicePreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspect
        view.updatePreviewOrientation()
        view.updatePreviewMirroring()
        return view
    }

    func updateUIView(_ uiView: DevicePreviewView, context: Context) {
        uiView.videoPreviewLayer.session = session
        uiView.updatePreviewOrientation()
        uiView.updatePreviewMirroring()
    }
}

final class DevicePreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updatePreviewOrientation()
        updatePreviewMirroring()
    }

    /// Match selfie-style mirroring for the front camera; Simulator / Mac camera often uses back or external devices.
    func updatePreviewMirroring() {
        guard let connection = videoPreviewLayer.connection,
              let session = videoPreviewLayer.session else { return }
        guard let videoInput = session.inputs.compactMap({ $0 as? AVCaptureDeviceInput }).first(where: { $0.device.hasMediaType(.video) }) else { return }
        if connection.isVideoMirroringSupported {
            connection.isVideoMirrored = videoInput.device.position == .front
        }
    }

    func updatePreviewOrientation() {
        guard let connection = videoPreviewLayer.connection else { return }

        let interfaceOrientation = window?.windowScene?.interfaceOrientation ?? .portrait

        if connection.isVideoOrientationSupported {
            switch interfaceOrientation {
            case .portrait:
                connection.videoOrientation = .portrait
            case .portraitUpsideDown:
                connection.videoOrientation = .portraitUpsideDown
            case .landscapeLeft:
                connection.videoOrientation = .landscapeLeft
            case .landscapeRight:
                connection.videoOrientation = .landscapeRight
            default:
                connection.videoOrientation = .portrait
            }
        }
    }
}
#endif

#if targetEnvironment(simulator)
private struct SimulatorCameraPreviewRepresentable: UIViewRepresentable {
    let camera: CameraService

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .black
        attachPreview(into: container)
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        attachPreview(into: uiView)
    }

    private func attachPreview(into container: UIView) {
        guard let preview = camera.simulatorPreviewView else { return }
        guard preview.superview !== container else { return }

        preview.removeFromSuperview()
        preview.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(preview)
        NSLayoutConstraint.activate([
            preview.topAnchor.constraint(equalTo: container.topAnchor),
            preview.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            preview.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            preview.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])
    }
}
#endif
