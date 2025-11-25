# FilterBadgesBar - Ajuste de Scroll Horizontal até as Bordas da Tela

## Problema

O componente `FilterBadgesBar` exibe uma lista horizontal de badges de filtro dentro de um `ScrollView`. O problema inicial era que os badges não conseguiam ser scrollados até as bordas laterais da tela, ficando limitados pelos paddings aplicados tanto no componente pai quanto no próprio componente.

## Contexto

O `FilterBadgesBar` é usado dentro de uma `List` no `MemoryTriggersView`, e os outros componentes da lista utilizam `listRowInsets` com padding de 20 pontos em ambos os lados (leading e trailing) para manter o alinhamento visual consistente.

## Solução Implementada

Para permitir que os badges scroll até as bordas da tela, foram feitos os seguintes ajustes:

### 1. Ajuste no Componente Pai (MemoryTriggersView)

**Arquivo**: `i-cant-miss/Views/Memories/MemoryTriggersView.swift`

O `listRowInsets` do `FilterBadgesBar` foi configurado com `leading: 0` e `trailing: 0` para remover os paddings que impediam o scroll até as bordas:

```swift
FilterBadgesBar(...)
    .listRowInsets(.init(top: 8, leading: 0, bottom: 8, trailing: 0))
```

**Importante**: Os outros componentes da lista mantêm o `listRowInsets` padrão com `leading: 20` e `trailing: 20` para preservar o alinhamento visual.

### 2. Ajuste no FilterBadgesBar

**Arquivo**: `i-cant-miss/Views/Shared/Filter/FilterBadgesBar.swift`

Foi adicionado apenas padding no leading do `HStack` interno para manter o alinhamento visual do primeiro badge com os outros componentes da lista:

```swift
ScrollView(.horizontal, showsIndicators: false) {
    HStack(alignment: .center, spacing: 10) {
        // ... badges ...
    }
    .padding(.leading, 20)
}
.scrollIndicators(.hidden)
```

**Pontos importantes**:
- Não há padding no trailing do `HStack`, permitindo que o último badge seja scrollado até a borda direita da tela
- O padding de 20 no leading alinha visualmente o primeiro badge com os outros componentes da lista
- O `ScrollView` pode expandir até as bordas da tela devido ao `listRowInsets` com valores zero

## Resultado

Com esses ajustes:
- ✅ Os badges podem ser scrollados horizontalmente até as bordas laterais da tela
- ✅ O primeiro badge mantém alinhamento visual com os outros componentes da lista (padding de 20)
- ✅ O último badge pode ser completamente visível quando scrollado até o fim
- ✅ Os outros componentes da lista mantêm seu padding padrão e alinhamento

## Estrutura Final

```
List {
    FilterBadgesBar
        └─ listRowInsets: leading: 0, trailing: 0 (permite scroll até bordas)
        └─ ScrollView
            └─ HStack
                └─ padding(.leading, 20) (alinhamento visual)
                └─ sem padding trailing (permite scroll até borda direita)

    Outros componentes
        └─ listRowInsets: leading: 20, trailing: 20 (padding padrão)
}
```

## Notas Técnicas

- O `listRowInsets` com valores zero remove as restrições de padding do container da lista
- O padding interno no `HStack` é necessário apenas no leading para manter consistência visual
- A ausência de padding no trailing permite que o conteúdo do scroll chegue até a borda direita da tela
- Esta solução mantém a experiência visual consistente enquanto permite scroll completo até as bordas
