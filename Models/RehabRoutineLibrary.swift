//
//  RehabRoutineLibrary.swift
//  fun_fitness
//
//  Created by Joseph Allred on 4/13/26.
//
import Foundation

enum RehabRoutineLibrary {
    static let all: [RehabRoutine] = [
        RehabRoutine(
            name: "Demo Routine",
            bodyRegion: .demo,
            summary: "Live multi-exercise demo that tracks squats and jumping jacks at the same time with no rep goal.",
            estimatedMinutes: 0,
            mode: .demo,
            exercises: [
                RehabExercise(type: .miniSquat, targetReps: nil),
                RehabExercise(type: .jumpingJack, targetReps: nil)
            ]
        ),

        RehabRoutine(
            name: "Shoulder Mobility 1.0 Beta",
            bodyRegion: .shoulder,
            summary: "A gentle guided shoulder sequence focused on forward raise, side raise, and scaption control.",
            estimatedMinutes: 4,
            mode: .guided,
            exercises: [
                RehabExercise(type: .shoulderFlexion, targetReps: 8),
                RehabExercise(type: .shoulderAbduction, targetReps: 8),
                RehabExercise(type: .shoulderScaption, targetReps: 8)
            ]
        ),

        RehabRoutine(
            name: "Shoulder Endurance 1.0 Beta",
            bodyRegion: .shoulder,
            summary: "A slightly longer shoulder routine that repeats supported overhead patterns for control and endurance.",
            estimatedMinutes: 5,
            mode: .guided,
            exercises: [
                RehabExercise(type: .shoulderFlexion, targetReps: 10),
                RehabExercise(type: .shoulderScaption, targetReps: 10),
                RehabExercise(type: .shoulderAbduction, targetReps: 10)
            ]
        ),

        RehabRoutine(
            name: "Hip Stability 1.0 Beta",
            bodyRegion: .hip,
            summary: "A guided hip routine using marching and standing hip abduction for control and balance.",
            estimatedMinutes: 5,
            mode: .guided,
            exercises: [
                RehabExercise(type: .marchInPlace, targetReps: 12),
                RehabExercise(type: .standingHipAbduction, targetReps: 10),
                RehabExercise(type: .marchInPlace, targetReps: 12)
            ]
        ),

        RehabRoutine(
            name: "Lower Body Control 1.0 Beta",
            bodyRegion: .kneeAnkle,
            summary: "A guided lower-body routine that mixes sit-to-stand, mini squats, and marching.",
            estimatedMinutes: 5,
            mode: .guided,
            exercises: [
                RehabExercise(type: .sitToStand, targetReps: 10),
                RehabExercise(type: .miniSquat, targetReps: 8),
                RehabExercise(type: .marchInPlace, targetReps: 12)
            ]
        ),

        RehabRoutine(
            name: "Calf & Knee Support 1.0 Beta",
            bodyRegion: .kneeAnkle,
            summary: "A supportive lower-leg routine combining heel raises with seated-to-standing movement and squat control.",
            estimatedMinutes: 5,
            mode: .guided,
            exercises: [
                RehabExercise(type: .standingHeelRaise, targetReps: 15),
                RehabExercise(type: .sitToStand, targetReps: 10),
                RehabExercise(type: .miniSquat, targetReps: 8)
            ]
        ),

        RehabRoutine(
            name: "General Warmup 1.0 Beta",
            bodyRegion: .general,
            summary: "A simple full-body warmup that combines marching, calf raises, and mini squats.",
            estimatedMinutes: 4,
            mode: .guided,
            exercises: [
                RehabExercise(type: .marchInPlace, targetReps: 12),
                RehabExercise(type: .standingHeelRaise, targetReps: 15),
                RehabExercise(type: .miniSquat, targetReps: 8)
            ]
        )
    ]
}
