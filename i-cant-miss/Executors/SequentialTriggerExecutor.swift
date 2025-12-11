//
//  SequentialTriggerExecutor.swift
//  i-cant-miss
//
//  Created by Codex on 13/10/25.
//

import Foundation

/// Executor para triggers sequenciais - agenda automaticamente a próxima memória quando a anterior é completada
@MainActor
final class SequentialTriggerExecutor: TriggerExecutorProtocol {
    private weak var memoryService: MemoryService?

    init(memoryService: MemoryService? = nil) {
        self.memoryService = memoryService
    }

    func register(trigger: any TriggerProtocol, for memoryID: UUID) async {
        guard trigger is SequentialTrigger else { return }
        // Triggers sequenciais não precisam de registro ativo, são processados quando memórias são completadas
    }

    func unregister(triggerID: UUID, for memoryID: UUID) async {
        // Triggers sequenciais não precisam de desregistro ativo
    }

    func unregisterAll(for memoryID: UUID) async {
        // Triggers sequenciais não precisam de desregistro ativo
    }

    func sync(memories: [MemoryModel]) async {
        // Sync não é necessário para triggers sequenciais
        // Eles são processados quando memórias são completadas
    }

    /// Processa a conclusão de uma memória e agenda a próxima memória na sequência
    func handleMemoryCompletion(memoryID: UUID) async {
        guard let memoryService = memoryService else { return }

        // Buscar todas as memórias ativas com triggers sequenciais
        let allMemories = memoryService.memories

        // Encontrar memórias que referenciam esta memória como previousMemoryID
        let nextMemories = allMemories.filter { memory in
            guard memory.status == .active else { return false }
            return memory.triggers.contains { trigger in
                guard trigger.type == .sequential,
                      trigger.isActive,
                      let sequential = trigger.sequential else { return false }
                return sequential.previousMemoryID == memoryID
            }
        }

        // Para cada memória "próxima", ativar e criar trigger scheduled
        for nextMemory in nextMemories {
            await activateNextMemory(nextMemory, in: memoryService)
        }
    }

    private func activateNextMemory(_ memory: MemoryModel, in memoryService: MemoryService) async {
        // Calcular data para o dia seguinte às 9h
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let fireDate = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow) ?? tomorrow

        // Criar trigger scheduled
        let scheduledTrigger = MemoryTriggerModel(
            id: UUID(),
            type: .scheduled,
            fireDate: fireDate,
            startDate: fireDate,
            recurrenceRule: nil,
            timeZoneIdentifier: TimeZone.current.identifier,
            weekdayMask: 0,
            isActive: true,
            location: nil,
            person: nil,
            sequential: nil,
            focus: nil,
            spacedStage: 0,
            lastReviewDate: nil,
            ignoreCount: 0
        )

        // Manter triggers existentes e adicionar o scheduled
        var updatedTriggers = memory.triggers
        // Remover triggers scheduled antigos para evitar duplicação
        updatedTriggers.removeAll { $0.type == .scheduled }
        updatedTriggers.append(scheduledTrigger)

        // Criar draft com triggers atualizados
        // Convert checkItems to CheckItemDrafts
        let checkItemDrafts = memory.checkItems.map { item in
            CheckItemDraft(
                id: item.id,
                title: item.title,
                detail: item.detail ?? "",
                isCompleted: item.isCompleted,
                sortOrder: item.sortOrder,
                createdAt: item.createdAt,
                completedAt: item.completedAt
            )
        }

        let draft = MemoryDraft(
            id: memory.id,
            title: memory.title,
            status: .active, // Garantir que está ativa
            isPinned: memory.isPinned,
            dueDate: memory.dueDate,
            spaceID: memory.space?.id,
            triggers: updatedTriggers,
            note: memory.note,
            checkItems: checkItemDrafts,
            photoAttachmentIDs: memory.photoAttachmentIDs,
            linkAttachmentIDs: memory.linkAttachmentIDs,
            audioAttachmentIDs: memory.audioAttachmentIDs,
            fileAttachmentIDs: memory.fileAttachmentIDs,
            attachments: memory.attachments,
            autoCompleteOnChecklistCompletion: memory.autoCompleteOnChecklistCompletion
        )

        // Atualizar memória
        do {
            _ = try await memoryService.updateMemory(from: draft)
        } catch {
            print("Failed to activate next memory in sequence: \(error.localizedDescription)")
        }
    }
}
