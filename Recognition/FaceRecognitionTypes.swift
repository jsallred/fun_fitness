import Foundation

struct FaceEmbedding: Equatable, Codable {
    let values: [Float]

    var isEmpty: Bool {
        values.isEmpty
    }

    func cosineSimilarity(to other: FaceEmbedding) -> Float {
        guard values.count == other.values.count, !values.isEmpty else { return 0 }

        var dot: Float = 0
        var normA: Float = 0
        var normB: Float = 0

        for index in values.indices {
            dot += values[index] * other.values[index]
            normA += values[index] * values[index]
            normB += other.values[index] * other.values[index]
        }

        let denom = sqrt(normA) * sqrt(normB)
        guard denom > 0 else { return 0 }
        return dot / denom
    }
}

enum RecognitionState: String, Codable, Equatable {
    case none
    case tentative
    case recognized
}

struct FaceProfile: Identifiable, Codable, Equatable {
    let id: UUID
    let trackedID: TrackedPersonID
    var embeddings: [FaceEmbedding]
    var createdAtMs: Int
    var lastUpdatedMs: Int

    init(
        id: UUID = UUID(),
        trackedID: TrackedPersonID,
        embeddings: [FaceEmbedding],
        createdAtMs: Int,
        lastUpdatedMs: Int
    ) {
        self.id = id
        self.trackedID = trackedID
        self.embeddings = embeddings
        self.createdAtMs = createdAtMs
        self.lastUpdatedMs = lastUpdatedMs
    }
}

struct FaceMatchResult: Equatable {
    let trackedID: TrackedPersonID
    let profileID: UUID
    let similarity: Float

    var isStrongMatch: Bool {
        similarity >= 0.58
    }
}

