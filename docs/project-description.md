# Descrição do Projeto: i-cant-miss

## Visão Geral

**i-cant-miss** é um aplicativo iOS nativo desenvolvido em Swift/SwiftUI para gerenciamento inteligente de memórias, lembretes e tarefas. O app permite criar "memórias" (qualquer ideia, tarefa ou lembrete) com múltiplos tipos de conteúdo e gatilhos (triggers) que disparam notificações, geofences e outras ações automatizadas.

### Conceito Central

- **Memória**: Unidade central que representa qualquer lembrança, ideia ou tarefa que o usuário deseja preservar
- **Espaços**: Organização hierárquica (pastas) para categorizar memórias, similar a projetos ou contextos
- **Triggers**: Gatilhos que disparam ações automatizadas (data/hora, localização, pessoa, sequência)
- **Conteúdos**: Múltiplos blocos de conteúdo por memória (texto rico, checklist, fotos, links, áudio, arquivos)
- **Status**: Ciclo de vida (`active` → `completed`) que controla participação em notificações, geofences e timeline

---

## Arquitetura e Estrutura

### Padrão Arquitetural

- **MVVM (Model-View-ViewModel)** com SwiftUI
- **Service Layer**: Lógica de negócio centralizada em serviços
- **Manager Pattern**: Componentes especializados (notificações, geofences)
- **Repository Pattern**: Persistência via Core Data com camada de abstração

### Componentes Principais

```
AppEnvironment (Singleton @MainActor, ObservableObject)
├── PersistenceController (Core Data stack)
├── MemoryService (@MainActor, CRUD + lógica de memórias)
├── SpaceService (@MainActor, CRUD + hierarquia de espaços)
├── NotificationScheduler (@MainActor, notificações locais)
├── GeofenceManager (@MainActor, monitoramento de localização)
├── MemoryAttachmentStore (actor, armazenamento de anexos)
└── SettingsStore (@MainActor, preferências do usuário)
```

### Convenções de Código

- **Separação de arquivos**: Cada componente em arquivo próprio e modularizado
- **Inglês obrigatório**: Variáveis, métodos, propriedades, textos em código sempre em inglês
- **Respostas em português**: Comunicação com usuário e documentação em português
- **Sem código legado**: Deletar código antigo ao refatorar, não manter migrações ou compatibilidade
- **Código limpo**: Remover código deprecado e funcionalidades incomuns

---

## Modelo de Dados

### Core Data Entities

#### Memory
- `id: UUID` (identificador único)
- `title: String` (título obrigatório, validado antes de salvar)
- `body: String?` (texto agregado automaticamente dos conteúdos richText)
- `statusRaw: String` ("active" | "completed" - apenas esses dois estados)
- `priorityRaw: Int16?` (low=0, medium=1, high=2, noPriority=-1)
- `isPinned: Bool` (fixado na timeline, influencia ordenação)
- `dueDate: Date?` (data de vencimento independente de triggers)
- `autoCompleteOnChecklistCompletion: Bool` (auto-completar memória quando checklist termina)
- `triggersData: Data?` (JSON serializado: `[MemoryTriggerModel]`)
- `contentsData: Data?` (JSON serializado: `MemoryDomain.MemoryContentBundle`)
- `createdAt: Date`, `updatedAt: Date` (timestamps automáticos)
- `userOrder: Int16` (ordenação manual)
- `space: Space?` (relacionamento opcional, Nullify on delete)

#### Space
- `id: UUID`
- `name: String` (obrigatório, validado)
- `colorHex: String?` (cor hexadecimal para UI)
- `iconName: String?` (SF Symbol name)
- `sortOrder: Int16` (ordenação manual)
- `isDefault: Bool` (apenas um espaço pode ser default)
- `parent: Space?` (hierarquia, permite subespaços)
- `children: Set<Space>` (subespaços, Nullify on delete)
- `memories: Set<Memory>` (memórias neste espaço)

#### Tag
- `id: UUID`
- `name: String`
- `colorHex: String?`

**Observação**: Tags ainda não estão totalmente integradas ao modelo de memórias.

### Modelos de Domínio (MemoryDomain.swift)

#### MemoryModel
Estrutura de valor imutável usada pela UI e serviços:

```swift
struct MemoryModel {
    let id: UUID
    var title: String
    var body: String?
    var status: MemoryStatus // .active | .completed
    var isPinned: Bool
    var priority: MemoryPriority?
    var dueDate: Date?
    var space: SpaceModel?
    var triggers: [MemoryTriggerModel]
    var checkItems: [CheckItemModel]
    var contents: [MemoryContent] // enum com múltiplos tipos
    var attachments: [Attachment]
    var autoCompleteOnChecklistCompletion: Bool

    // Propriedades computadas
    var hasTriggers: Bool
    var hasRecurringTriggers: Bool
    var isInbox: Bool // status == .active && !hasTriggers && space == nil
    func nextFireDate(referenceDate: Date) -> Date?
}
```

#### MemoryTriggerModel
Gatilho que pode ser de 4 tipos:

- **scheduled**: Data/hora com recorrência opcional e máscara de dias da semana
- **location**: Geofence (latitude, longitude, raio, evento entrada/saída)
- **person**: Pessoa relacionada (nome, contactIdentifier) - atualmente apenas metadado
- **sequential**: Relacionamento entre memórias (previousMemoryID, nextMemoryID) - atualmente apenas informativo

Cada trigger tem:
- `id: UUID`
- `type: MemoryTriggerType`
- `isActive: Bool` (apenas triggers ativos participam de cálculos)
- `fireDate: Date?` (data/hora do disparo)
- `startDate: Date?` (data de início para triggers que começam no futuro)
- `recurrenceRule: RecurrenceRule?` (frequência: daily/weekly/monthly/yearly, intervalo, endDate)
- `weekdayMask: Int16` (bitmask para dias da semana selecionados)
- Dados específicos do tipo (location, person, sequential)

#### MemoryContent
Enum que representa diferentes tipos de conteúdo:

```swift
enum MemoryContent {
    case richText(String)
    case checklist([CheckItemModel])
    case photos([UUID]) // IDs dos attachments
    case links([UUID])
    case audio([UUID])
    case files([UUID])
}
```

**Importante**: Anexos (photos, links, audio, files) são armazenados separadamente no `MemoryAttachmentStore` e referenciados por ID no conteúdo.

#### MemoryDraft
Versão editável usada no `MemoryEditorViewModel` antes de persistir:

```swift
struct MemoryDraft {
    let id: UUID
    var title: String
    var status: MemoryStatus
    var priority: MemoryPriority?
    var isPinned: Bool
    var dueDate: Date?
    var spaceID: UUID?
    var triggers: [MemoryTriggerModel]
    var contents: [MemoryContent]
    var attachments: [MemoryModel.Attachment]
    var autoCompleteOnChecklistCompletion: Bool
}
```

---

## Serviços e Managers

### MemoryService

**Localização**: `i-cant-miss/Services/MemoryService.swift`

Serviço principal para operações com memórias:

#### Responsabilidades

1. **CRUD completo**: `createMemory`, `updateMemory`, `deleteMemory`, `memory(id:)`
2. **Queries complexas**:
   - `memories(in:includeDescendants:statuses:includeCompleted:sort:)` - filtragem avançada
   - `timelineMemories(referenceDate:)` - apenas ativas com triggers e nextFireDate válido
   - `timelineSections(referenceDate:)` - agrupa em seções (Today, Next 7 Days, Later, Recurring)
   - `inboxMemories()` - memórias sem trigger nem espaço
   - `searchMemories(query:)` - busca textual em título e body
3. **Mutações de status/prioridade**: `setStatus`, `toggleCompletion`, `setPriority`, `togglePin`, `moveMemory`
4. **Sincronização**: `refresh(force:)` recarrega tudo do Core Data, limpa cache e reconfigura notificações/geofences
5. **Cache**: Mantém `memories: [MemoryModel]` em memória com TTL de 30 segundos

#### Fluxo de Persistência

1. `MemoryEditorViewModel.save()` cria `MemoryDraft`
2. `MemoryService.createMemory/updateMemory(from:)` chama `persist(draft:isUpdate:)`
3. `persist` roda em background context, chama `apply(draft:to:context:)` que:
   - Atualiza campos diretos
   - Serializa `triggers` → JSON → `triggersData`
   - Serializa `contents` → JSON → `contentsData`
   - Agrega textos → `body`
   - Salva contexto
4. `MemoryAttachmentStore.replaceAttachments` persiste anexos em disco
5. `refresh(force: true)` recarrega, atualiza cache e reconfigura notificações/geofences

#### Regras Importantes

- **Status manda**: Apenas memórias `active` participam de notificações, geofences e timeline
- **Validação**: Título não pode ser vazio
- **Refresh centralizado**: Qualquer mutação dispara `refresh(force: true)` para garantir sincronização
- **Thread safety**: Operações de Core Data em background contexts, modelo reconstruído no view context

### SpaceService

**Localização**: `i-cant-miss/Services/SpaceService.swift`

Gerenciamento de espaços hierárquicos:

#### Responsabilidades

1. **CRUD**: `createSpace`, `updateSpace`, `deleteSpace`, `space(id:)`
2. **Hierarquia**:
   - `rootSpaces()` - espaços sem parent
   - `children(of:)` - subespaços
   - `descendantIDs(of:)` - todos os descendentes (recursivo)
   - `isValidMove(space:targetParentID:)` - previne ciclos
3. **Tags**: `createTag`, `deleteTag`, `refreshTags`
4. **Refresh**: Mantém cache similar ao MemoryService

#### Regras Importantes

- Apenas um espaço pode ser `isDefault: true`
- Espaço default não pode ser deletado
- Hierarquia pode ter múltiplos níveis (parent → children → grandchildren)
- Ao deletar espaço, memórias podem ser deletadas também ou movidas (Nullify)

### NotificationScheduler

**Localização**: `i-cant-miss/Managers/NotificationScheduler.swift`

Gerencia notificações locais para triggers `scheduled`:

#### Responsabilidades

1. **Autorização**: `requestAuthorizationIfNeeded()` solicita permissão uma vez
2. **Agendamento**: `scheduleNotifications(for:)` cria `UNNotificationRequest` apenas para memórias `active`
3. **Lógica de recorrência**:
   - `weekdayMask != 0`: Cria múltiplas requests (uma por dia selecionado) com `UNCalendarNotificationTrigger(repeats: true)`
   - `recurrenceRule != nil`: Cria trigger recorrente mensal/anual
   - Caso simples: Trigger único não-recorrente
4. **Remoção**: `removeNotifications(for:)` remove todas as notificações pendentes de uma memória
5. **Refresh completo**: `refreshNotifications(memories:)` remove todas e recria

#### Regras Importantes

- Respeita `SettingsStore.notificationSoundEnabled`
- Remove notificações antigas antes de criar novas (evita duplicatas)
- Apenas memórias `active` têm notificações agendadas
- Identificadores: `"memory-{memoryID}-{triggerID}"` ou `"...-{day}"` para weekdayMask

### GeofenceManager

**Localização**: `i-cant-miss/Managers/GeofenceManager.swift`

Monitora regiões geográficas para triggers `location`:

#### Responsabilidades

1. **Autorização**: `requestAuthorization(always:)` solicita permissão Always (necessária para geofences)
2. **Sincronização**: `sync(memories:)` filtra memórias ativas com triggers `.location`, limita a 20 regiões (preferindo mais recentes) e:
   - Remove regiões não mais monitoradas
   - Adiciona novas regiões
3. **Eventos**: `didEnterRegion` / `didExitRegion` disparam notificação genérica imediatamente
4. **Normalização**: Raios maiores que 1000m são ajustados para 1000m (limite iOS)

#### Regras Importantes

- Máximo de 20 geofences simultâneas (limite iOS)
- Apenas memórias `active` participam
- Regiões priorizadas por `updatedAt` (mais recentes primeiro)
- Notificações são genéricas; usuário precisa abrir app para marcar como completo
- Identificadores: `"memory-{memoryID}-location-{triggerID}"`

### MemoryAttachmentStore

**Localização**: `i-cant-miss/Managers/MemoryAttachmentStore.swift`

Armazenamento de anexos em disco (fotos, links, áudio, arquivos):

#### Responsabilidades

1. **Armazenamento**: Anexos salvos em `ApplicationSupport/MemoryAttachments/{memoryID}/`
2. **Tipos suportados**:
   - Fotos: `.jpg` (data binária)
   - Links: `.json` (URL serializado)
   - Áudio: `.m4a`, `.mp3`, `.wav`, etc. (data binária)
   - Arquivos: qualquer extensão com prefixo `{uuid}_file_{filename}`
3. **Queries**: `attachments(for:)` carrega todos os anexos de uma memória
4. **Substituição atômica**: `replaceAttachments(for:with:)` remove diretório antigo e cria novo
5. **Limpeza**: `deleteAllAttachments(for:)` remove diretório completo

#### Regras Importantes

- Actor isolado para thread safety
- Anexos referenciados por UUID no conteúdo JSON
- Links armazenados como JSON, não como arquivos binários
- Fotos sempre convertidas para JPG

### SettingsStore

**Localização**: `i-cant-miss/Settings/SettingsStore.swift`

Preferências do usuário persistidas em `UserDefaults`:

#### Propriedades

- `defaultTimelineFilter: MemoryTimelineFilter`
- `defaultMemoryPriority: MemoryPriority`
- `defaultSnoozeMinutes: Int` (clamp 1-1440)
- `defaultPostponeMinutes: Int` (clamp 1-1440)
- `notificationSoundEnabled: Bool` (default: true)
- `preferAlwaysOnLocationAccess: Bool` (default: false)
- `hasCompletedOnboarding: Bool`

---

## ViewModels

### MemoryEditorViewModel

**Localização**: `i-cant-miss/ViewModels/MemoryEditorViewModel.swift`

ViewModel principal para criação/edição de memórias:

#### Estado Publicado

```swift
@Published var title: String
@Published var selectedSpaceID: UUID?
@Published var status: MemoryStatus
@Published var priority: MemoryPriority
@Published var isPinned: Bool
@Published var autoCompleteChecklist: Bool
@Published var triggers: [MemoryTriggerDraft]
@Published var contentQueue: [MemoryEditorContentItem]
@Published var isSaving: Bool
@Published var errorMessage: String?
```

#### Responsabilidades

1. **Gerenciamento de conteúdo**:
   - `appendContent(_:)` - adiciona novo bloco (richText, checklist, photos, etc.)
   - `removeContent(id:)` - remove bloco
   - `updateRichText(id:text:)` - atualiza texto
   - Helpers para anexos: `addPhotoAttachment`, `removePhotoAttachment`, etc.
2. **Gerenciamento de triggers**:
   - `setScheduledTrigger` - configura trigger de data/hora
   - `addLocationTrigger` - adiciona geofence
   - `addPersonTrigger` - adiciona pessoa
   - `updateSequentialTrigger` - configura sequência
   - `removeTrigger(id:)` - remove trigger
3. **Checklist**:
   - `addChecklistItem`, `removeChecklistItem`, `toggleChecklistCompletion`
4. **Persistência**:
   - `save()` - cria/atualiza memória via `MemoryService`
   - Converte `MemoryTriggerDraft` → `MemoryTriggerModel` antes de salvar

#### Draft vs Model

- **Draft**: Usado durante edição (mutável, pode ter estado inválido temporariamente)
- **Model**: Versão persistida (imutável, sempre válida)
- Conversão: `draft.toModel()` no momento do save

---

## Fluxos Principais

### 1. Criar Nova Memória

1. Usuário toca botão "+" na tab bar
2. `ContentView.prepareMemoryCreation()` cria `MemoryEditorRoute(mode: .create)`
3. `MemoryEditorView` inicializa com `MemoryEditorViewModel(memory: nil, template: .blank)`
4. Usuário edita título, adiciona conteúdos, configura triggers
5. `MemoryEditorViewModel.save()` cria `MemoryDraft`
6. `MemoryService.createMemory(from:)` persiste no Core Data
7. `MemoryAttachmentStore.replaceAttachments` salva anexos
8. `MemoryService.refresh(force: true)` recarrega tudo e configura notificações/geofences
9. UI atualiza automaticamente via `@Published` properties

### 2. Completar Memória (Toggle Status)

1. Usuário faz swipe em `MemoryListItemButton` → "Mark Completed"
2. Chama `MemoryService.toggleCompletion(memoryID:)`
3. `setStatus(memoryID:status: .completed)` atualiza `statusRaw` no Core Data
4. `mutateMemory` salva e atualiza cache
5. `refresh(force: true)` remove notificações/geofences (apenas `active` participam)
6. Memória desaparece da timeline (filtra `status == .active && hasTriggers`)

**Ver documentação completa**: `docs/memory-status-flow.md`

### 3. Adicionar Trigger de Data/Hora

1. Usuário toca "Add Trigger" no editor
2. `MemoryTriggerPickerSheet` abre
3. Seleciona "Date & Time"
4. `MemoryDateAndTimeTriggerEditorScreen` permite:
   - Escolher horário (`DatePicker`)
   - Selecionar recorrência (daily/weekly/monthly/yearly)
   - Escolher dias da semana (`MemoryWeekdaySelectionView`)
5. ViewModel chama `setScheduledTrigger(fireDate:recurrence:weekdaySelection:)`
6. Cria/atualiza `MemoryTriggerDraft` com `weekdayMask` e `recurrenceRule`
7. Ao salvar memória, trigger é convertido para `MemoryTriggerModel` e persistido
8. `NotificationScheduler.scheduleNotifications` cria `UNNotificationRequest`(s)

**Ver documentação completa**: `docs/memory-triggers.md`

### 4. Adicionar Trigger de Localização

1. Usuário seleciona "Location" no picker
2. `LocationPickerView` abre com mapa interativo
3. Usuário pode:
   - Buscar lugar (`MKLocalSearch`)
   - Selecionar no mapa
   - Inserir manualmente
4. Define raio (padrão 200m, máximo 1000m) e evento (entrada/saída)
5. `addLocationTrigger(name:latitude:longitude:radius:event:)` cria draft
6. Ao salvar, `GeofenceManager.sync` adiciona `CLCircularRegion` ao `CLLocationManager`
7. Quando sistema dispara evento, `didEnterRegion`/`didExitRegion` mostra notificação

### 5. Timeline e Filtros

1. `MemoryTimelineView` chama `MemoryService.timelineSections(referenceDate:)`
2. Service filtra: `status == .active && hasTriggers && nextFireDate != nil`
3. Agrupa em seções:
   - **Today**: `nextFireDate` hoje
   - **Next 7 Days**: próximos 7 dias
   - **Later**: após 7 dias
   - **Recurring**: memórias com `hasRecurringTriggers`
4. Filtros adicionais:
   - Por tipo de trigger (scheduled, location, person, sequential)
   - Por tipo de conteúdo (richText, checklist, photos, etc.)
   - Por seção temporal
   - Inbox (mostrar/ocultar)

---

## Regras de Negócio Críticas

### Status e Ciclo de Vida

1. **Apenas dois estados**: `active` e `completed` (não existe `archived` ou `deleted` no enum)
2. **Status manda**: Memórias `completed`:
   - Não aparecem na timeline principal
   - Não têm notificações agendadas
   - Não têm geofences monitoradas
   - Podem aparecer em listas se `includeCompleted = true`
3. **Toggle simples**: `toggleCompletion` alterna entre os dois estados
4. **Reativação**: Ao reativar (`completed → active`), notificações/geofences são recriadas no próximo `refresh`

### Triggers

1. **Apenas `active` contam**: `nextFireDate` considera apenas triggers com `isActive == true`
2. **Múltiplos triggers**: Uma memória pode ter vários triggers de tipos diferentes
3. **Próximo disparo**: `MemoryModel.nextFireDate` retorna o mínimo entre todos os triggers ativos
4. **Triggers informativos**: `person` e `sequential` não têm automação ainda (apenas metadado)
5. **Validação**: Máscara de dias não pode ser vazia quando modo "Weekdays" está habilitado

### Conteúdos

1. **Ordem significativa**: `contentQueue` mantém ordem dos blocos
2. **Anexos separados**: Fotos/links/áudio/arquivos são armazenados em disco, referenciados por ID no JSON
3. **Checklist**: Itens podem ser marcados como completos; isso não altera status da memória (exceto se `autoCompleteOnChecklistCompletion = true`)
4. **Body agregado**: `body` é preenchido automaticamente concatenando todos os blocos `richText`

### Espaços

1. **Hierarquia**: Espaços podem ter parent/children (múltiplos níveis)
2. **All Spaces**: Espaço virtual com ID `00000000-0000-0000-0000-000000000000` que agrega todas as memórias
3. **Default único**: Apenas um espaço pode ser `isDefault: true`
4. **Filtragem**: `memories(in:includeDescendants:)` pode incluir memórias de subespaços recursivamente

### Persistência

1. **Refresh centralizado**: Qualquer mutação (create/update/delete/status change) dispara `refresh(force: true)`
2. **Cache com TTL**: Cache de 30 segundos para queries filtradas
3. **Background contexts**: Operações de escrita sempre em background contexts
4. **Thread safety**: `@MainActor` em serviços, `actor` no AttachmentStore

### Notificações e Geofences

1. **Limites físicos**:
   - Máximo 20 geofences simultâneas
   - Máximo 64 notificações pendentes (limite iOS)
   - Raio máximo 1000m para geofences
2. **Autorizações**:
   - Notificações: `.alert`, `.badge`, `.sound`
   - Geofences: `always` (não funciona com `whenInUse`)
3. **Som configurável**: `SettingsStore.notificationSoundEnabled` controla som das notificações

---

## Estrutura de Pastas

```
i-cant-miss/
├── AppEnvironment.swift (inicialização e coordenação)
├── i_cant_missApp.swift (entry point)
├── ContentView.swift (root view com tabs)
├── Persistence.swift (Core Data stack)
├── Info.plist
│
├── Model/
│   └── MemoryDomain.swift (todos os modelos de domínio)
│
├── Services/
│   ├── MemoryService.swift
│   ├── SpaceService.swift
│   └── MemoryBulkActionProcessor.swift
│
├── Managers/
│   ├── NotificationScheduler.swift
│   ├── GeofenceManager.swift
│   └── MemoryAttachmentStore.swift
│
├── ViewModels/
│   ├── MemoryEditorViewModel.swift
│   └── MemoryEditorContentItem.swift
│
├── Views/
│   ├── Memories/
│   │   ├── MemoryCardView.swift
│   │   ├── MemoryTimelineView.swift
│   │   ├── Editor/
│   │   │   ├── MemoryEditorView.swift
│   │   │   ├── Components/ (cards de conteúdo)
│   │   │   ├── Checklist/ (componentes de checklist)
│   │   │   └── Triggers/ (UI de triggers)
│   │   ├── Components/ (filtros, multi-select)
│   │   └── SpaceDetail/ (detalhes de espaço)
│   ├── Onboarding/
│   ├── Settings/
│   └── Shared/ (lista, empty states)
│
├── Settings/
│   └── SettingsStore.swift
│
├── Utilities/
│   ├── Color+Hex.swift
│   ├── PhotoPickerLoadedImage.swift
│   ├── SpeechTranscriber.swift
│   └── String+Optional.swift
│
└── Extensions/
    └── LiquidGlassModifier.swift (efeitos visuais)
```

---

## Tecnologias e Frameworks

### Principais

- **SwiftUI**: Interface declarativa
- **Core Data**: Persistência com CloudKit habilitado (`usedWithCloudKit="true"`)
- **Combine**: Reactive programming para `@Published` e timers
- **UserNotifications**: Notificações locais
- **CoreLocation**: Geofences e monitoramento de localização
- **MapKit**: Visualização de mapas no location picker
- **Contacts**: Acesso à agenda (trigger de pessoa)

### Padrões de Concorrência

- **@MainActor**: Serviços e ViewModels (UI thread)
- **actor**: MemoryAttachmentStore (isolamento de thread)
- **async/await**: Operações assíncronas
- **Task/Background contexts**: Core Data operations

---

## Documentação de Referência

### Arquivos de Documentação

1. **`docs/memory-business-rules.md`**: Regras de negócio completas sobre memórias, espaços, conteúdos e triggers
2. **`docs/memory-status-flow.md`**: Fluxo detalhado de Complete/Make Active, incluindo efeitos colaterais
3. **`docs/memory-triggers.md`**: Detalhes sobre modelagem, edição, persistência e execução de cada tipo de trigger
4. **`docs/trigger-capabilities.md`**: Catálogo de triggers suportados hoje e potenciais futuros com APIs nativas

### Pontos de Entrada Importantes

- **Entry point**: `i_cant_missApp.swift` → `ContentView` → tabs
- **Criação de memória**: `ContentView` → `MemoryEditorRoute` → `MemoryEditorView`
- **Timeline**: `MemoryTimelineView` → `MemoryService.timelineSections`
- **Espaços**: `SpacesRootView` → `SpaceDetailView`
- **Bootstrap**: `AppEnvironment.bootstrap()` carrega dados iniciais e solicita permissões

---

## Considerações Especiais para IA Assistente

### Ao Criar/Modificar Código

1. **Sempre criar arquivos separados** para novos componentes (não colocar múltiplos componentes no mesmo arquivo)
2. **Usar inglês** para nomes de variáveis, métodos, propriedades
3. **Respeitar padrões existentes**: Ver como outros componentes similares estão implementados
4. **Não criar migrações**: Se refatorar, deletar código antigo completamente
5. **Manter separação de responsabilidades**: Services para lógica, Managers para recursos do sistema, ViewModels para estado da UI

### Ao Trabalhar com Core Data

1. **Sempre usar background contexts** para escrita (`persistence.performBackgroundTask`)
2. **Atualizar cache imediatamente** após mutações (`updateCachedMemory`)
3. **Chamar refresh** após qualquer mutação (`refresh(force: true)`)
4. **Serializar triggers/contents** em JSON antes de salvar

### Ao Trabalhar com Notificações/Geofences

1. **Verificar status da memória** antes de agendar (apenas `active`)
2. **Remover notificações antigas** antes de criar novas
3. **Respeitar limites** (20 geofences, 64 notificações)
4. **Normalizar raios** para máximo 1000m

### Ao Criar Novos Triggers

1. Adicionar tipo ao `MemoryTriggerType` enum
2. Adicionar dados específicos em `MemoryTriggerModel` (struct aninhada se necessário)
3. Atualizar `MemoryTriggerDraft` para corresponder
4. Criar tela de edição em `Views/Memories/Editor/Triggers/Sheets/Screens/`
5. Atualizar `NotificationScheduler` ou criar novo Manager se necessário
6. Documentar comportamento em `docs/memory-triggers.md`

### Validações Obrigatórias

- Título de memória não pode ser vazio
- Máscara de dias não pode ser vazia no modo Weekdays
- Espaço não pode ser parent de si mesmo
- Trigger sequencial não pode apontar para a própria memória
- Geofence raio máximo 1000m

---

## Estado Atual do Projeto

### Funcionalidades Implementadas

✅ CRUD completo de memórias
✅ Múltiplos tipos de conteúdo (texto, checklist, fotos, links, áudio, arquivos)
✅ Triggers de data/hora com recorrência e máscaras de dias
✅ Triggers de localização com geofences
✅ Triggers de pessoa (apenas metadado, sem automação)
✅ Triggers sequenciais (apenas informativo, sem replanejamento automático)
✅ Espaços hierárquicos
✅ Timeline com seções temporais
✅ Filtros por tipo de trigger e conteúdo
✅ Busca textual
✅ Notificações locais
✅ Geofences funcionais
✅ Bulk actions (multi-select)
✅ Onboarding

### Funcionalidades Planejadas (não implementadas)

❌ Automação de triggers sequenciais (replanejamento automático)
❌ Automação de triggers de pessoa (integração com CallKit/Contacts)
❌ Tags integradas ao modelo de memórias
❌ Agenda visual (modo calendário)
❌ Sincronização iCloud (CloudKit está habilitado mas não usado ativamente)

---

## Exemplos de Uso Comum

### Buscar todas as memórias ativas de um espaço

```swift
let memories = memoryService.memories(
    in: space,
    includeDescendants: true,
    statuses: [.active],
    includeCompleted: false,
    sort: .updatedAtDescending
)
```

### Calcular próximo disparo de uma memória

```swift
if let nextDate = memory.nextFireDate(referenceDate: Date()) {
    print("Próximo lembrete: \(nextDate)")
}
```

### Criar memória com trigger de data

```swift
let trigger = MemoryTriggerModel(
    id: UUID(),
    type: .scheduled,
    fireDate: someDate,
    recurrenceRule: RecurrenceRule(frequency: .weekly, interval: 1),
    weekdayMask: 0,
    isActive: true
)
let draft = MemoryDraft(
    id: UUID(),
    title: "Reunião semanal",
    triggers: [trigger]
)
let memory = try await memoryService.createMemory(from: draft)
```

### Verificar se memória está na inbox

```swift
if memory.isInbox {
    // Memória sem trigger nem espaço, status active
}
```

---

## Glossário Rápido

- **Memory**: Unidade central do app (lembrete, tarefa, ideia)
- **Space**: Pasta/categoria hierárquica para organizar memórias
- **Trigger**: Gatilho que dispara notificação/ação automática
- **Content Block**: Bloco individual de conteúdo (texto, checklist, foto, etc.)
- **Attachment**: Anexo (foto, link, áudio, arquivo) armazenado em disco
- **Timeline**: Visualização principal agrupada por seções temporais
- **Inbox**: Memórias ativas sem trigger nem espaço atribuído
- **Draft**: Versão editável de um modelo (usado durante edição)
- **Model**: Versão persistida e imutável de uma entidade
- **Refresh**: Recarregar dados do Core Data e reconfigurar notificações/geofences

---

**Última atualização**: Baseado na análise completa do código em dezembro de 2024






