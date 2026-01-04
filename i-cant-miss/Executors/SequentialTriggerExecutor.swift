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

    /// Processa a conclusão de uma memória e avança para o próximo passo na sequência (ciclicamente)
    func handleMemoryCompletion(memoryID: UUID) async {
        guard let memoryService = memoryService else { return }

        // 1. Encontrar a memória que acabou de ser concluída
        guard let completedMemory = memoryService.memory(id: memoryID) else { return }

        // 2. Encontrar triggers sequenciais ativos
        let activeSeqTriggers = completedMemory.triggers.filter { $0.isActive && $0.type == .sequential }

        for trigger in activeSeqTriggers {
            guard let seqInfo = trigger.sequential else { continue }

            // Só processar se a memória completada é o passo atual
            guard seqInfo.stepIndex == seqInfo.currentStepIndex else { continue }

            let sequenceID = seqInfo.sequenceID

            // 3. Encontrar todas as memórias na sequência
            let sequenceMemories = memoryService.memories.filter { memory in
                memory.triggers.contains { t in
                    t.type == .sequential && t.sequential?.sequenceID == sequenceID
                }
            }

            // 4. Encontrar o maior stepIndex na sequência
            let maxStepIndex = sequenceMemories.compactMap { memory -> Int? in
                memory.triggers.first(where: { $0.type == .sequential })?.sequential?.stepIndex
            }.max() ?? 0

            // 5. Calcular próximo passo (cíclico: volta para 0 após o último)
            let nextStepIndex = (seqInfo.currentStepIndex + 1) > maxStepIndex ? 0 : (seqInfo.currentStepIndex + 1)

            // 6. Atualizar currentStepIndex para TODAS as memórias na sequência
            // e resetar status para .active na memória que se torna "current"
            for memory in sequenceMemories {
                let isNextCurrent = memory.triggers.first(where: { $0.type == .sequential })?.sequential?.stepIndex == nextStepIndex
                await updateCurrentStepIndex(memory: memory, newCurrentStepIndex: nextStepIndex, startDate: seqInfo.startDate, resetStatus: isNextCurrent, in: memoryService)
            }
        }
    }

    /// Atualiza o currentStepIndex de uma memória mantendo os outros campos
    /// - Parameters:
    ///   - memory: A memória a ser atualizada
    ///   - newCurrentStepIndex: O novo índice do passo atual
    ///   - startDate: Data de início da sequência
    ///   - resetStatus: Se true, reseta o status para .active (usado quando a memória se torna a "current")
    ///   - memoryService: Serviço para persistir as alterações
    private func updateCurrentStepIndex(memory: MemoryModel, newCurrentStepIndex: Int, startDate: Date?, resetStatus: Bool, in memoryService: MemoryService) async {
        var updatedTriggers = memory.triggers

        guard let index = updatedTriggers.firstIndex(where: { $0.type == .sequential }),
              let currentSeq = updatedTriggers[index].sequential else {
            return
        }

        // Atualizar apenas o currentStepIndex, mantendo tudo mais
        let updatedSeq = MemoryTriggerModel.TriggerSequential(
            sequenceID: currentSeq.sequenceID,
            stepIndex: currentSeq.stepIndex,
            startDate: startDate,
            currentStepIndex: newCurrentStepIndex
        )

        updatedTriggers[index] = MemoryTriggerModel(
            id: updatedTriggers[index].id,
            type: .sequential,
            fireDate: updatedTriggers[index].fireDate,
            startDate: updatedTriggers[index].startDate,
            recurrenceRule: updatedTriggers[index].recurrenceRule,
            timeZoneIdentifier: updatedTriggers[index].timeZoneIdentifier,
            weekdayMask: updatedTriggers[index].weekdayMask,
            isActive: updatedTriggers[index].isActive,
            isAllDay: updatedTriggers[index].isAllDay,
            location: updatedTriggers[index].location,
            sequential: updatedSeq,
            spacedStage: updatedTriggers[index].spacedStage,
            lastReviewDate: updatedTriggers[index].lastReviewDate,
            ignoreCount: updatedTriggers[index].ignoreCount
        )

        // Criar draft e atualizar
        // Se resetStatus é true, reseta o status para .active (para permitir completar novamente no ciclo)
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
            status: resetStatus ? .active : memory.status,
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

        do {
            _ = try await memoryService.updateMemory(from: draft)
        } catch {
            print("Failed to update currentStepIndex in sequence: \(error.localizedDescription)")
        }
    }
}
