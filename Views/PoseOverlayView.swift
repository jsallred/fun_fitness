//
//  PoseOverlayView.swift
//  fun_fitness
//
//  Created by Joseph Allred on 3/9/26.
//

import SwiftUI
import AVFoundation

struct PoseOverlayView: View {
    let frame: PoseFrame

    var body: some View {
        GeometryReader { _ in
            Canvas { context, size in
                guard !frame.points.isEmpty else { return }

                let videoRect = fittedVideoRect(in: size)

                for (startIndex, endIndex) in PoseConnections.lines {
                    guard startIndex < frame.points.count, endIndex < frame.points.count else { continue }

                    let a = pointToCGPoint(frame.points[startIndex], in: videoRect)
                    let b = pointToCGPoint(frame.points[endIndex], in: videoRect)

                    var path = Path()
                    path.move(to: a)
                    path.addLine(to: b)
                    context.stroke(path, with: .color(.green), lineWidth: 3)
                }

                for point in frame.points where point.visibility > 0.35 {
                    let p = pointToCGPoint(point, in: videoRect)
                    let rect = CGRect(x: p.x - 4, y: p.y - 4, width: 8, height: 8)
                    context.fill(Path(ellipseIn: rect), with: .color(.yellow))
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func fittedVideoRect(in canvasSize: CGSize) -> CGRect {
        let imageSize = frame.imageSize == .zero ? canvasSize : frame.imageSize
        return AVMakeRect(aspectRatio: imageSize, insideRect: CGRect(origin: .zero, size: canvasSize))
    }

    private func pointToCGPoint(_ point: PosePoint, in rect: CGRect) -> CGPoint {
        CGPoint(
            x: rect.minX + point.x * rect.width,
            y: rect.minY + point.y * rect.height
        )
    }
}
