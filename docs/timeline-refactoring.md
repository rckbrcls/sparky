# Refatoração da Timeline e Nova Aba de Triggers

Este documento descreve a refatoração completa da visualização de timeline e a criação de uma nova aba dedicada a memórias sem triggers de data/hora.

---

## 1. Objetivo Geral

- **Remover** todas as disclosures de seções temporais (Today, Next 7 Days, Later, Recurring) da timeline atual
- **Simplificar** os filtros para apenas: Contents, Inbox e Tipos de Triggers
- **Criar** uma nova aba no `CustomTabBar` para memórias sem triggers de data/hora (`scheduled`)
- **Refatorar** a aba Timeline para exibir um calendário vertical estilo agenda (similar ao Google Calendar)

---

## 2. Remoção de Timeline Sections

### 2.1 Arquivos a Modificar

#### `i-cant-miss/Services/MemoryService.swift`
- **Remover** a struct `TimelineSection` e seu enum `Kind` (linhas ~44-76)
- **Remover** o método `timelineSections(referenceDate:)` (linhas ~247-292)
- **Manter** apenas métodos auxiliares que ainda sejam necessários (ex: `timelineMemories()` se existir)

#### `i-cant-miss/Views/Memories/MemoryTimelineView.swift`
- **Remover** `@State private var selectedSections: Set<MemoryService.TimelineSection.Kind>`
- **Remover** `@State private var collapsedSections: Set<MemoryService.TimelineSection.Kind>`
- **Remover** `private var timelineSectionData: [MemoryService.TimelineSection]`
- **Remover** `private var timelineSectionsList: some View`
- **Remover** `private func sectionExpansionBinding(for kind: MemoryService.TimelineSection.Kind) -> Binding<Bool>`
- **Remover** `private func sectionKind(for memory: MemoryModel, referenceDate: Date) -> MemoryService.TimelineSection.Kind?`
- **Simplificar** `filteredPinnedMemories` para remover lógica de `selectedSections` e `sectionKind`
- **Remover** referências a `selectedSections` em `activeFilterCount` e `filterDescription`
- **Remover** a renderização de `timelineSectionsList` do body

#### `i-cant-miss/Views/Memories/Components/FilterSheetView.swift`
- **Remover** `@Binding var selectedSections: Set<MemoryService.TimelineSection.Kind>`
- **Remover** `private var timelineSectionsSection: some View` (linhas ~117-140)
- **Remover** `private func isSectionVisuallySelected(_ kind: MemoryService.TimelineSection.Kind) -> Bool`
- **Remover** `private func toggleSection(_ kind: MemoryService.TimelineSection.Kind)`
- **Remover** a chamada de `timelineSectionsSection` no body
- **Remover** referências a `selectedSections` nos botões de reset/close

#### `i-cant-miss/Views/Memories/SpaceDetailView.swift`
- **Remover** todas as referências a `TimelineSection` e `selectedSections`
- **Simplificar** a lógica de exibição de memórias para não usar seções temporais

#### `i-cant-miss/Views/Memories/SpaceDetail/SpaceDetailTimelineContentView.swift`
- **Avaliar** se este componente ainda é necessário ou se deve ser refatorado/removido

---

## 3. Simplificação dos Filtros

### 3.1 Filtros Mantidos

Os filtros devem conter apenas:

1. **Contents** (`MemoryContentFilterType`)
   - Rich Text
   - Checklist
   - Photos
   - Links
   - Audio
   - Files

2. **Triggers** (`MemoryTriggerType`)
   - Scheduled (⏰)
   - Location (📍)
   - Person (👤)
   - Sequential (➡️)

3. **Inbox**
   - Toggle "Show Inbox"

### 3.2 Modificações em `FilterSheetView.swift`

- Manter apenas `contentsSection`, `triggersSection` e `inboxSection`
- Remover completamente `timelineSectionsSection`
- Atualizar lógica de reset para não incluir `selectedSections`

### 3.3 Modificações em `MemoryTimelineView.swift`

- Atualizar `isMemoryContentAndTriggerSelected` para não considerar `selectedSections`
- Atualizar `activeFilterCount` para contar apenas:
  - Content types selecionados (se não for todos)
  - Trigger types selecionados (se não for todos)
  - Inbox oculto (+1)
- Atualizar `filterDescription` para não incluir seções temporais

---

## 4. Nova Aba: Memórias sem Triggers de Data/Hora

### 4.1 Adicionar ao `CustomTab`

#### `i-cant-miss/ContentView.swift`

Adicionar novo caso ao enum `CustomTab`:

```swift
enum CustomTab: String, CaseIterable {
    case home = "Timeline"
    case triggers = "Triggers"  // NOVO
    case spaces = "Spaces"
    case settings = "Settings"

    var symbol: String {
        switch self {
        case .home:
            return "list.bullet.rectangle"
        case .triggers:  // NOVO
            return "bolt.fill"
        case .spaces:
            return "square.grid.2x2"
        case .settings:
            return "gearshape"
        }
    }

    // ... resto do código
}
```

### 4.2 Criar Nova View

#### `i-cant-miss/Views/Memories/MemoryTriggersView.swift` (NOVO ARQUIVO)

Esta view deve exibir:

1. **Memórias com triggers Location** (sem `scheduled`)
   - Seção "📍 Location-based"
   - Lista de memórias ativas com apenas triggers `location`
   - Mostrar nome do lugar, raio, evento (entrada/saída)

2. **Memórias com triggers Person** (sem `scheduled`)
   - Seção "👤 Person-based"
   - Lista de memórias ativas com apenas triggers `person`
   - Mostrar nome da pessoa ou contato

3. **Memórias com triggers Sequential** (sem `scheduled`)
   - Seção "➡️ Sequential"
   - Lista de memórias ativas com apenas triggers `sequential`
   - Mostrar relação anterior → próximo

4. **Memórias sem triggers** (opcional)
   - Seção "📦 No Triggers"
   - Memórias ativas sem nenhum trigger
   - CTA para adicionar trigger

**Estrutura sugerida:**

```swift
struct MemoryTriggersView: View {
    @ObservedObject var memoryService: MemoryService
    let onSelectMemory: (MemoryModel) -> Void
    let onEditMemory: ((MemoryModel) -> Void)?
    @Binding var navigationPath: NavigationPath

    @State private var searchText = ""
    @State private var selectedTriggerTypes: Set<MemoryTriggerType> = []
    @State private var showingFilterSheet = false

    // Computed properties para filtrar memórias
    private var locationOnlyMemories: [MemoryModel] { ... }
    private var personOnlyMemories: [MemoryModel] { ... }
    private var sequentialOnlyMemories: [MemoryModel] { ... }
    private var noTriggerMemories: [MemoryModel] { ... }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                // Seções com disclosures
            }
            .navigationTitle("Triggers")
            .searchable(text: $searchText)
            .toolbar { ... }
        }
    }
}
```

### 4.3 Integrar no ContentView

Adicionar novo `Tab` no `TabView`:

```swift
Tab.init(value: .triggers) {
    MemoryTriggersView(
        memoryService: environment.memoryService,
        onSelectMemory: handleMemorySelection,
        onEditMemory: handleMemoryEdit,
        navigationPath: $triggersNavigationPath  // NOVO @State
    )
    .tabBarSpacer()
}
```

Adicionar `@State private var triggersNavigationPath = NavigationPath()` e atualizar `handleTabReselection`.

---

## 5. Refatoração da Timeline para Calendário Vertical

### 5.1 Estrutura Visual

A nova `MemoryTimelineView` deve exibir um calendário vertical estilo agenda com:

1. **Header do Mês**
   - Nome do mês (ex: "December") com dropdown para seleção
   - Botão "Today" para voltar ao dia atual
   - Indicador do dia atual (ex: quadrado com "25")
   - Barra de busca

2. **Lista Vertical por Dia**
   - Divisores de semana: "DECEMBER 7 - 13", "DECEMBER 14 - 20", etc.
   - Para cada dia com memórias:
     - Cabeçalho do dia: "TUE 2" (dia da semana + número)
     - Cards de memórias com `nextFireDate` naquele dia
   - Para dias sem memórias: não mostrar nada (ou placeholder opcional)

3. **Cards de Memória**
   - Fundo colorido (baseado em prioridade/espaço)
   - Lado esquerdo: faixa de horário (ex: "19:30-20:30" ou "All day")
   - Título da memória
   - Subtítulo com resumo do trigger (ex: "Repetir: seg/qui")
   - Chips: ícone de recorrência, espaço, status
   - Tap abre memória, swipe revela ações

4. **Seção Inbox** (se `showInbox == true`)
   - Aparece no topo ou no final
   - Lista de memórias sem `nextFireDate` mas que estão no inbox

5. **Pinned Memories** (se houver)
   - Aparecem no topo, antes do calendário
   - Mesmo estilo de card, mas com indicador de pin

### 5.2 Lógica de Filtragem

A timeline deve mostrar **apenas memórias com triggers `scheduled`** que tenham `nextFireDate != nil`.

```swift
private var scheduledMemories: [MemoryModel] {
    memoryService.memories
        .filter { memory in
            guard memory.status == .active else { return false }
            guard memory.nextFireDate() != nil else { return false }

            // Deve ter pelo menos um trigger scheduled ativo
            let hasScheduled = memory.triggers.contains {
                $0.type == .scheduled && $0.isActive
            }

            guard hasScheduled else { return false }

            // Aplicar filtros de content e trigger types
            return isMemoryContentAndTriggerSelected(memory)
        }
}
```

### 5.3 Agrupamento por Data

```swift
private var memoriesByDate: [Date: [MemoryModel]] {
    Dictionary(grouping: scheduledMemories) { memory in
        Calendar.current.startOfDay(for: memory.nextFireDate() ?? Date())
    }
}

private var sortedDates: [Date] {
    memoriesByDate.keys.sorted()
}
```

### 5.4 Componentes Sugeridos

1. **`CalendarMonthHeader`** - Header com mês, botão Today, busca
2. **`CalendarWeekDivider`** - Divisor "DECEMBER 7 - 13"
3. **`CalendarDayHeader`** - "TUE 2"
4. **`CalendarMemoryCard`** - Card de memória com horário, título, chips
5. **`CalendarInboxSection`** - Seção de inbox (se aplicável)

### 5.5 Interações

- **Scroll infinito**: carregar mais semanas conforme usuário rola
- **Tap no card**: abre memória
- **Swipe no card**: ações rápidas (Completar, Editar, Mover)
- **Tap no dia sem eventos**: menu "Adicionar trigger para este dia"
- **Reselect tab**: scroll suave para o dia atual

---

## 6. Separação de Memórias: Scheduled vs Não-Scheduled

### 6.1 Regra de Negócio

- **Timeline (aba home)**: apenas memórias com `nextFireDate != nil` e pelo menos um trigger `scheduled` ativo
- **Triggers (nova aba)**: memórias ativas que:
  - Têm apenas triggers `location` (sem `scheduled`)
  - Têm apenas triggers `person` (sem `scheduled`)
  - Têm apenas triggers `sequential` (sem `scheduled`)
  - Não têm nenhum trigger

### 6.2 Helpers no MemoryService

Adicionar métodos auxiliares (se necessário):

```swift
// Memórias com scheduled triggers
func scheduledMemories() -> [MemoryModel] { ... }

// Memórias sem scheduled (para nova aba)
func nonScheduledMemories() -> [MemoryModel] { ... }

// Memórias por tipo de trigger (sem scheduled)
func memoriesWithLocationOnly() -> [MemoryModel] { ... }
func memoriesWithPersonOnly() -> [MemoryModel] { ... }
func memoriesWithSequentialOnly() -> [MemoryModel] { ... }
```

---

## 7. Checklist de Implementação

### Fase 1: Limpeza
- [ ] Remover `TimelineSection` de `MemoryService.swift`
- [ ] Remover `timelineSections()` de `MemoryService.swift`
- [ ] Remover todas as referências a `selectedSections` e `collapsedSections` de `MemoryTimelineView.swift`
- [ ] Remover `timelineSectionsSection` de `FilterSheetView.swift`
- [ ] Limpar `SpaceDetailView.swift` de referências a timeline sections
- [ ] Atualizar filtros para não incluir seções temporais

### Fase 2: Nova Aba
- [ ] Adicionar `case triggers` ao `CustomTab`
- [ ] Criar `MemoryTriggersView.swift`
- [ ] Implementar seções: Location, Person, Sequential, No Triggers
- [ ] Integrar no `ContentView` com navigation path
- [ ] Testar navegação e seleção de memórias

### Fase 3: Refatoração da Timeline
- [ ] Criar estrutura de calendário vertical
- [ ] Implementar header do mês com seleção
- [ ] Implementar agrupamento por data
- [ ] Criar componentes: `CalendarMonthHeader`, `CalendarWeekDivider`, `CalendarDayHeader`, `CalendarMemoryCard`
- [ ] Implementar scroll infinito
- [ ] Adicionar interações (tap, swipe, reselect)
- [ ] Manter funcionalidades: busca, filtros, multi-seleção, bulk actions

### Fase 4: Testes e Ajustes
- [ ] Testar com memórias scheduled
- [ ] Testar com memórias location/person/sequential
- [ ] Testar filtros em ambas as abas
- [ ] Testar navegação entre abas
- [ ] Validar performance com muitas memórias
- [ ] Ajustar UI/UX conforme feedback

---

## 8. Considerações Técnicas

### 8.1 Performance

- Usar `LazyVStack` ou `List` com `Section` para renderização eficiente
- Cachear agrupamentos por data para evitar recálculos
- Paginar semanas conforme necessário

### 8.2 Acessibilidade

- Labels descritivos para cada seção
- VoiceOver friendly
- Suporte a Dynamic Type

### 8.3 Consistência

- Manter mesmo estilo visual (glass effect, cores, tipografia)
- Reutilizar componentes existentes quando possível
- Seguir padrões de navegação já estabelecidos

---

## 9. Notas Finais

- Esta refatoração separa claramente memórias com data/hora (Timeline) de memórias acionadas por outros gatilhos (Triggers)
- A visualização de calendário vertical oferece uma experiência mais intuitiva para quem precisa ver o futuro
- Os filtros simplificados reduzem complexidade e melhoram usabilidade
- A nova aba "Triggers" dá visibilidade a memórias que antes ficavam "escondidas" na inbox

---

**Última atualização**: 2025-01-XX
**Autor**: Refatoração de Timeline e Triggers
