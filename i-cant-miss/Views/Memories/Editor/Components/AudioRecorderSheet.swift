import SwiftUI
import AVFoundation

struct AudioRecorderSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onSave: (Data, URL) -> Void

    @State private var recorder: AVAudioRecorder?
    @State private var recordingURL: URL?
    @State private var isRecording = false
    @State private var recordingDuration: TimeInterval = 0
    @State private var recordingError: String?
    @State private var timer: Timer?

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                // Visualization
                VStack(spacing: 16) {
                    if isRecording {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 24, height: 24)
                            .shadow(color: .red.opacity(0.5), radius: 8, x: 0, y: 0)
                            .animation(.easeInOut(duration: 0.6).repeatForever(), value: isRecording)
                    } else {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                    }

                    Text(formattedDuration(recordingDuration))
                        .font(.system(size: 64, weight: .light).monospacedDigit())
                        .contentTransition(.numericText())
                }

                if let recordingError {
                    Text(recordingError)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                }

                Spacer()

                // Controls
                VStack(spacing: 24) {
                    Button {
                        isRecording ? stopRecording(shouldSave: true) : beginRecording()
                    } label: {
                        ZStack {
                            Circle()
                                .strokeBorder(isRecording ? Color.red : Color.accentColor, lineWidth: 4)
                                .frame(width: 80, height: 80)

                            if isRecording {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.red)
                                    .frame(width: 32, height: 32)
                            } else {
                                Circle()
                                    .fill(Color.accentColor)
                                    .frame(width: 68, height: 68)
                            }
                        }
                    }

                    Text(isRecording ? "Tap to Stop" : "Tap to Record")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 48)
            }
            .navigationTitle("Record Audio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        stopRecording(shouldSave: false)
                        dismiss()
                    }
                }
            }
            .onDisappear {
                cleanup()
            }
        }
    }

    private func cleanup() {
        stopTimer()
        if isRecording {
            recorder?.stop()
             do {
                try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
             } catch {}
        }
    }

    private func beginRecording() {
        recordingError = nil
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

    private func stopRecording(shouldSave: Bool) {
        recorder?.stop()
        recorder = nil
        stopTimer()
        isRecording = false

        if shouldSave, let url = recordingURL, let data = try? Data(contentsOf: url), !data.isEmpty {
            onSave(data, url)
            dismiss()
        }

        recordingURL = nil
        recordingDuration = 0
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            recordingDuration += 0.1
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var recordingSettings: [String: Any] {
        [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 12_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
    }
}
