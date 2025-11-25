# Documentação dos triggers de memória

Este documento descreve como cada tipo de trigger é modelado, editado, persistido e executado dentro do **i-cant-miss**. Ele complementa `docs/memory-status-flow.md`, explicando como os estados `active`/`completed` impactam notificações, geofences e demais efeitos colaterais ligados aos gatilhos.

---

## 1. Entidades centrais

- **Tipos suportados** – data/hora (`scheduled`), localização (`location`), pessoa (`person`) e sequência (`sequential`). Cada tipo expõe ícone para a UI e um rótulo humanizado.

```51:111:i-cant-miss/Model/MemoryDomain.swift
enum MemoryTriggerType: String, CaseIterable, Identifiable, Codable { ... }
struct MemoryTriggerModel { ... TriggerLocation ... TriggerPerson ... TriggerSequential ... }
```

- **Recorrência temporal** – `RecurrenceRule` define frequência/intervalo e opcionalmente `endDate`. A combinação `(weekdayMask, recurrenceRule)` controla disparos semanais flexíveis.

- **Draft vs Model** – no editor trabalhamos com `MemoryTriggerDraft`, convertido para `MemoryTriggerModel` apenas no `save`.

- **Cálculo do próximo disparo** – `MemoryTriggerModel.nextFireDate` trata casos simples, recorrentes e máscaras de dias, enquanto `MemoryModel.nextFireDate` agrega todos os triggers ativos de uma memória.

```183:295:i-cant-miss/Model/MemoryDomain.swift
extension MemoryTriggerModel {
    func nextFireDate(after reference: Date = Date()) -> Date? { ... }
}
```

```722:734:i-cant-miss/Model/MemoryDomain.swift
func nextFireDate(referenceDate: Date = Date()) -> Date? { ... }
```

---

## 2. Entrada e edição na UI

### 2.1 Barra de ações rápidas

- `MemoryEditorTriggerButtonsBar` expõe botões inline para cada trigger ativo e um CTA para abrir o seletor principal.

```3:74:i-cant-miss/Views/Memories/Editor/Triggers/Inline/MemoryEditorTriggerButtonsBar.swift
struct MemoryEditorTriggerButtonsBar: View { ... }
```

### 2.2 Seletor principal

- `MemoryTriggerPickerSheet` centraliza a criação/edição, usando `NavigationStack` para enviar o usuário às telas específicas.

```3:134:i-cant-miss/Views/Memories/Editor/Triggers/Sheets/MemoryTriggerPickerSheet.swift
struct MemoryTriggerPickerSheet: View { ... }
```

### 2.3 Telas específicas

- **Data & hora** – `MemoryDateAndTimeTriggerEditorScreen` valida horários, impede máscaras de dias vazias e converte seleções em `RecurrenceRule`.

```45:190:i-cant-miss/Views/Memories/Editor/Triggers/Sheets/Screens/MemoryDateAndTimeTriggerEditorScreen.swift
Form { ... DatePicker ... Picker(Type) ... MemoryWeekdaySelectionView ... }
```

- **Localização** – `LocationPickerView` oferece mapa interativo, busca (MKLocalSearch), fallback manual e define raio/evento (entrada ou saída). O callback `onAdd` retorna nome/latitude/longitude/raio/evento para o ViewModel.

```4:118:i-cant-miss/Views/Memories/Editor/Triggers/Sheets/Screens/Location/LocationPickerView.swift
struct LocationPickerView: View { ... onAdd(name, lat, lon, radius, event) ... }
```

- **Pessoa** – `MemoryPersonTriggerEditorScreen` aceita nome livre ou contato da agenda (com fluxo de permissão) e permite remover o trigger atual.

```26:158:i-cant-miss/Views/Memories/Editor/Triggers/Sheets/Screens/MemoryPersonTriggerEditorScreen.swift
Form { TextField + contato, alertas de permissão, toolbar com remoção } ...
```

- **Sequência** – `MemorySequentialTriggerEditorScreen` mostra lista filtrável de memórias, impede selecionar o mesmo item como anterior e próximo, e explica o comportamento esperado (“quando a anterior completa, agendamos a próxima para o dia seguinte”).

```27:279:i-cant-miss/Views/Memories/Editor/Triggers/Sheets/Screens/MemorySequentialTriggerEditorScreen.swift
List { infoSection + selectionSection } ...
```

---

## 3. ViewModel e persistência

- O `MemoryEditorViewModel` expõe helpers para criar/remover triggers, compondo `MemoryDraft`.

```337:433:i-cant-miss/ViewModels/MemoryEditorViewModel.swift
func setScheduledTrigger(...); func addLocationTrigger(...); func addPersonTrigger(...); func updateSequentialTrigger(...)
```

- Ao salvar, o ViewModel monta um `MemoryDraft` com `triggers.map { $0.toModel() }` e delega para `MemoryService`.

```439:521:i-cant-miss/ViewModels/MemoryEditorViewModel.swift
func save() async -> Bool { ... triggers: triggerModels ... environment.memoryService.create/update ... }
```

- `MemoryService.apply` serializa os triggers em `Memory.triggersData` (JSON) junto com os demais campos.

- Após qualquer mutação, `refresh(force: true)` recarrega todas as memórias, zera caches e dispara reconfiguração de notificações/geofences.

```123:148:i-cant-miss/Services/MemoryService.swift
func refresh(force: Bool) async -> [MemoryModel] { ... scheduler.refreshNotifications(...); geofenceManager?.sync(...) }
```

---

## 4. Camada de execução

### 4.1 Notificações locais (data/hora)

- `NotificationScheduler` garante autorização, remove pendências duplicadas e agenda `UNNotificationRequest` apenas para memórias **ativas**.
- `weekdayMask` gera múltiplas requests (uma por dia selecionado). Recorrências mensais/anuais usam `UNCalendarNotificationTrigger` repetitivo.

```42:150:i-cant-miss/Managers/NotificationScheduler.swift
func scheduleNotifications(for memory: MemoryModel) async { ... guard memory.status == .active ... switch trigger.type ... }
```

### 4.2 Geofences (localização)

- `GeofenceManager.sync` filtra memórias ativas com triggers `.location`, limita a 20 regiões (preferindo as mais recentes) e normaliza raio para máximo de 1 km.
- Eventos de entrada/saída disparam uma notificação genérica imediatamente; não há automação extra (status permanece manual).

```46:101:i-cant-miss/Managers/GeofenceManager.swift
func sync(memories: [MemoryModel]) { ... filter status == .active ... prefix(maxGeofences) ... startMonitoring ... }
```

### 4.3 Triggers por pessoa

- Ainda não existe motor automático. O trigger serve como metadado para filtros, cards e futuras integrações (ex.: detecção manual via contatos).
- A ausência de referências fora da UI (apenas `NotificationScheduler` ignora `.person`) confirma que não há disparo automatizado hoje.

### 4.4 Triggers sequenciais

- O modelo persiste os IDs anterior/próximo, exibindo-os em cards e no editor.
- Não há rotina no `MemoryService` que replaneje automaticamente o “próximo” quando a memória anterior completa. Por enquanto, é um vínculo informativo.
- Caso um fluxo automático seja adicionado futuramente, ele deve observar `MemoryService.toggleCompletion` e criar/reativar triggers no item “next”.

---

## 5. Experiência do usuário e filtros

- A timeline só exibe memórias ativas com triggers e `nextFireDate` válido.

```227:245:i-cant-miss/Services/MemoryService.swift
func timelineMemories(...) -> [MemoryModel] { ... memory.status == .active && memory.hasTriggers && memory.nextFireDate != nil ... }
```

- `MemoryTimelineView` permite filtrar por tipo de trigger; apenas memórias com triggers ativos do tipo selecionado permanecem visíveis.

```21:490:i-cant-miss/Views/Memories/MemoryTimelineView.swift
@State private var selectedTriggerTypes ... triggerMatches = memory.triggers.contains { $0.type == triggerType && $0.isActive }
```

- `MemoryCardView` mostra resumos de sequência, próxima ocorrência relativa e outros metadados, ajudando a entender quando/como cada trigger será disparado.

---

## 6. Regras de negócio e limites

1. **Status manda** – apenas memórias `active` participam de notificações e geofences. O fluxo completo está detalhado em `docs/memory-status-flow.md`.
2. **Sincronização centralizada** – qualquer alteração (salvar, editar, bulk actions) converge para `MemoryService.refresh`, garantindo que notificações/geofences sejam sempre recalculadas a partir do estado persistido.
3. **Autorização** – notificações exigem `UNUserNotificationCenter`, localização precisa exige `CLLocationManager` com `always` para geofences confiáveis. `AppEnvironment` já aciona `requestAuthorizationIfNeeded`.

```33:56:i-cant-miss/AppEnvironment.swift
memoryService.notificationScheduler = notificationScheduler
memoryService.geofenceManager = geofenceManager
geofenceManager.notificationScheduler = notificationScheduler
```

4. **Limites físicos** – monitoramos no máximo 20 geofences simultâneas e ajustamos o raio para no máximo 1000 metros, preservando bateria e obedecendo limites do iOS.
5. **Som das notificações** – respeita `SettingsStore.notificationSoundEnabled`, permitindo desligar sons sem afetar o cronograma.

```59:104:i-cant-miss/Settings/SettingsStore.swift
@Published var notificationSoundEnabled ... defaults-backed ...
```

6. **Máscara de dias** – `MemoryDateAndTimeTriggerEditorScreen` bloqueia confirmação quando nenhuma semana foi escolhida no modo “Weekdays”.
7. **Representação textual** – `WeekdayMaskSummary` converte o bitmask em legenda curta, usada tanto no editor quanto em cards.
8. **Sequência informativa** – como ainda não há automação, comunique ao usuário que os links são apenas uma visualização (não existe replanejamento automático).

---

## 7. Fluxos resumidos por tipo

### 7.1 Data & hora
1. Usuário abre o sheet, escolhe horário, data ou dias da semana.
2. ViewModel cria/atualiza `MemoryTriggerDraft` com `fireDate`, `weekdayMask` e `RecurrenceRule`.
3. Ao salvar a memória, `MemoryService` persiste os triggers e chama `NotificationScheduler.scheduleNotifications`.
4. O scheduler remove notificações antigas, cria novas e o item aparece automaticamente na timeline (section `today`, `next 7 days` etc).

### 7.2 Localização
1. Usuário seleciona lugar no mapa ou busca (com raio padrão 200 m e evento entrada/saída).
2. ViewModel converte para trigger `.location`.
3. `MemoryService.refresh` chama `GeofenceManager.sync`, que adiciona/atualiza `CLCircularRegion`.
4. Quando o sistema dispara `didEnterRegion`/`didExitRegion`, mostramos uma notificação genérica; cabe ao usuário abrir a memória para marcá-la como concluída.

### 7.3 Pessoa
1. Usuário informa nome/contato.
2. O trigger é exibido na UI (cards, filtros). Ainda não existe callback automático – precisamos de ações manuais (ex.: o usuário marca como completo após conversar com a pessoa).

### 7.4 Sequência
1. Usuário escolhe qual memória antecede e/ou qual deve ser ativada depois.
2. A UI mostra o resumo (“After X → Then Y”) mas nenhuma automação acontece nos serviços.
3. Este dado pode ser usado em reports ou para navegação manual entre memórias relacionadas.

---

## 8. Considerações e próximos passos

- **Automação futura** – para cumprir a mensagem mostrada no editor (“agendamos o próximo no dia seguinte”), será necessário observar o evento de conclusão de memórias e inserir/reativar triggers programaticamente. Hoje isso é apenas planejado.
- **Triggers por pessoa** – há espaço para integrar com Contact/Focus APIs (ex.: detectar ligações recebidas). Até lá, trate como metadado.
- **Testes** – ao adicionar novos gatilhos, verifique:
  - Salvamento/edição via ViewModel.
  - Reagendamento em `NotificationScheduler` / `GeofenceManager`.
  - Filtros na timeline.
  - Cenários de status (ativar/completar) de acordo com `docs/memory-status-flow.md`.

---

## 9. Checklist rápida (QA / revisão)

- Criar, editar e remover cada trigger via editor.
- Ativar/Completar memórias e confirmar que notificações/geofences são removidas/recriadas corretamente.
- Verificar limite de 20 geofences com memórias atualizadas recentemente.
- Ajustar configurações de som e garantir que notificações respeitam `SettingsStore`.
- Confirmar que timeline reflete filtros por tipo.
- Validar que sequential/person continuam consistentes mesmo sem automação.

Com esta visão, qualquer evolução futura (novos tipos de trigger, automações de sequência ou integrações com contatos) pode aproveitar a camada existente sem quebrar o fluxo atual.
