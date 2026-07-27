import AVFoundation
import Foundation
import os

@MainActor
final class FocusSoundService: FocusSoundPlaying {
    nonisolated private static let logger = Logger(
        subsystem: "sparky",
        category: "FocusSoundService"
    )

    private var player: AVAudioPlayer?

    func play(_ cue: FocusSoundCue) throws {
        guard let url = soundURL(for: cue) else {
            Self.logger.error("Missing Focus sound: \(cue.resourceName)")
            throw FocusSoundError.missingResource(cue.resourceName)
        }

        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.ambient, options: [.mixWithOthers])
        try session.setActive(true)
        #endif

        player?.stop()

        let nextPlayer = try AVAudioPlayer(contentsOf: url)
        nextPlayer.numberOfLoops = 0
        nextPlayer.prepareToPlay()
        guard nextPlayer.play() else {
            throw FocusSoundError.playbackFailed(cue.resourceName)
        }
        player = nextPlayer
    }

    private func soundURL(for cue: FocusSoundCue) -> URL? {
        Bundle.main.url(
            forResource: cue.resourceName,
            withExtension: "caf",
            subdirectory: "FocusSounds"
        ) ?? Bundle.main.url(
            forResource: cue.resourceName,
            withExtension: "caf"
        )
    }
}

private enum FocusSoundError: LocalizedError {
    case missingResource(String)
    case playbackFailed(String)

    var errorDescription: String? {
        switch self {
        case let .missingResource(name):
            return "Missing Focus sound resource: \(name)"
        case let .playbackFailed(name):
            return "Could not play Focus sound resource: \(name)"
        }
    }
}
