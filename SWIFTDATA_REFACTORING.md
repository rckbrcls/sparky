# Refatoração SwiftData - Sparky

## Objetivo

Migrar de CoreData para SwiftData com arquitetura simplificada usando apenas `@Model` diretamente.

---

## Arquitetura Anterior (CoreData)

```
┌─────────────────────────────────────────────────────────────┐
│                      CoreData                                │
├─────────────────────────────────────────────────────────────┤
│  .xcdatamodeld (XML)                                        │
│       │                                                      │
│       ▼                                                      │
│  NSManagedObject (gerado automaticamente)                   │
│       │                                                      │
│       ▼                                                      │
│  Structs (MemoryModel, LobeModel, MindModel, TagModel)      │
│       │                                                      │
│       ▼                                                      │
│  Views                                                       │
└─────────────────────────────────────────────────────────────┘
```

**Arquivos removidos:**
- `Persistence.swift` - NSPersistentContainer
- `i_cant_miss.xcdatamodeld` - Modelo de dados XML

---

## Arquitetura Final (SwiftData Simplificado)

```
┌─────────────────────────────────────────────────────────────┐
│                      SwiftData                               │
├─────────────────────────────────────────────────────────────┤
│  @Model classes usadas diretamente                          │
│  (Mind, Space, Memory, Tag)                                 │
│       │                                                      │
│       ▼                                                      │
│  Views                                                       │
└─────────────────────────────────────────────────────────────┘
```

**Benefícios:**
- Código mais simples
- Sem conversões .toModel()
- Uma única fonte de verdade
- Padrão moderno SwiftData

---

## Mudanças Realizadas

### 1. Novos Modelos (@Model)

| Arquivo | Localização | Descrição |
|---------|-------------|-----------|
| `Mind.swift` | `Model/Mind/` | @Model class - substitui MindModel |
| `Space.swift` | `Model/Space/` | @Model class - substitui LobeModel |
| `Memory.swift` | `Model/Memory/` | @Model class - substitui MemoryModel |
| `Tag.swift` | `Model/Tag/` | @Model class - substitui TagModel |

### 2. Arquivos Removidos

| Arquivo | Motivo |
|---------|--------|
| `Persistence.swift` | Substituído por DataController |
| `i_cant_miss.xcdatamodeld/` | SwiftData não usa .xcdatamodeld |
| `MindModel.swift` | Substituído por Mind.swift |
| `LobeModel.swift` | Substituído por Space.swift |
| `MemoryModel.swift` | Substituído por Memory.swift |
| `TagModel.swift` | Substituído por Tag.swift |
| `MindEntity.swift` | Removido (camada intermediária) |
| `SpaceEntity.swift` | Removido (camada intermediária) |
| `MemoryEntity.swift` | Removido (camada intermediária) |
| `TagEntity.swift` | Removido (camada intermediária) |

### 3. DataController

`Data/DataController.swift` - Gerencia o ModelContainer do SwiftData

```swift
@MainActor
final class DataController {
    static let shared = DataController()
    static let preview: DataController  // Para SwiftUI previews

    let container: ModelContainer
    let modelContext: ModelContext

    func save()
    func performBackgroundTask(_:)
    func performBackgroundTaskAsync(_:)
}
```

### 4. Renomeações de Tipos

| Antes | Depois |
|-------|--------|
| `MindModel` | `Mind` |
| `LobeModel` | `Space` |
| `MemoryModel` | `Memory` |
| `TagModel` | `Tag` |
| `MemoryModel.Attachment` | `Memory.Attachment` |
| `MemoryModel.AttachmentKind` | `Memory.AttachmentKind` |

### 5. Renomeações de Identificadores

| Antes | Depois |
|-------|--------|
| `LobeModel.allLobesIdentifier` | `Space.allSpacesIdentifier` |
| `LobeModel.inboxLobesIdentifier` | `Space.inboxIdentifier` |
| `LobeModel.limboLobesIdentifier` | `Space.limboIdentifier` |
| `.isAllLobes` | `.isAllSpaces` |
| `.isInboxLobes` | `.isInbox` |
| `.isLimboLobes` | `.isLimbo` |

---

## Estrutura de Arquivos Final

```
i-cant-miss/
├── Data/
│   └── DataController.swift        # Container SwiftData
│
├── Model/
│   ├── Mind/
│   │   └── Mind.swift              # @Model class
│   ├── Space/
│   │   └── Space.swift             # @Model class
│   ├── Memory/
│   │   ├── Memory.swift            # @Model class
│   │   ├── MemoryDraft.swift       # Struct para criação/edição
│   │   ├── MemoryStatus.swift      # Enum
│   │   └── MemoryContentBundle.swift
│   ├── Tag/
│   │   └── Tag.swift               # @Model class
│   ├── CheckItem/
│   │   └── CheckItemModel.swift    # Struct (serializado em JSON)
│   └── Triggers/
│       └── MemoryTriggerModel.swift # Struct (serializado em JSON)
│
├── Services/
│   ├── MindService.swift           # Opera com Mind
│   ├── LobeService.swift           # Opera com Space
│   └── MemoryService.swift         # Opera com Memory
│
└── Views/
    └── ...                         # Usam @Model diretamente
```

---

## Relacionamentos SwiftData

```swift
@Model class Mind {
    @Relationship(deleteRule: .nullify, inverse: \Space.mind)
    var spaces: [Space]?
}

@Model class Space {
    var mind: Mind?

    @Relationship(deleteRule: .nullify, inverse: \Space.parent)
    var children: [Space]?
    var parent: Space?

    @Relationship(deleteRule: .nullify, inverse: \Memory.space)
    var memories: [Memory]?
}

@Model class Memory {
    var space: Space?

    // Dados transientes (populados pelo service)
    @Transient var triggers: [MemoryTriggerModel] = []
    @Transient var checkItems: [CheckItemModel] = []
    @Transient var attachments: [Attachment] = []
}

@Model class Tag {
    // Standalone, sem relacionamentos
}
```

---

## Notas Importantes

1. **Classes vs Structs**: `@Model` são reference types (classes). Mudanças em um objeto são refletidas em todas as referências.

2. **Dados Transientes**: `Memory` usa `@Transient` para propriedades que são populadas pelo service (triggers, checkItems, attachments) a partir de dados JSON.

3. **Dados Complexos**: `triggersData` e `contentsData` são armazenados como `Data` (JSON serializado) pois são estruturas aninhadas complexas.

4. **Drafts**: `MemoryDraft` continua existindo como struct para operações de criação/edição antes de persistir.

5. **Identificadores Especiais**: `Space.allSpacesIdentifier`, `Space.inboxIdentifier` etc. são propriedades estáticas para spaces virtuais.
