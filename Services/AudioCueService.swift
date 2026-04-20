import Foundation
import AudioToolbox

final class AudioCueService {
    // These are simple built-in iOS system sound IDs.
    // They can be swapped later if you want a different feel.
    private let repSoundID: SystemSoundID = 1104
    private let readySoundID: SystemSoundID = 1113
    private let invalidSoundID: SystemSoundID = 1053

    func playRepComplete() {
        AudioServicesPlaySystemSound(repSoundID)
    }

    func playReadyToBegin() {
        AudioServicesPlaySystemSound(readySoundID)
    }

    func playInvalidTracking() {
        AudioServicesPlaySystemSound(invalidSoundID)
    }
}
