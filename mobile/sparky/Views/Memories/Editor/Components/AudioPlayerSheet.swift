import SwiftUI
import AVFoundation

struct AudioPlayerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let audioData: Data

    @State private var player: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var currentTime: TimeInterval = 0
    @State private var duration: TimeInterval = 0
    @State private var timer: Timer?
    @State private var playbackError: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 16) {
                    Image(systemName: isPlaying ? "waveform" : "waveform.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(isPlaying ? .accent : .secondary)
                        .symbolEffect(.variableColor.iterative, isActive: isPlaying)

                    Text(formattedTime(currentTime))
                        .font(.system(size: 56, weight: .light).monospacedDigit())
                        .contentTransition(.numericText())
                }

                if duration > 0 {
                    VStack(spacing: 8) {
                        Slider(
                            value: Binding(
                                get: { currentTime },
                                set: { newValue in
                                    currentTime = newValue
                                    player?.currentTime = newValue
                                }
                            ),
                            in: 0...max(duration, 0.01)
                        )
                        .tint(.accent)

                        HStack {
                            Text(formattedTime(currentTime))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(formattedTime(duration))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 32)
                }

                if let playbackError {
                    Text(playbackError)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer()

                Button {
                    isPlaying ? pausePlayback() : startPlayback()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 80, height: 80)

                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.white)
                    }
                }
                .padding(.bottom, 48)
            }
            .navigationTitle("Audio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                preparePlayer()
            }
            .onDisappear {
                cleanup()
            }
        }
    }

    private func preparePlayer() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)

            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(UUID().uuidString).m4a")
            try audioData.write(to: tempURL, options: .atomic)

            let audioPlayer = try AVAudioPlayer(contentsOf: tempURL)
            audioPlayer.prepareToPlay()
            duration = audioPlayer.duration
            player = audioPlayer
        } catch {
            playbackError = "Unable to load audio."
        }
    }

    private func startPlayback() {
        guard let player else {
            playbackError = "Unable to play audio."
            return
        }

        if player.currentTime >= player.duration {
            player.currentTime = 0
            currentTime = 0
        }

        player.play()
        isPlaying = true
        startTimer()
    }

    private func pausePlayback() {
        player?.pause()
        isPlaying = false
        stopTimer()
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            guard let player else { return }
            currentTime = player.currentTime

            if !player.isPlaying && isPlaying {
                isPlaying = false
                stopTimer()
                currentTime = duration
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func cleanup() {
        stopTimer()
        player?.stop()
        player = nil
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {}
    }

    private func formattedTime(_ time: TimeInterval) -> String {
        let totalSeconds = Int(max(time, 0))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
