//
//  PoseMath.swift
//  fun_fitness
//
//  Created by Joseph Allred on 3/9/26.
//

import Foundation

enum PoseMath {
    static func clamp01(_ x: Double) -> Double {
        max(0.0, min(1.0, x))
    }

    static func ema(previous: Double?, next: Double, alpha: Double) -> Double {
        guard let previous else { return next }
        return previous + alpha * (next - previous)
    }

    static func angleDegrees(a: (Double, Double), b: (Double, Double), c: (Double, Double)) -> Double? {
        let v1x = a.0 - b.0
        let v1y = a.1 - b.1
        let v2x = c.0 - b.0
        let v2y = c.1 - b.1

        let dot = v1x * v2x + v1y * v2y
        let m1 = sqrt(v1x * v1x + v1y * v1y)
        let m2 = sqrt(v2x * v2x + v2y * v2y)

        guard m1 > 1e-6, m2 > 1e-6 else { return nil }

        let cosValue = max(-1.0, min(1.0, dot / (m1 * m2)))
        return acos(cosValue) * 180.0 / .pi
    }
}


