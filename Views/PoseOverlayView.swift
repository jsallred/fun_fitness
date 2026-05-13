import SwiftUI
import AVFoundation

struct PoseOverlayView: View {
    let trackedPeople: [TrackedPerson]
    let showHUDs: Bool
    let showIDs: Bool
    let highlightTentativeTracks: Bool
    let showSquatDebugInfo: Bool
    let showJumpingJackDebugInfo: Bool
    let showBicepCurlDebugInfo: Bool

    private let flashDurationMs = 500

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
            TimelineView(.animation) { timeline in
                let nowMs = Int(timeline.date.timeIntervalSince1970 * 1000)

                ZStack(alignment: .topLeading) {
                    ForEach(trackedPeople) { person in
                        let anchor = convertNormalizedToViewPoint(person.hud.anchor, size: proxy.size, imageSize: person.imageSize)
                        let hudColor = readinessColor(for: person)

                        VStack(alignment: .leading, spacing: 7) {
                            if showIDs {
                                Text(person.hud.title)
                                    .font(.caption.weight(.bold))
                            }

                            HStack(spacing: 4) {
                                counterSegment(
                                    label: "Squat",
                                    value: person.exerciseState.demoCounters.squats,
                                    isFlashing: isFlashing(lastMs: person.exerciseState.demoRepFlashTimes.squats, nowMs: nowMs)
                                )

                                counterSegment(
                                    label: "Jack",
                                    value: person.exerciseState.demoCounters.jumpingJacks,
                                    isFlashing: isFlashing(lastMs: person.exerciseState.demoRepFlashTimes.jumpingJacks, nowMs: nowMs)
                                )

                                counterSegment(
                                    label: "Curl",
                                    value: person.exerciseState.demoCounters.bicepCurls,
                                    isFlashing: isFlashing(lastMs: person.exerciseState.demoRepFlashTimes.bicepCurls, nowMs: nowMs)
                                )
                            }
                            .fixedSize(horizontal: true, vertical: true)

                            debugBlock(for: person)
                                .frame(maxWidth: 210, alignment: .leading)
                                .lineLimit(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.70))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(
                                    highlightTentativeTracks && person.visualState == .tentative
                                    ? Color.yellow
                                    : hudColor.opacity(0.9),
                                    lineWidth: 2
                                )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .shadow(color: .black.opacity(0.30), radius: 5, x: 0, y: 2)
                        .fixedSize(horizontal: true, vertical: true)
                        .position(
                            x: clamp(anchor.x, min: 82, max: proxy.size.width - 82),
                            y: max(34, anchor.y)
                        )
                    }
                }
            }
        }
    }

    private func counterSegment(label: String, value: Int, isFlashing: Bool) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.86))

            Text("\(value)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
        }
        .frame(width: 48, height: 38)
        .background(isFlashing ? Color.green.opacity(0.82) : Color.white.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isFlashing ? Color.green.opacity(0.95) : Color.clear, lineWidth: 1.5)
        )
        .shadow(color: isFlashing ? Color.green.opacity(0.85) : Color.clear, radius: isFlashing ? 8 : 0)
        .animation(.easeOut(duration: 0.18), value: isFlashing)
    }

    @ViewBuilder
    private func debugBlock(for person: TrackedPerson) -> some View {
        let debug = person.exerciseState.demoDebugInfo

        if showSquatDebugInfo || showJumpingJackDebugInfo || showBicepCurlDebugInfo {
            VStack(alignment: .leading, spacing: 3) {
                if showSquatDebugInfo {
                    Text("Squat: \(debug.squat.state) • knee min \(angleText(debug.squat.minKneeAngle)) • avg \(angleText(debug.squat.averageKneeAngle))")
                }

                if showJumpingJackDebugInfo {
                    Text("Jack: \(debug.jumpingJack.state) • feet/shoulders \(ratioText(debug.jumpingJack.ankleToShoulderRatio)) • open \(yesNo(debug.jumpingJack.feetWiderThanShoulders && debug.jumpingJack.wristsAboveShoulders)) • closed \(yesNo(debug.jumpingJack.feetCloserThanShoulders && debug.jumpingJack.wristsBelowShoulders))")
                }

                if showBicepCurlDebugInfo {
                    Text("Curl: \(debug.curl.state) • elbow min \(angleText(debug.curl.minElbowAngle)) • avg \(angleText(debug.curl.averageElbowAngle))")
                }
            }
            .font(.system(size: 8, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.86))
            .padding(.top, 1)
        }
    }

    private func isFlashing(lastMs: Int, nowMs: Int) -> Bool {
        lastMs > 0 && nowMs - lastMs <= flashDurationMs
    }

    private func angleText(_ value: Double?) -> String {
        guard let value else { return "--°" }
        return "\(Int(value.rounded()))°"
    }

    private func ratioText(_ value: Double?) -> String {
        guard let value else { return "--" }
        return String(format: "%.2f", value)
    }

    private func yesNo(_ value: Bool) -> String {
        value ? "yes" : "no"
    }

    private func clamp(_ value: CGFloat, min minValue: CGFloat, max maxValue: CGFloat) -> CGFloat {
        Swift.max(minValue, Swift.min(maxValue, value))
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
