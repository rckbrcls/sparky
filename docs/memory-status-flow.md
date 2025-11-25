# Fluxo de Complete / Make Active do Memory

Este documento descreve como o aplicativo altera o status de uma memória entre **Active** e **Completed**, abrangendo entrada do usuário, camada de serviço, persistência e efeitos colaterais (notificações, geofences e listagens).

## Pontos de entrada na UI

1. **Swipe em `MemoryListItemButton`**: o botão “Mark Completed/Mark Active” dispara `MemoryService.toggleCompletion`, alternando o status do item individual.

```
72:118:i-cant-miss/Views/Shared/MemoryList/MemoryListItemButton.swift
        Button {
            Task { await toggleMemoryCompletion() }
        } label: {
            Label(memory.status == .completed ? "Mark Active" : "Mark Completed",
                  systemImage: memory.status == .completed ? "arrow.uturn.backward.circle" : "checkmark.circle")
        }
```

2. **Seleção múltipla em `MemoryMultiSelectToolbarContent`**: o menu Status chama `onSelectStatus`, que por sua vez usa `MemoryBulkActionProcessor.updateStatus` para aplicar o novo estado a vários itens.

```
59:83:i-cant-miss/Views/Memories/Components/MemoryMultiSelectToolbarContent.swift
        Menu {
            ForEach(MemoryStatus.allCases) { status in
                Button { onSelectStatus(status) } label: {
                    Label(title(for: status), systemImage: systemImage(for: status))
                }
            }
        }
```

```
46:55:i-cant-miss/Services/MemoryBulkActionProcessor.swift
    func updateStatus(of ids: Set<UUID>, to status: MemoryStatus) async -> MemoryBulkActionResult {
        await process(ids: ids) { memory in
            try await self.environment.memoryService.setStatus(memoryID: memory.id, status: status)
        }
    }
```

## Mutação na camada de serviço

### Alternância simples

`toggleCompletion` verifica o estado atual e delega para `setStatus`.

```
367:386:i-cant-miss/Services/MemoryService.swift
    func toggleCompletion(memoryID: UUID) async throws {
        guard let current = memory(id: memoryID) else {
            throw MemoryServiceError.memoryNotFound
        }
        let newStatus: MemoryStatus = current.status == .completed ? .active : .completed
        try await setStatus(memoryID: memoryID, status: newStatus)
    }
```

### Persistência via `mutateMemory`

`setStatus` usa `mutateMemory`, que roda em uma task de Core Data, atualiza `statusRaw`, grava `updatedAt`, salva, reconstrói `MemoryModel`, atualiza o cache local e finalmente força `refresh`.

```
381:588:i-cant-miss/Services/MemoryService.swift
    func setStatus(memoryID: UUID, status: MemoryStatus) async throws {
        try await mutateMemory(memoryID: memoryID) { memory in
            memory.statusRaw = status.rawValue
        }
    }
```

```
559:588:i-cant-miss/Services/MemoryService.swift
    func mutateMemory(...) async throws {
        ...
        memory.updatedAt = Date()
        try context.save()
        ...
        let updatedMemory = try await fetchMemoryFromViewContext(objectID: objectID)
        updateCachedMemory(updatedMemory)
        await refresh(force: true)
    }
```

O `refresh` repopula `memories`, zera o cache de filtros e reconfigura notificações/geofences (ver próxima seção).

Além disso, o método `memories(_:includeCompleted:)` filtra automaticamente itens `completed` quando `includeCompleted` é `false`, garantindo que listas padrão mostrem apenas itens ativos.

```
154:210:i-cant-miss/Services/MemoryService.swift
        if !statuses.isEmpty {
            filtered = filtered.filter { statuses.contains($0.status) }
        } else {
            filtered = filtered.filter { memory in
                switch memory.status {
                case .active: return true
                case .completed: return includeCompleted
                }
            }
        }
```

## Efeitos colaterais automáticos

### Notificações locais

O `NotificationScheduler` só agenda alertas para memórias ativas. Ao completar uma memória, as notificações pendentes são removidas; ao reativar, são recriadas durante o próximo `refresh`.

```
42:89:i-cant-miss/Managers/NotificationScheduler.swift
    func scheduleNotifications(for memory: MemoryModel) async {
        await requestAuthorizationIfNeeded()
        guard memory.status == .active else {
            await removeNotifications(for: memory.id)
            return
        }
        await removeNotifications(for: memory.id)
        ...
    }
```

### Geofences

`GeofenceManager.sync` também ignora memórias não ativas. A sincronização é chamada após cada `refresh(force: true)`.

```
46:92:i-cant-miss/Managers/GeofenceManager.swift
        let locationTriggers = memories
            .filter { $0.status == .active }
            .flatMap { memory in ... }
```

### Cache e timeline

- `updateCachedMemory` mantém `MemoryService.memories` coerente até o `refresh`.
- As sessões de timeline (`timelineMemories`, `timelineSections`) só consideram memórias ativas com gatilhos (`hasTriggers`), então itens completados somem imediatamente da agenda.

## Regras de negócio

- **Estados válidos**: toda memória está exatamente em `active` ou `completed` (`MemoryStatus`). Não existe estado intermediário; alternar implica sobrescrever o valor anterior.
- **Critério funcional**: memórias `active` representam lembretes ainda relevantes (participam de notificações, geofences, timeline e inbox). `completed` indica compromisso cumprido; o item permanece apenas para histórico/consulta.
- **Checklist como gatilho**: se `autoCompleteOnChecklistCompletion` estiver habilitado (no draft ou globalmente), concluir todos os itens marca a memória como `completed` automaticamente, garantindo consistência entre execução e status.
- **Recorrência**: memórias com gatilhos recorrentes precisam estar `active` para que o próximo disparo seja agendado. Marcar como `completed` interrompe o ciclo; reativar recria o agendamento a partir do próximo `nextFireDate`.
- **Permissões de UI**: a ação “Mark Completed” só aparece para memórias ativas e o oposto para concluídas, evitando comandos inválidos.
- **Filtros e relatórios**: consultas padrão (timeline, inbox, contadores da home) incluem apenas `active`. Telas que exibem métricas históricas precisam passar `includeCompleted = true` explicitamente para `MemoryService`.
- **Bulk actions**: ao aplicar `Completed`/`Active` em lote, todas as regras acima são aplicadas individualmente. IDs que falham (ex.: memória inexistente) retornam erro, mas não interrompem as demais.

## Fluxo “Complete”

1. Usuário toca no swipe ou seleciona várias memórias e escolhe “Completed”.
2. `MemoryService.setStatus` grava `statusRaw = completed`, atualiza `updatedAt` e salva no Core Data.
3. `refresh` recarrega todas as memórias, atualiza caches e invoca `NotificationScheduler.refreshNotifications` + `GeofenceManager.sync`.
4. Notificações e geofences do item são removidas.
5. Listagens padrão (inbox, timeline, etc.) deixam de mostrar a memória, exceto quando filtros pedem `includeCompleted`.

## Fluxo “Make Active”

1. Usuário escolhe “Mark Active” (swipe) ou seleciona “Active” no menu de status múltiplo.
2. `MemoryService.setStatus` grava `statusRaw = active`.
3. `refresh` repovoa `memories`, notifica observadores SwiftUI e reconfigura notificações/geofences.
4. `NotificationScheduler` agenda novamente os gatilhos temporais; `GeofenceManager` volta a monitorar regiões associadas.
5. A memória reaparece nas listas e timeline, respeitando prioridade, due date e demais regras de ordenação.

## Considerações adicionais

- **Auto-complete de checklists**: quando `autoCompleteOnChecklistCompletion` está ativo, `MemoryService` pode ser chamado automaticamente por `MemoryEditorViewModel` ao detectar todos os itens concluídos, disparando o mesmo fluxo descrito acima.
- **Bulk actions**: `MemoryBulkActionProcessor` acumula resultados, permitindo feedback parcial (IDs com sucesso ou erro). Durante operações longas, a UI bloqueia novos comandos (`isPerformingBulkAction`).
- **Ambiente e sincronização**: `AppEnvironment` mantém `MemoryService` como objeto observado; qualquer mudança de status publicada aciona updates em `MemoryCardView`, `MemoryTimelineView` e demais componentes.

Com esse fluxo, completar ou reativar uma memória é sempre tratado de forma consistente, garantindo que persistência, notificações e representações visuais permaneçam sincronizadas.
