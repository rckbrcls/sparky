import AVFoundation
import SwiftUI

struct MemoryEditorAudioCard: View {
    @Binding var clips: [MemoryModel.Attachment]
    var isEditable: Bool = true
    var onAddClip: (Data, URL?) -> Void
    var onRemoveClip: (UUID) -> Void

    @State private var recorder: AVAudioRecorder?
    @State private var recordingURL: URL?
    @State private var isRecording = false
    @State private var recordingDuration: TimeInterval = 0
    @State private var recordingError: String?
    @State private var timer: Timer?

    @State private var player: AVAudioPlayer?
    @State private var currentlyPlayingID: UUID?

    var body: some View {
        MemoryEditorContentCard {
            VStack(alignment: .leading, spacing: 16) {
                header
                clipsList
                if let recordingError {
                    Text(recordingError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .transition(.opacity)
                }
            }
        }
        .onDisappear {
            stopTimer()
            if isRecording {
                stopRecording(didCancel: true)
            }
            player?.stop()
            // Garante que a sessão de áudio seja desativada ao sair da view
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setActive(false, options: .notifyOthersOnDeactivation)
            } catch {
                // Ignora erros ao desativar a sessão
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Audio clips")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(isRecording ? "Recording…" : "Record and attach quick notes.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isEditable {
                Button {
                    isRecording ? stopRecording(didCancel: false) : beginRecording()
                } label: {
                    Label(isRecording ? "Stop" : "Record", systemImage: isRecording ? "stop.circle.fill" : "record.circle")
                        .labelStyle(.iconOnly)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(isRecording ? .red : .accentColor)
                        .padding(10)
                        .background(
                            Circle()
                                .fill(Color.clear)
                                .liquidGlass(in: Circle(), addSubtleBorder: false)
                        )
                }
                .accessibilityLabel(isRecording ? "Stop recording" : "Start recording")
            }
        }
    }

    @ViewBuilder
    private var clipsList: some View {
        if clips.isEmpty && !isRecording {
            placeholder
        } else {
            VStack(alignment: .leading, spacing: 12) {
                if isRecording {
                    recordingIndicator
                }
                ForEach(clips) { clip in
                    clipRow(clip)
                }
            }
        }
    }

    private var placeholder: some View {
        VStack(alignment: .center, spacing: 8) {
            Image(systemName: "waveform")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(.secondary)
            Text(isEditable ? "Record audio to capture quick reminders." : "No audio attached to this memory.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.15), lineWidth: 1)
        )
    }

    private var recordingIndicator: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color.red)
                .frame(width: 10, height: 10)
                .shadow(color: .red.opacity(0.5), radius: 6, x: 0, y: 0)
                .animation(.easeInOut(duration: 0.6).repeatForever(), value: isRecording)
            Text("Recording \(formattedDuration(recordingDuration))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Button(role: .destructive) {
                stopRecording(didCancel: true)
            } label: {
                Label("Cancel", systemImage: "xmark.circle.fill")
                    .labelStyle(.iconOnly)
            }
            .tint(.secondary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    private func clipRow(_ clip: MemoryModel.Attachment) -> some View {
        HStack(spacing: 12) {
            Button {
                togglePlayback(for: clip)
            } label: {
                Image(systemName: (currentlyPlayingID == clip.id && player?.isPlaying == true) ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.accent)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text("Clip \(clipLabel(for: clip))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                HStack(spacing: 8) {
                    if let duration = clipDuration(for: clip) {
                        Label(formattedDuration(duration), systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Label(byteCountFormatter.string(fromByteCount: Int64(clip.data.count)), systemImage: "tray.and.arrow.down.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()

            if isEditable {
                Button {
                    stopPlaybackIfNeeded()
                    onRemoveClip(clip.id)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete clip")
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    private func beginRecording() {
        recordingError = nil
        stopPlaybackIfNeeded()
        let session = AVAudioSession.sharedInstance()
        let requestPermission: (@escaping (Bool) -> Void) -> Void
        if #available(iOS 17.0, *) {
            requestPermission = { handler in
                AVAudioApplication.requestRecordPermission { granted in
                    handler(granted)
                }
            }
        } else {
            requestPermission = { handler in
                session.requestRecordPermission(handler)
            }
        }

        requestPermission { granted in
            DispatchQueue.main.async {
                guard granted else {
                    recordingError = "Microphone access was denied."
                    return
                }

                do {
                    try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetoothHFP])
                    try session.setActive(true)
                    let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).m4a")
                    let recorder = try AVAudioRecorder(url: url, settings: recordingSettings)
                    recorder.record()
                    recordingURL = url
                    self.recorder = recorder
                    isRecording = true
                    startTimer()
                } catch {
                    recordingError = "Unable to start recording."
                }
            }
        }
    }

    private func stopRecording(didCancel: Bool) {
        recorder?.stop()
        recorder = nil
        stopTimer()

        let url = recordingURL
        recordingURL = nil
        recordingDuration = 0
        isRecording = false

        // Desativa a sessão de áudio para não interferir com outros apps
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            // Ignora erros ao desativar a sessão
        }

        guard !didCancel, let url, let data = try? Data(contentsOf: url), !data.isEmpty else {
            return
        }

        onAddClip(data, url)
    }

    private func togglePlayback(for clip: MemoryModel.Attachment) {
        stopRecording(didCancel: true)

        if currentlyPlayingID == clip.id, let player, player.isPlaying {
            player.stop()
            currentlyPlayingID = nil
            return
        }

        do {
            player = try AVAudioPlayer(data: clip.data)
            player?.play()
            currentlyPlayingID = clip.id
        } catch {
            recordingError = "Unable to play this clip."
        }
    }

    private func stopPlaybackIfNeeded() {
        player?.stop()
        currentlyPlayingID = nil
    }

    private func clipDuration(for clip: MemoryModel.Attachment) -> TimeInterval? {
        guard let player = try? AVAudioPlayer(data: clip.data) else { return nil }
        return player.duration
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
            recordingDuration += 0.2
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private var recordingSettings: [String: Any] {
        [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 12_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
    }

    private var byteCountFormatter: ByteCountFormatter {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter
    }

    private func clipLabel(for clip: MemoryModel.Attachment) -> String {
        if let index = clips.firstIndex(where: { $0.id == clip.id }) {
            return "#\(index + 1)"
        }
        return String(clip.id.uuidString.prefix(4)) + "…"
    }
}
