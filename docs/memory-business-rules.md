# Regras de negócio de uma memória

Este documento explica a abstração central `Memory`, detalhando como ela se relaciona com espaços, conteúdos e gatilhos (triggers). Ele complementa `docs/memory-status-flow.md` e `docs/memory-triggers.md`, servindo como referência única para produto, design e engenharia.

---

## 1. Conceito e identidade

- **Memória como cápsula** – representa qualquer lembrança, ideia ou tarefa que o usuário deseja preservar. Triggers são opcionais: a memória pode existir apenas como registro, ligada a um espaço específico.
- **Identidade** – `MemoryModel` agrega identificador (`UUID`), timestamps (`createdAt`, `updatedAt`), autorias (`createdBy`, `lastEditedBy`) e campos auxiliares como `slug` para URLs internas.
- **Associação com espaços** – cada memória pertence a um `Space` (pasta colaborativa). Existe o espaço “All Spaces” (virtual) que agrega todas as memórias; usuários podem mover memórias entre espaços.
- **Pinos e caixas de entrada** – memórias podem ser fixadas (`isPinned`) para ganhar destaque. Uma memória aparece no `Inbox` apenas se não tiver triggers e não estiver associada a um espaço (`status == .active && !hasTriggers && space == nil`).

---

## 2. Conteúdos suportados

Uma memória pode conter múltiplos blocos (`MemoryContentBlock`):

| Tipo        | Uso principal                                                       |
|-------------|--------------------------------------------------------------------|
| `richText`  | Notas livres com markdown leve                                     |
| `checklist` | Tarefas marcáveis (impactam indicadores visuais, não o status)     |
| `photos`    | Anexos de imagem                                                    |
| `links`     | Coleções de URLs                                                    |
| `audio`     | Gravações ou uploads de áudio                                      |
| `files`     | Upload de documentos genéricos                                     |

Regras gerais:
- Ordem é significativa; o editor permite reordenar.
- Cada bloco armazena metadados próprios (ex.: checklist guarda itens, fotos guardam identificadores no storage).
- Não há limite explícito por tipo, mas validações de UX aplicam quotas (ex.: tamanho máximo de upload).

---

## 3. Status e ciclo de vida

- **Estados** – `active`, `completed`, `archived`, `deleted`. Apenas `active` participa de notificações e geofences.
- **Transições** – detalhadas em `docs/memory-status-flow.md`. Destaques:
  - Completar uma memória remove notificações futuras e sinaliza cards como concluídos.
  - Reativar (`completed → active`) recria triggers válidos.
  - Arquivar remove a memória da timeline, mas preserva conteúdos e histórico.
- **Bulk actions** – timeline suporta seleção múltipla para atualizar status, prioridade, espaço e exclusão permanente.

---

## 4. Triggers (gatilhos)

Referência completa em `docs/memory-triggers.md`. Resumo:

| Tipo          | Objetivo                                                                                | Persistência chave                                            |
|---------------|-----------------------------------------------------------------------------------------|---------------------------------------------------------------|
| `scheduled`   | Notificações por data/hora, com suporte a recorrência e máscaras de dias.               | `fireDate`, `weekdayMask`, `recurrenceRule`, `endDate`.       |
| `location`    | Geofences (entrada/saída) com raio normalizado (≤ 1000 m).                              | `latitude`, `longitude`, `radius`, `event`.                   |
| `person`      | Metadado para pessoas relacionadas (sem automação ainda).                               | `displayName`, `contactIdentifier`.                           |
| `sequential`  | Liga memórias em cadeia (“depois de X faça Y”), sem replanejamento automático ainda.    | `previousMemoryID`, `nextMemoryID`.                           |

Regras centrais:
- Uma memória pode ter múltiplos triggers, inclusive de tipos distintos.
- Apenas triggers com `isActive == true` participam de cálculos (`nextFireDate`, filtros).
- `nextFireDate` de `MemoryModel` é o mínimo entre todos os gatilhos ativos que produzem uma data agendável.
- Triggers podem ser editados no editor principal; drafts (`MemoryTriggerDraft`) só viram dados persistidos no `save`.

---

## 5. Priorização e metadados adicionais

- **Prioridade** – enum (`low`, `medium`, `high`, `critical`, `none`). Influencia ordenação em listas (pinned e timeline) e aparência visual.
- **Due date** – campo opcional independente de triggers; usado principalmente para memórias sem gatilho formal.
- **Tags/labels** – ainda não implementado; espaços cumprem parte desse papel.
- **Custom fields** – futuros campos devem ser adicionados como extensões da camada de conteúdo, nunca embutidos no trigger.

---

## 6. Persistência e sincronização

- `MemoryService` é o ponto central. Operações:
  - `create` / `update` recebem `MemoryDraft`.
  - `apply` serializa `triggers` em `Memory.triggersData` (JSON) e escreve conteúdos/flags no armazenamento.
  - Após qualquer mutação, `refresh(force: true)` recarrega todas as memórias, reconfigura notificações e geofences.
- **Cache** – `MemoryService.memories` guarda snapshot em memória, usado pela timeline, busca e filtros.
- **Sincronização externa** – se houver iCloud/colaboração futura, `refresh` continua sendo a porta de entrada para rebalancear triggers.

---

## 7. Execução de efeitos

### 7.1 Notificações (`scheduled`)
- `NotificationScheduler.scheduleNotifications` é invocado apenas para memórias `active`.
- Máscara de dias gera múltiplas `UNNotificationRequest`.
- Recorrências mensais/anuais usam `UNCalendarNotificationTrigger` repetitivo.
- Sons respeitam `SettingsStore.notificationSoundEnabled`.

### 7.2 Geofences (`location`)
- `GeofenceManager.sync` limita a 20 regiões, priorizando memórias recentes.
- Raios maiores que 1000 m são rebaixados automaticamente.
- Entrada/saída disparam notificação genérica; status permanece manual.

### 7.3 Pessoa e sequência
- Atualmente não possuem automação. Servem para filtragem, exibição contextual e futuras integrações.
- Qualquer futura automação deve observar `MemoryService.toggleCompletion` para disparar efeitos quando o status muda.

---

## 8. Timeline e filtros

- **Timeline** (`MemoryTimelineView`) – exibe apenas memórias ativas com triggers `scheduled` que tenham `nextFireDate != nil` e que não estejam associadas a um espaço (`space == nil`). Visualização em calendário vertical estilo agenda, agrupando memórias por data.
- **Triggers** (`MemoryTriggersView`) – exibe memórias ativas sem triggers `scheduled` e sem espaço (`space == nil`), organizadas por tipo:
  - Location-based (apenas triggers `location`, sem `scheduled`)
  - Person-based (apenas triggers `person`, sem `scheduled`)
  - Sequential (apenas triggers `sequential`, sem `scheduled`)
- **Inbox** – memórias aparecem no inbox apenas se `status == .active && !hasTriggers && space == nil`. Uma memória com space não aparece na Timeline nem na aba Triggers, apenas no espaço correspondente.
- **Filtros disponíveis**:
  - Por tipo de conteúdo (`MemoryContentFilterType`).
  - Por tipo de trigger (`MemoryTriggerType`).
  - Exibir/ocultar `Inbox` (apenas na Timeline).
- **Busca textual** (`searchMemories`) ignora agrupamentos e retorna lista plana.
- **Pinned memories** têm lógica de ordenação própria (fire date, due date, prioridade, `updatedAt`).

---

## 9. Limites e validações

1. **Status manda** – apenas memórias `active` participam de efeitos (notificações, geofences, timeline principal).
2. **Triggers consistentes** – editar um gatilho precisa invalidar/reativar notificações correspondentes imediatamente.
3. **Campos obrigatórios** – títulos são opcionais (memórias podem começar vazias), mas salvar exige ao menos um conteúdo ou um trigger.
4. **Recorrência segura** – `weekdayMask` não pode ser vazio quando o modo “Weekdays” está habilitado.
5. **Referências cruzadas** – triggers sequenciais não podem apontar a própria memória e devem validar se IDs existem.
6. **Limites físicos** – máximo de 20 geofences, máximo de 64 notificações simultâneas (limite iOS), raio ≤ 1000 m.
7. **Privacidade** – dados de pessoa/contact ficam apenas no dispositivo até termos consentimento explícito para sincronização.

---

## 10. Fluxos resumidos

### Criar memória sem gatilho
1. Usuário abre editor, adiciona texto ou checklist.
2. Seleciona espaço, opcionalmente define prioridade/due date.
3. Salva → memória fica em `active` e aparece no `Inbox` até ganhar trigger/due date.

### Criar memória com trigger de data
1. Editor → botão “Add trigger”.
2. Define horário, recorrência, máscara de dias.
3. Ao salvar, `MemoryService` persiste e `NotificationScheduler` agenda.
4. Timeline passa a mostrar a memória na seção adequada.

### Completar memória
1. Usuário marca como `completed` (via card, multi-select ou editor).
2. `MemoryService` atualiza status, cancela notificações/geofences, remove da timeline ativa.
3. Se reativada, todos os triggers são recalculados.

### Mover entre espaços
1. Multi-select → “Move to Space”.
2. `MemoryBulkActionProcessor` invoca `memoryService.move`.
3. `refresh` garante que timeline e filtros reflitam o espaço correto.

---

## 11. Próximos passos sugeridos

- **Agenda visual** – criar modo calendário para visualizar memórias com `nextFireDate` e um painel lateral para gatilhos sem data.
- **Automação sequencial** – observar `toggleCompletion` e criar trigger temporário para o item “next”.
- **Integrações de pessoa** – explorar API de contatos/Focus shortcuts para sugerir ações quando interações acontecem.
- **Metadados avançados** – permitir tags e campos customizados mantendo separação clara entre conteúdo e triggers.

Com estas regras de negócio centralizadas, futuras evoluções podem ser discutidas com base comum entre as equipes.
