import Foundation
import Combine

@MainActor
final class AppSettings: ObservableObject {
    @Published var multiPersonTrackingEnabled: Bool = false
    @Published var faceAssistedRecognitionEnabled: Bool = false
    @Published var showPersonHUDs: Bool = true
    @Published var showPersonIDs: Bool = false
    @Published var highlightTentativeTracks: Bool = false

    @Published var audioCuesEnabled: Bool = true

    @Published var maxVisiblePeople: Int = 4
}
