//
//  TriggerFactory.swift
//  sparky
//
//  Created by Codex on 13/10/25.
//

import Foundation

/// Factory para criar triggers a partir de dados persistidos e converter entre tipos
enum TriggerFactory {
    /// Cria um trigger específico a partir de um MemoryTriggerModel (compatibilidade com dados antigos)
    static func createTrigger(from model: MemoryTriggerModel) -> any TriggerProtocol {
        switch model.type {
        case .scheduled:
            return ScheduledTrigger(
                id: model.id,
                fireDate: model.fireDate,
                startDate: model.startDate,
                recurrenceRule: model.recurrenceRule,
                timeZoneIdentifier: model.timeZoneIdentifier,
                weekdayMask: model.weekdayMask,
                isActive: model.isActive,
                spacedStage: model.spacedStage,
                lastReviewDate: model.lastReviewDate,
                ignoreCount: model.ignoreCount
            )
        case .location:
            let locationData = LocationTrigger.LocationData(
                latitude: model.location?.latitude ?? 0,
                longitude: model.location?.longitude ?? 0,
                radius: model.location?.radius ?? 0,
                name: model.location?.name,
                event: model.location?.event ?? .onEntry
            )
            return LocationTrigger(
                id: model.id,
                startDate: model.startDate,
                isActive: model.isActive,
                location: locationData,
                spacedStage: model.spacedStage,
                lastReviewDate: model.lastReviewDate,
                ignoreCount: model.ignoreCount
            )

        case .sequential:
            let sequentialData = SequentialTrigger.SequentialData(
                sequenceID: model.sequential?.sequenceID ?? UUID(),
                stepIndex: model.sequential?.stepIndex ?? 0,
                startDate: model.sequential?.startDate,
                currentStepIndex: model.sequential?.currentStepIndex ?? 0
            )
            return SequentialTrigger(
                id: model.id,
                startDate: model.startDate,
                isActive: model.isActive,
                sequential: sequentialData,
                spacedStage: model.spacedStage,
                lastReviewDate: model.lastReviewDate,
                ignoreCount: model.ignoreCount
            )
        }
    }

    /// Cria um MemoryTriggerModel a partir de um trigger protocol (para serialização)
    static func createModel(from trigger: any TriggerProtocol) -> MemoryTriggerModel {
        switch trigger.type {
        case .scheduled:
            guard let scheduled = trigger as? ScheduledTrigger else {
                fatalError("Trigger type mismatch")
            }
            return MemoryTriggerModel(
                id: scheduled.id,
                type: .scheduled,
                fireDate: scheduled.fireDate,
                startDate: scheduled.startDate,
                recurrenceRule: scheduled.recurrenceRule,
                timeZoneIdentifier: scheduled.timeZoneIdentifier,
                weekdayMask: scheduled.weekdayMask,
                isActive: scheduled.isActive,
                location: nil,
                sequential: nil,
                spacedStage: scheduled.spacedStage,
                lastReviewDate: scheduled.lastReviewDate,
                ignoreCount: scheduled.ignoreCount
            )
        case .location:
            guard let location = trigger as? LocationTrigger else {
                fatalError("Trigger type mismatch")
            }
            let locationModel = MemoryTriggerModel.TriggerLocation(
                latitude: location.location.latitude,
                longitude: location.location.longitude,
                radius: location.location.radius,
                name: location.location.name,
                event: location.location.event
            )
            return MemoryTriggerModel(
                id: location.id,
                type: .location,
                fireDate: nil,
                startDate: location.startDate,
                recurrenceRule: nil,
                timeZoneIdentifier: nil,
                weekdayMask: 0,
                isActive: location.isActive,
                location: locationModel,

                sequential: nil,
                spacedStage: location.spacedStage,
                lastReviewDate: location.lastReviewDate,
                ignoreCount: location.ignoreCount
            )
        case .sequential:
            guard let sequential = trigger as? SequentialTrigger else {
                fatalError("Trigger type mismatch")
            }
            let sequentialModel = MemoryTriggerModel.TriggerSequential(
                sequenceID: sequential.sequential.sequenceID,
                stepIndex: sequential.sequential.stepIndex,
                startDate: sequential.sequential.startDate,
                currentStepIndex: sequential.sequential.currentStepIndex
            )
            return MemoryTriggerModel(
                id: sequential.id,
                type: .sequential,
                fireDate: nil,
                startDate: sequential.startDate,
                recurrenceRule: nil,
                timeZoneIdentifier: nil,
                weekdayMask: 0,
                isActive: sequential.isActive,
                location: nil,
                sequential: sequentialModel,
                spacedStage: sequential.spacedStage,
                lastReviewDate: sequential.lastReviewDate,
                ignoreCount: sequential.ignoreCount
            )
        }
    }

    /// Cria um trigger a partir de um MemoryTriggerDraft (compatibilidade durante transição)
    static func createTrigger(from draft: MemoryTriggerDraft) -> any TriggerProtocol {
        let model = draft.toModel()
        return createTrigger(from: model)
    }
}
