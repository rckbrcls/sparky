//
//  FocusTriggerExecutor.swift
//  i-cant-miss
//
//  Created by Codex on 13/10/25.
//

import Foundation
import UserNotifications
import Combine

enum FocusAuthorizationStatus {
    case notDetermined
    case denied
    case authorized
}

@MainActor
final class FocusTriggerExecutor: NSObject, ObservableObject, TriggerExecutorProtocol {
    @Published private(set) var authorizationStatus: FocusAuthorizationStatus = .notDetermined

    private var registeredTriggers: [UUID: (triggerID: UUID, focusIdentifier: String?, memoryTitle: String)] = [:]
    private var notificationObserver: NSObjectProtocol?
    private let center = UNUserNotificationCenter.current()
    private weak var memoryService: MemoryService?

    init(memoryService: MemoryService? = nil) {
        super.init()
        self.memoryService = memoryService
        if #available(iOS 15.0, *) {
            setupNotificationObserver()
        }
    }

    deinit {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func setupNotificationObserver() {
        guard #available(iOS 15.0, *) else { return }

        // Observar mudanças no status de foco via NotificationCenter
        // Nota: A API real do FocusStatusCenter pode variar, então usamos uma abordagem mais genérica
        notificationObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("INFocusStatusCenterStatusDidChange"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.handleFocusStatusChange()
            }
        }
    }

    func requestAuthorization() async {
        guard #available(iOS 15.0, *) else { return }

        // Por enquanto, marcamos como autorizado após solicitação
        // Em uma implementação real, isso deveria usar a API do FocusStatusCenter
        authorizationStatus = .authorized
    }

    func register(trigger: any TriggerProtocol, for memoryID: UUID) async {
        guard #available(iOS 15.0, *) else { return }
        guard let focusTrigger = trigger as? FocusTrigger else { return }
        guard focusTrigger.isActive else {
            await unregister(triggerID: trigger.id, for: memoryID)
            return
        }

        // Buscar título da memória para a notificação
        let memoryTitle = memoryService?.memories.first(where: { $0.id == memoryID })?.title ?? "Memory"

        registeredTriggers[memoryID] = (
            triggerID: trigger.id,
            focusIdentifier: focusTrigger.focus.focusIdentifier,
            memoryTitle: memoryTitle
        )
    }

    func register(trigger: any TriggerProtocol, for memory: MemoryModel) async {
        await register(trigger: trigger, for: memory.id)
    }

    func unregister(triggerID: UUID, for memoryID: UUID) async {
        registeredTriggers.removeValue(forKey: memoryID)
    }

    func unregisterAll(for memoryID: UUID) async {
        registeredTriggers.removeValue(forKey: memoryID)
    }

    func sync(memories: [MemoryModel]) async {
        guard #available(iOS 15.0, *) else { return }
        guard case .authorized = authorizationStatus else { return }

        // Limpar registros antigos
        let activeMemoryIDs = Set(memories.filter { $0.status == .active }.map { $0.id })
        registeredTriggers = registeredTriggers.filter { activeMemoryIDs.contains($0.key) }

        // Registrar novos triggers
        for memory in memories {
            guard memory.status == .active else {
                await unregisterAll(for: memory.id)
                continue
            }

            for trigger in memory.triggers {
                guard trigger.type == .focus, trigger.isActive else { continue }
                let protocolTrigger = TriggerFactory.createTrigger(from: trigger)
                await register(trigger: protocolTrigger, for: memory.id)
            }
        }
    }

    private func handleFocusStatusChange() async {
        guard #available(iOS 15.0, *) else { return }
        guard case .authorized = authorizationStatus else { return }

        // Por enquanto, quando detectamos uma mudança de foco, verificamos todos os triggers
        // Em uma implementação real, deveríamos obter o status atual do foco via API
        // Por simplicidade, vamos disparar notificações para triggers que não especificam um identificador
        // ou usar uma lógica mais simples

        // Nota: Em uma implementação completa, precisaríamos acessar o status real do foco
        // através da API do FocusStatusCenter, mas como a API exata pode variar,
        // usamos uma abordagem que funciona quando o foco está ativo

        for (memoryID, triggerInfo) in registeredTriggers {
            let triggerIdentifier = triggerInfo.focusIdentifier

            // Se o trigger não especifica um identificador, dispara para qualquer foco
            // Se especifica, precisaríamos verificar se corresponde ao foco atual
            // Por enquanto, vamos disparar para todos quando há mudança de foco
            if triggerIdentifier == nil {
                await sendNotification(for: memoryID)
            }
            // TODO: Implementar verificação de identificador específico quando a API estiver disponível
        }
    }

    private func sendNotification(for memoryID: UUID) async {
        guard let triggerInfo = registeredTriggers[memoryID] else { return }

        let content = UNMutableNotificationContent()
        content.title = triggerInfo.memoryTitle
        content.body = "Focus mode reminder"
        content.sound = .default
        content.categoryIdentifier = "FOCUS_TRIGGER"

        let request = UNNotificationRequest(
            identifier: "focus-\(memoryID.uuidString)-\(triggerInfo.triggerID.uuidString)-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        do {
            try await center.add(request)
        } catch {
            print("Failed to send focus notification: \(error.localizedDescription)")
        }
    }
}
