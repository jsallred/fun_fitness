import Foundation

final class ExerciseConfigLoader {
    private(set) var exercises: [String: ExerciseConfig] = [:]
    private(set) var routines: [RoutineConfig] = []

    static let shared = ExerciseConfigLoader()

    private init() {}

    @discardableResult
    func loadAll() -> Bool {
        let loadedExercises = loadExercises()
        let loadedRoutines = loadRoutines()
        return !loadedExercises.isEmpty || !loadedRoutines.isEmpty
    }

    private func loadExercises() -> [ExerciseConfig] {
        guard let urls = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: "ExerciseConfigs") else {
            print("[ExerciseConfigLoader] No ExerciseConfigs directory found in bundle")
            return []
        }

        let decoder = JSONDecoder()
        var loaded: [ExerciseConfig] = []

        for url in urls where url.lastPathComponent != "routines.json" {
            do {
                let data = try Data(contentsOf: url)
                let config = try decoder.decode(ExerciseConfig.self, from: data)
                exercises[config.id] = config
                loaded.append(config)
                print("[ExerciseConfigLoader] Loaded exercise: \(config.id)")
            } catch {
                print("[ExerciseConfigLoader] Failed to parse \(url.lastPathComponent): \(error)")
            }
        }

        return loaded
    }

    private func loadRoutines() -> [RoutineConfig] {
        guard let url = Bundle.main.url(forResource: "routines", withExtension: "json", subdirectory: "ExerciseConfigs") else {
            print("[ExerciseConfigLoader] routines.json not found in ExerciseConfigs")
            return []
        }

        let decoder = JSONDecoder()

        do {
            let data = try Data(contentsOf: url)
            routines = try decoder.decode([RoutineConfig].self, from: data)
            print("[ExerciseConfigLoader] Loaded \(routines.count) routines")
            return routines
        } catch {
            print("[ExerciseConfigLoader] Failed to parse routines.json: \(error)")
            return []
        }
    }

    func exerciseConfig(for id: String) -> ExerciseConfig? {
        exercises[id]
    }

    func buildRehabRoutines() -> [RehabRoutine] {
        routines.compactMap { routineConfig in
            let rehabExercises: [RehabExercise] = routineConfig.exercises.compactMap { ref in
                guard let exerciseConfig = exercises[ref.exerciseId] else {
                    print("[ExerciseConfigLoader] Exercise '\(ref.exerciseId)' not found for routine '\(routineConfig.id)'")
                    return nil
                }
                return RehabExercise(
                    configId: ref.exerciseId,
                    displayName: exerciseConfig.displayName,
                    instructions: exerciseConfig.instructions,
                    targetReps: ref.targetReps
                )
            }

            guard !rehabExercises.isEmpty else { return nil }

            return RehabRoutine(
                name: routineConfig.name,
                exercises: rehabExercises
            )
        }
    }
}
