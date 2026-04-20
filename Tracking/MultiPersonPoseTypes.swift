import Foundation
import CoreGraphics

struct PersonPoseDetection: Identifiable, Equatable {
    let id = UUID()
    let points: [PosePoint]
    let timestampMs: Int
    let imageSize: CGSize

    var isEmpty: Bool {
        points.isEmpty
    }

    var visiblePoints: [PosePoint] {
        points.filter { $0.visibility > 0.35 }
    }

    var visiblePointCount: Int {
        visiblePoints.count
    }

    var averageVisibility: Double {
        let pts = visiblePoints
        guard !pts.isEmpty else { return 0 }
        return pts.map(\.visibility).reduce(0, +) / Double(pts.count)
    }

    var centroid: CGPoint {
        let pts = visiblePoints
        guard !pts.isEmpty else { return .zero }

        let avgX = pts.map(\.x).reduce(0, +) / Double(pts.count)
        let avgY = pts.map(\.y).reduce(0, +) / Double(pts.count)
        return CGPoint(x: avgX, y: avgY)
    }

    var boundingRectNormalized: CGRect {
        let pts = visiblePoints
        guard !pts.isEmpty else { return .zero }

        let xs = pts.map(\.x)
        let ys = pts.map(\.y)

        let minX = xs.min() ?? 0
        let maxX = xs.max() ?? 0
        let minY = ys.min() ?? 0
        let maxY = ys.max() ?? 0

        return CGRect(
            x: minX,
            y: minY,
            width: max(0.001, maxX - minX),
            height: max(0.001, maxY - minY)
        )
    }

    var bodyScaleHint: Double {
        let rect = boundingRectNormalized
        return Double(rect.width + rect.height)
    }

    var qualityScore: Double {
        let rect = boundingRectNormalized
        let area = Double(rect.width * rect.height)
        return (Double(visiblePointCount) * 2.0) + (averageVisibility * 10.0) + area
    }
}

struct MultiPersonPoseFrame: Equatable {
    var persons: [PersonPoseDetection] = []
    var timestampMs: Int = 0
    var imageSize: CGSize = .zero

    var isEmpty: Bool {
        persons.isEmpty
    }
}

struct TrackedPersonID: Hashable, Equatable, Codable, CustomStringConvertible {
    let rawValue: Int

    var description: String {
        "id_\(rawValue)"
    }
}

enum TrackingVisualState: String, Equatable, Codable {
    case tentative
    case recognized
}

struct TrackedPersonHUD: Identifiable, Equatable {
    let id: TrackedPersonID
    let title: String
    let subtitle: String
    let anchor: CGPoint
    let visualState: TrackingVisualState
}

struct TrackedPerson: Identifiable, Equatable {
    var id: TrackedPersonID
    var visualState: TrackingVisualState
    var points: [PosePoint]
    var timestampMs: Int
    var imageSize: CGSize

    var firstSeenMs: Int
    var lastSeenMs: Int
    var stableFrameCount: Int
    var missingFrameCount: Int

    var faceProfileID: UUID?
    var lastKnownCentroid: CGPoint
    var lastKnownBoundingRect: CGRect

    var readinessScore: Double
    var exerciseState: TrackedPersonExerciseState

    var displayName: String {
        id.description
    }

    var isReadyForExercise: Bool {
        readinessScore >= 0.78
    }

    var readinessLabel: String {
        switch readinessScore {
        case 0.78...:
            return "Ready"
        case 0.55..<0.78:
            return "Almost ready"
        case 0.30..<0.55:
            return "Get full body in frame"
        default:
            return "Not ready"
        }
    }

    var readinessPercentText: String {
        "\(Int((max(0, min(1, readinessScore)) * 100).rounded()))%"
    }

    var hud: TrackedPersonHUD {
        TrackedPersonHUD(
            id: id,
            title: displayName,
            subtitle: "\(readinessLabel) • \(readinessPercentText) • \(exerciseState.hudSubtitle)",
            anchor: hudAnchor,
            visualState: visualState
        )
    }

    var hudAnchor: CGPoint {
        let rect = normalizedBoundingRect
        return CGPoint(x: rect.minX, y: max(0.02, rect.minY - 0.05))
    }

    var normalizedBoundingRect: CGRect {
        let visible = points.filter { $0.visibility > 0.35 }
        guard !visible.isEmpty else { return lastKnownBoundingRect }

        let xs = visible.map(\.x)
        let ys = visible.map(\.y)

        let minX = xs.min() ?? Double(lastKnownBoundingRect.minX)
        let maxX = xs.max() ?? Double(lastKnownBoundingRect.maxX)
        let minY = ys.min() ?? Double(lastKnownBoundingRect.minY)
        let maxY = ys.max() ?? Double(lastKnownBoundingRect.maxY)

        return CGRect(
            x: minX,
            y: minY,
            width: max(0.001, maxX - minX),
            height: max(0.001, maxY - minY)
        )
    }

    var centroid: CGPoint {
        let visible = points.filter { $0.visibility > 0.35 }
        guard !visible.isEmpty else { return lastKnownCentroid }

        let avgX = visible.map(\.x).reduce(0, +) / Double(visible.count)
        let avgY = visible.map(\.y).reduce(0, +) / Double(visible.count)
        return CGPoint(x: avgX, y: avgY)
    }
}

