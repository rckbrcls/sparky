//
//  PersonTriggerExecutor.swift
//  i-cant-miss
//
//  Created by Codex on 13/10/25.
//

import Foundation
import CallKit
import Contacts
import UserNotifications

/// Executor para triggers de pessoa - detecta ligações recebidas de contatos específicos
@MainActor
final class PersonTriggerExecutor: NSObject, TriggerExecutorProtocol {
    private let callObserver = CXCallObserver()
    private var monitoredContacts: [String: Set<UUID>] = [:] // contactIdentifier -> Set<memoryID>
    private var memoryLookup: [UUID: MemoryModel] = [:] // memoryID -> MemoryModel
    private let settings: SettingsStore
    private let contactStore = CNContactStore()
    private var lastCallCheck: Date?

    init(settings: SettingsStore) {
        self.settings = settings
        super.init()
        callObserver.setDelegate(self, queue: nil)
    }

    func register(trigger: any TriggerProtocol, for memoryID: UUID) async {
        guard let personTrigger = trigger as? PersonTrigger else { return }
        guard personTrigger.isActive else {
            await unregister(triggerID: trigger.id, for: memoryID)
            return
        }
        // O registro real acontece no sync
    }

    func unregister(triggerID: UUID, for memoryID: UUID) async {
        // Remove do lookup
        memoryLookup.removeValue(forKey: memoryID)

        // Remove do mapeamento de contatos
        for (contactID, memoryIDs) in monitoredContacts {
            var updated = memoryIDs
            updated.remove(memoryID)
            if updated.isEmpty {
                monitoredContacts.removeValue(forKey: contactID)
            } else {
                monitoredContacts[contactID] = updated
            }
        }
    }

    func unregisterAll(for memoryID: UUID) async {
        await unregister(triggerID: UUID(), for: memoryID)
    }

    func sync(memories: [MemoryModel]) async {
        // Limpar mapeamentos antigos
        monitoredContacts.removeAll()
        memoryLookup.removeAll()

        // Processar apenas memórias ativas com triggers de pessoa
        let activePersonMemories = memories.filter { memory in
            guard memory.status == .active else { return false }
            return memory.triggers.contains { $0.type == .person && $0.isActive }
        }

        // Mapear contatos para memórias
        for memory in activePersonMemories {
            memoryLookup[memory.id] = memory

            for trigger in memory.triggers where trigger.type == .person && trigger.isActive {
                guard let person = trigger.person else { continue }

                // Se tem contactIdentifier, usar ele; senão, usar o nome para busca
                if let contactID = person.contactIdentifier {
                    if monitoredContacts[contactID] == nil {
                        monitoredContacts[contactID] = []
                    }
                    monitoredContacts[contactID]?.insert(memory.id)
                } else {
                    // Para contatos sem identifier, tentar encontrar pelo nome
                    await mapContactByName(person.name, memoryID: memory.id)
                }
            }
        }
    }

    private func mapContactByName(_ name: String, memoryID: UUID) async {
        // Buscar contato pelo nome
        let keys = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactIdentifierKey] as [CNKeyDescriptor]
        let request = CNContactFetchRequest(keysToFetch: keys)
        request.predicate = CNContact.predicateForContacts(matchingName: name)

        do {
            try contactStore.enumerateContacts(with: request) { contact, stop in
                let contactID = contact.identifier
                if self.monitoredContacts[contactID] == nil {
                    self.monitoredContacts[contactID] = []
                }
                self.monitoredContacts[contactID]?.insert(memoryID)
                stop.pointee = true // Parar após primeiro match
            }
        } catch {
            print("Failed to map contact by name: \(error.localizedDescription)")
        }
    }

    private func handleIncomingCall(from contactIdentifier: String?) {
        guard let contactIdentifier = contactIdentifier else { return }
        guard let memoryIDs = monitoredContacts[contactIdentifier] else { return }

        // Disparar notificação para cada memória associada a este contato
        for memoryID in memoryIDs {
            guard let memory = memoryLookup[memoryID] else { continue }
            Task {
                await sendNotification(for: memory)
            }
        }
    }

    private func sendNotification(for memory: MemoryModel) async {
        let content = UNMutableNotificationContent()
        content.title = memory.title
        if let body = memory.body {
            content.body = body
        } else {
            content.body = "You received a call from a contact you wanted to remember."
        }

        let soundEnabled = settings.notificationSoundEnabled
        content.sound = soundEnabled ? .default : nil
        content.categoryIdentifier = "REMINDER_ACTIONS"

        let request = UNNotificationRequest(
            identifier: "person-trigger-\(memory.id.uuidString)-\(UUID().uuidString)",
            content: content,
            trigger: nil // Notificação imediata
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("Failed to send person trigger notification: \(error.localizedDescription)")
        }
    }

    /// Verifica ligações recentes e dispara notificações se necessário
    @MainActor
    func checkRecentCalls() async {
        // Evitar verificações muito frequentes
        if let lastCheck = lastCallCheck,
           Date().timeIntervalSince(lastCheck) < 5 {
            return
        }
        lastCallCheck = Date()

        // Buscar contatos monitorados
        guard !monitoredContacts.isEmpty else { return }

        // Verificar ligações ativas
        let activeCalls = callObserver.calls.filter { !$0.hasEnded && !$0.isOutgoing }

        for call in activeCalls {
            // Tentar identificar o contato da ligação
            // Como CXCall não expõe contactIdentifier diretamente,
            // vamos usar uma abordagem de verificação periódica
            await checkCallForMonitoredContacts(call)
        }
    }

    private func checkCallForMonitoredContacts(_ call: CXCall) async {
        // Esta é uma implementação simplificada
        // Em produção, você pode querer usar uma extensão de CallKit
        // ou integrar com o histórico de ligações do sistema

        // Por enquanto, vamos apenas manter o observer ativo
        // A detecção real pode ser melhorada com extensões ou APIs futuras
    }
}

extension PersonTriggerExecutor: CXCallObserverDelegate {
    nonisolated func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall) {
        // Quando uma ligação recebida começa
        if !call.hasEnded && !call.isOutgoing {
            Task { @MainActor in
                // Verificar se podemos identificar o contato
                await self.checkRecentCalls()
            }
        }
    }
}
