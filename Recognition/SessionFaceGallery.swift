import Foundation

final class SessionFaceGallery {
    private(set) var profiles: [UUID: FaceProfile] = [:]

    func reset() {
        profiles.removeAll()
    }

    func register(
        embedding: FaceEmbedding,
        for trackedID: TrackedPersonID,
        timestampMs: Int
    ) -> UUID {
        if let existing = profiles.values.first(where: { $0.trackedID == trackedID }) {
            var profile = existing
            profile.embeddings.append(embedding)
            profile.embeddings = Array(profile.embeddings.suffix(8))
            profile.lastUpdatedMs = timestampMs
            profiles[profile.id] = profile
            return profile.id
        } else {
            let profile = FaceProfile(
                trackedID: trackedID,
                embeddings: [embedding],
                createdAtMs: timestampMs,
                lastUpdatedMs: timestampMs
            )
            profiles[profile.id] = profile
            return profile.id
        }
    }

    func bestMatch(for embedding: FaceEmbedding) -> FaceMatchResult? {
        let candidates: [FaceMatchResult] = profiles.values.compactMap { profile in
            guard let similarity = bestSimilarity(from: embedding, to: profile) else { return nil }
            return FaceMatchResult(
                trackedID: profile.trackedID,
                profileID: profile.id,
                similarity: similarity
            )
        }

        return candidates.max(by: { $0.similarity < $1.similarity })
    }

    func profile(for trackedID: TrackedPersonID) -> FaceProfile? {
        profiles.values.first(where: { $0.trackedID == trackedID })
    }

    private func bestSimilarity(from embedding: FaceEmbedding, to profile: FaceProfile) -> Float? {
        let similarities = profile.embeddings.map { embedding.cosineSimilarity(to: $0) }
        return similarities.max()
    }
}

