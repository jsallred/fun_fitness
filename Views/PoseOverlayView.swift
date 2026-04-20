import SwiftUI
import AVFoundation

struct PoseOverlayView: View {
    let trackedPeople: [TrackedPerson]
    let showHUDs: Bool
    let showIDs: Bool
    let highlightTentativeTracks: Bool

    var body: some View {
        GeometryReader { _ in
            Canvas { context, size in
                guard !trackedPeople.isEmpty else { return }

                for person in trackedPeople {
                    let imageSize = person.imageSize == .zero ? size : person.imageSize
                    let videoRect = AVMakeRect(
                        aspectRatio: imageSize,
                        insideRect: CGRect(origin: .zero, size: size)
                    )

                    let strokeColor = readinessColor(for: person)

                    for (startIndex, endIndex) in PoseConnections.lines {
                        guard startIndex < person.points.count, endIndex < person.points.count else { continue }

                        let aPoint = person.points[startIndex]
                        let bPoint = person.points[endIndex]

                        guard aPoint.visibility > 0.35, bPoint.visibility > 0.35 else { continue }

                        let a = pointToCGPoint(aPoint, in: videoRect)
                        let b = pointToCGPoint(bPoint, in: videoRect)

                        var path = Path()
                        path.move(to: a)
                        path.addLine(to: b)
                        context.stroke(path, with: .color(strokeColor), lineWidth: 3)
                    }

                    for point in person.points where point.visibility > 0.35 {
                        let p = pointToCGPoint(point, in: videoRect)
                        let rect = CGRect(x: p.x - 4, y: p.y - 4, width: 8, height: 8)
                        context.fill(Path(ellipseIn: rect), with: .color(strokeColor))
                    }
                }
            }
            .overlay(alignment: .topLeading) {
                if showHUDs {
                    hudLayer
                }
            }
        }
        .allowsHitTesting(false)
    }

    private var hudLayer: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                ForEach(trackedPeople) { person in
                    let anchor = convertNormalizedToViewPoint(person.hud.anchor, size: proxy.size, imageSize: person.imageSize)
                    let hudColor = readinessColor(for: person)

                    VStack(alignment: .leading, spacing: 4) {
                        if showIDs {
                            Text(person.hud.title)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.black)
                        }

                        Text(person.hud.subtitle)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.black)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(hudColor.opacity(0.92))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                highlightTentativeTracks && person.visualState == .tentative
                                ? Color.yellow
                                : Color.clear,
                                lineWidth: 2
                            )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .position(x: anchor.x + 62, y: max(18, anchor.y + 14))
                }
            }
        }
    }

    private func readinessColor(for person: TrackedPerson) -> Color {
        let score = max(0, min(1, person.readinessScore))
        let hue = 0.33 * score
        return Color(hue: hue, saturation: 0.92, brightness: 0.98)
    }

    private func pointToCGPoint(_ point: PosePoint, in rect: CGRect) -> CGPoint {
        CGPoint(
            x: rect.minX + point.x * rect.width,
            y: rect.minY + point.y * rect.height
        )
    }

    private func convertNormalizedToViewPoint(_ point: CGPoint, size: CGSize, imageSize: CGSize) -> CGPoint {
        let sourceSize = imageSize == .zero ? size : imageSize
        let videoRect = AVMakeRect(
            aspectRatio: sourceSize,
            insideRect: CGRect(origin: .zero, size: size)
        )

        return CGPoint(
            x: videoRect.minX + point.x * videoRect.width,
            y: videoRect.minY + point.y * videoRect.height
        )
    }
}
