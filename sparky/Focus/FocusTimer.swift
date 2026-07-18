//
//  FocusTimer.swift
//  sparky
//
//  Pomodoro engine for Focus sessions (ported from Converge, iOS-native).
//

import Foundation
import Combine

enum FocusPhase: String {
    case idle
    case work
    case `break`
}

@MainActor
final class FocusTimer: ObservableObject {
    @Published private(set) var remainingSeconds: Int
    @Published private(set) var isRunning: Bool = false
    @Published private(set) var phase: FocusPhase = .idle
    @Published private(set) var completedPomodoros: Int = 0
    @Published private(set) var isWaitingForManualStart: Bool = false
    @Published private(set) var activeMemoryID: UUID?
    @Published private(set) var activeMemoryTitle: String?
    @Published private(set) var activeRecipe: FocusRecipe?
    @Published private(set) var phaseStartedAt: Date?
    @Published private(set) var phaseEndsAt: Date?

    let settings: FocusSettings
    private let notifications: FocusNotificationService

    private var currentPhaseTotalSeconds: Int = 0
    private var timerCancellable: AnyCancellable?
    private var settingsCancellable: AnyCancellable?

    var formattedTime: String {
        let m = remainingSeconds / 60
        let s = remainingSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    var progress: Double {
        guard currentPhaseTotalSeconds > 0 else { return 0 }
        let elapsed = currentPhaseTotalSeconds - remainingSeconds
        return max(0, min(1, Double(elapsed) / Double(currentPhaseTotalSeconds)))
    }

    private var boundRecipe: FocusRecipe {
        activeRecipe ?? FocusRecipe.from(settings: settings)
    }

    var nextBreakDurationSeconds: Int {
        let nextCount = completedPomodoros + 1
        let isLong = nextCount % boundRecipe.pomodorosUntilLongBreak == 0
        return isLong ? boundRecipe.longBreakDurationSeconds : boundRecipe.shortBreakDurationSeconds
    }

    var nextBreakFormattedTime: String {
        let m = nextBreakDurationSeconds / 60
        let s = nextBreakDurationSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    var isSessionActive: Bool {
        // Bound recipe means a session exists until endSession(); reset keeps the binding.
        activeRecipe != nil
    }

    var isQuickSession: Bool {
        isSessionActive && activeMemoryID == nil
    }

    /// Whether +1 min (or similar) may extend the current work/break phase.
    var canExtendPhase: Bool {
        isSessionActive
            && (phase == .work || phase == .break)
            && !isWaitingForManualStart
    }

    var displayStartDate: Date? {
        phaseStartedAt
    }

    /// End of current phase for UI time window (running uses wall clock; paused uses remaining).
    var displayEndDate: Date? {
        if isRunning {
            return phaseEndsAt
        }
        guard canExtendPhase, remainingSeconds >= 0 else { return nil }
        return Date().addingTimeInterval(TimeInterval(remainingSeconds))
    }

    init(settings: FocusSettings, notifications: FocusNotificationService) {
        self.settings = settings
        self.notifications = notifications
        let initial = FocusRecipe.from(settings: settings).workDurationSeconds
        self.remainingSeconds = initial
        self.currentPhaseTotalSeconds = initial

        settingsCancellable = settings.objectWillChange.sink { [weak self] _ in
            Task { @MainActor in
                self?.updateTimerFromSettings()
            }
        }
    }

    /// Starts a Quick Focus session using a snapshot of global defaults.
    /// - Parameter workDurationMinutes: Optional work length override (clamped 1…60). `nil` uses global work default.
    func beginQuickSession(workDurationMinutes: Int? = nil) {
        let base = FocusRecipe.from(settings: settings)
        let recipe: FocusRecipe
        if let workDurationMinutes {
            recipe = FocusRecipe(
                workDurationMinutes: workDurationMinutes,
                shortBreakDurationMinutes: base.shortBreakDurationMinutes,
                longBreakDurationMinutes: base.longBreakDurationMinutes,
                pomodorosUntilLongBreak: base.pomodorosUntilLongBreak,
                autoContinue: base.autoContinue
            )
        } else {
            recipe = base
        }

        beginQuickSession(recipe: recipe)
    }

    /// Starts a Quick Focus session using a complete session-local recipe.
    func beginQuickSession(recipe: FocusRecipe) {
        if isSessionActive, activeMemoryID == nil {
            return
        }
        guard !isSessionActive else { return }

        reset()
        activeRecipe = recipe
        activeMemoryID = nil
        activeMemoryTitle = "Quick Focus"
        configurePhase(.work, totalSeconds: recipe.workDurationSeconds)
        start()
    }

    /// Starts a Memory-bound session. No-ops if the same memory session is already active.
    func beginSession(memoryID: UUID, memoryTitle: String, recipe: FocusRecipe) {
        if activeMemoryID == memoryID, isSessionActive {
            return
        }
        guard !isSessionActive || activeMemoryID == memoryID else { return }

        reset()
        activeRecipe = recipe
        activeMemoryID = memoryID
        activeMemoryTitle = memoryTitle
        configurePhase(.work, totalSeconds: recipe.workDurationSeconds)
        start()
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        isWaitingForManualStart = false

        if phase == .idle {
            let recipe = boundRecipe
            activeRecipe = recipe
            if activeMemoryTitle == nil {
                activeMemoryTitle = "Quick Focus"
            }
            configurePhase(.work, totalSeconds: recipe.workDurationSeconds)
        } else {
            phaseEndsAt = Date().addingTimeInterval(TimeInterval(max(remainingSeconds, 0)))
        }

        startTicking()
    }

    func pause() {
        guard isRunning else { return }
        syncRemainingFromWallClock()
        isRunning = false
        phaseEndsAt = nil
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    func reset() {
        pause()
        phase = .idle
        let seconds = FocusRecipe.from(settings: settings).workDurationSeconds
        remainingSeconds = seconds
        currentPhaseTotalSeconds = seconds
        completedPomodoros = 0
        isWaitingForManualStart = false
        activeMemoryID = nil
        activeMemoryTitle = nil
        activeRecipe = nil
        phaseEndsAt = nil
        phaseStartedAt = nil
    }

    func endSession() {
        reset()
    }

    /// Resets counters while keeping memory binding and recipe.
    func resetCurrentSession() {
        let memoryID = activeMemoryID
        let title = activeMemoryTitle
        let recipe = activeRecipe
        pause()
        phase = .idle
        let seconds = (recipe ?? FocusRecipe.from(settings: settings)).workDurationSeconds
        remainingSeconds = seconds
        currentPhaseTotalSeconds = seconds
        completedPomodoros = 0
        isWaitingForManualStart = false
        activeMemoryID = memoryID
        activeMemoryTitle = title
        activeRecipe = recipe
        phaseEndsAt = nil
        phaseStartedAt = nil
    }

    func startNextPhase() {
        guard isWaitingForManualStart else { return }
        isWaitingForManualStart = false
        start()
    }

    /// Adds minutes to the current work/break phase remaining time (and total, so progress stays continuous).
    func extendCurrentPhase(byMinutes minutes: Int = 1) {
        guard canExtendPhase else { return }
        let clampedMinutes = max(minutes, 1)
        let delta = clampedMinutes * 60
        remainingSeconds += delta
        currentPhaseTotalSeconds += delta
        if isRunning {
            if let phaseEndsAt {
                self.phaseEndsAt = phaseEndsAt.addingTimeInterval(TimeInterval(delta))
            } else {
                phaseEndsAt = Date().addingTimeInterval(TimeInterval(remainingSeconds))
            }
        }
    }

    /// Whether starting `memoryID` (nil = quick) would replace a different active session.
    func wouldReplaceSession(withMemoryID memoryID: UUID?) -> Bool {
        guard isSessionActive else { return false }
        return activeMemoryID != memoryID
    }

    /// Re-sync remaining time after returning to foreground.
    func refreshFromWallClock() {
        guard isRunning else { return }
        syncRemainingFromWallClock()
        if remainingSeconds <= 0 {
            advanceToNextPhase()
        }
    }

    /// Completes the current phase immediately (tests / diagnostics).
    func completePhaseNow() {
        advanceToNextPhase()
    }

    private func updateTimerFromSettings() {
        guard !isRunning, phase == .idle, activeRecipe == nil else { return }
        let seconds = FocusRecipe.from(settings: settings).workDurationSeconds
        remainingSeconds = seconds
        currentPhaseTotalSeconds = seconds
    }

    private func startTicking() {
        timerCancellable?.cancel()
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.tick()
                }
            }
    }

    private func configurePhase(_ newPhase: FocusPhase, totalSeconds: Int) {
        phase = newPhase
        currentPhaseTotalSeconds = max(totalSeconds, 0)
        remainingSeconds = currentPhaseTotalSeconds
        let now = Date()
        phaseStartedAt = now
        phaseEndsAt = now.addingTimeInterval(TimeInterval(currentPhaseTotalSeconds))
    }

    private func syncRemainingFromWallClock() {
        guard let phaseEndsAt else { return }
        remainingSeconds = max(0, Int(ceil(phaseEndsAt.timeIntervalSinceNow)))
    }

    private func tick() {
        guard isRunning else { return }
        syncRemainingFromWallClock()
        if remainingSeconds <= 0 {
            advanceToNextPhase()
        }
    }

    private func advanceToNextPhase() {
        let recipe = boundRecipe

        switch phase {
        case .work:
            notifications.sendWorkComplete()
            completedPomodoros += 1
            let isLong = completedPomodoros % recipe.pomodorosUntilLongBreak == 0
            let seconds = isLong ? recipe.longBreakDurationSeconds : recipe.shortBreakDurationSeconds
            configurePhase(.break, totalSeconds: seconds)

        case .break:
            notifications.sendBreakComplete()
            configurePhase(.work, totalSeconds: recipe.workDurationSeconds)

        case .idle:
            configurePhase(.work, totalSeconds: recipe.workDurationSeconds)
        }

        if recipe.autoContinue {
            // keep running with new deadline already set
            if !isRunning {
                isRunning = true
                startTicking()
            }
        } else {
            pause()
            isWaitingForManualStart = true
        }
    }
}
