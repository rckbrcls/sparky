import Foundation
import Combine
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

@MainActor
final class RemoteSyncService: ObservableObject {
    enum Status {
        case disabled, notConfigured, idle(lastSync: Date?), syncing, error(String)
    }
    let settings: RemoteSyncSettings
    let client: RemoteSyncClient
    let builder: RemoteMirrorBuilder
    let executor: RemoteCommandExecutor
    @Published private(set) var status: Status = .disabled
    @Published private(set) var lastSyncedAt: Date?
    @Published private(set) var pendingError: String?
    private var cancellables: Set<AnyCancellable> = []
    private var loop: Task<Void, Never>?
    private var debounce: Task<Void, Never>?
    private var operation: Task<Void, Never>?
    private var lastMirrorData: Data?
    private var retryNotBefore: Date?
    private var failures = 0
    private var unauthorized = false
    private var started = false
    private var active: Bool
    private var generation = 0

    init(minds: MindService, memories: MemoryService, attachments: MemoryAttachmentStore,
         settings: RemoteSyncSettings? = nil) {
        let settings = settings ?? RemoteSyncSettings()
        self.settings = settings
        client = RemoteSyncClient(settings: settings)
        builder = RemoteMirrorBuilder(minds: minds, memories: memories, attachments: attachments)
        executor = RemoteCommandExecutor(builder: builder)
        #if os(iOS)
        active = UIApplication.shared.applicationState == .active
        let activated = UIApplication.didBecomeActiveNotification
        let deactivated = UIApplication.willResignActiveNotification
        #else
        active = NSApplication.shared.isActive
        let activated = NSApplication.didBecomeActiveNotification
        let deactivated = NSApplication.willResignActiveNotification
        #endif
        NotificationCenter.default.publisher(for: activated).receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.active = true
            self?.restart()
        }.store(in: &cancellables)
        NotificationCenter.default.publisher(for: deactivated).receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.active = false
            self?.cancelWork()
        }.store(in: &cancellables)
        Publishers.Merge(memories.$memories.map { _ in () }, minds.$minds.map { _ in () })
            .receive(on: DispatchQueue.main).sink { [weak self] in self?.schedulePush() }.store(in: &cancellables)
        settings.$isEnabled.dropFirst().map { _ in () }
            .merge(with: settings.$serverURL.dropFirst().map { _ in () })
            .merge(with: settings.$tokenRevision.dropFirst().map { _ in () })
            .receive(on: DispatchQueue.main).sink { [weak self] in
                guard let self else { return }
                self.unauthorized = false
                self.failures = 0
                self.retryNotBefore = nil
                self.lastMirrorData = nil
                self.restart()
            }.store(in: &cancellables)
    }

    func start() {
        started = true
        restart()
    }

    func stop() {
        started = false
        cancelWork()
        status = settings.isEnabled ? .idle(lastSync: lastSyncedAt) : .disabled
    }

    private func cancelWork() {
        generation += 1
        loop?.cancel()
        debounce?.cancel()
        operation?.cancel()
        loop = nil
        debounce = nil
        // Keep the operation reference until it unwinds so a restart cannot overlap mutations.
    }

    private var canSync: Bool { started && active && settings.isEnabled && client.isConfigured && !unauthorized }

    private func restart() {
        cancelWork()
        guard settings.isEnabled else { status = .disabled; pendingError = nil; return }
        guard client.isConfigured else { status = .notConfigured; return }
        guard canSync else { return }
        let currentGeneration = generation
        loop = Task { [weak self] in
            guard let self else { return }
            // Await a cancelled operation before starting another generation.
            if let operation = self.operation { await operation.value }
            while !Task.isCancelled, self.generation == currentGeneration, self.canSync {
                await self.syncNow()
                do { try await Task.sleep(for: .seconds(self.failures >= 3 ? 60 : 10)) }
                catch { return }
            }
        }
    }

    private func schedulePush() {
        guard canSync, retryNotBefore.map({ Date() >= $0 }) ?? true else { return }
        debounce?.cancel()
        debounce = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(2)) } catch { return }
            guard let self, self.canSync else { return }
            if let operation = self.operation { await operation.value }
            guard !Task.isCancelled else { return }
            await self.run(poll: false)
        }
    }

    func syncNow() async { await run(poll: true) }

    private func run(poll: Bool) async {
        guard canSync else {
            if !settings.isEnabled { status = .disabled }
            else if !client.isConfigured { status = .notConfigured }
            return
        }
        if let operation { await operation.value; return }
        let currentGeneration = generation
        let task = Task { [weak self] in
            guard let self else { return }
            self.status = .syncing
            do {
                try await self.pushMirror()
                if poll {
                    var reportingError: Error?
                    for (id, result) in self.executor.pendingResults() {
                        try Task.checkCancellation()
                        do {
                            try await self.client.report(id: id, result: result)
                            try self.executor.markReported(id)
                        } catch RemoteSyncError.unauthorized { throw RemoteSyncError.unauthorized }
                        catch { reportingError = error }
                    }
                    try Task.checkCancellation()
                    let commands = try await self.client.commands()
                    for command in commands {
                        try Task.checkCancellation()
                        guard self.canSync else { throw CancellationError() }
                        let result = await self.executor.execute(command)
                        try Task.checkCancellation()
                        do {
                            try await self.client.report(id: command.id, result: result)
                            try self.executor.markReported(command.id.lowercased())
                        } catch RemoteSyncError.unauthorized { throw RemoteSyncError.unauthorized }
                        catch { reportingError = error }
                    }
                    try await self.pushMirror()
                    if let reportingError { throw reportingError }
                }
                try Task.checkCancellation()
                guard self.generation == currentGeneration else { return }
                self.failures = 0
                self.retryNotBefore = nil
                self.pendingError = nil
                self.status = .idle(lastSync: self.lastSyncedAt)
            } catch {
                guard !Task.isCancelled, self.generation == currentGeneration else { return }
                self.failures += 1
                if self.failures >= 3 { self.retryNotBefore = Date().addingTimeInterval(60) }
                self.pendingError = error.localizedDescription
                self.status = .error(error.localizedDescription)
                if case RemoteSyncError.unauthorized = error {
                    self.unauthorized = true
                    self.loop?.cancel()
                    self.debounce?.cancel()
                }
            }
        }
        operation = task
        await task.value
        operation = nil
    }

    private func pushMirror() async throws {
        try Task.checkCancellation()
        guard canSync else { throw CancellationError() }
        let mirror = try await builder.build()
        var comparison = mirror
        comparison.syncedAt = Date(timeIntervalSince1970: 0)
        let data = try RemoteJSON.encoder().encode(comparison)
        try Task.checkCancellation()
        guard canSync else { throw CancellationError() }
        if data == lastMirrorData { return }
        try await client.putMirror(mirror)
        lastMirrorData = data
        lastSyncedAt = mirror.syncedAt
    }

    func testConnection() async -> Result<Void, Error> {
        if let operation { await operation.value }
        guard settings.isEnabled, client.isConfigured else { return .failure(RemoteSyncError.notConfigured) }
        var outcome: Result<Void, Error> = .failure(CancellationError())
        let task = Task {
            do {
                let mirror = try await builder.build()
                try Task.checkCancellation()
                guard settings.isEnabled else { throw RemoteSyncError.notConfigured }
                try await client.putMirror(mirror)
                outcome = .success(())
            } catch {
                outcome = .failure(error)
                if case RemoteSyncError.unauthorized = error {
                    unauthorized = true
                    pendingError = error.localizedDescription
                    status = .error(error.localizedDescription)
                    loop?.cancel()
                    debounce?.cancel()
                }
            }
        }
        operation = task
        await task.value
        operation = nil
        return outcome
    }
}
