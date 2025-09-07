# Estrutura do Projeto I Can't Miss

## Estrutura Final de Pastas

```
i-cant-miss/
├── app/                    # Estrutura de rotas do Expo Router
│   ├── (tabs)/            # Navegação por abas
│   │   ├── index.tsx      # Tela principal de lembretes
│   │   ├── explore.tsx    # Tela de configurações
│   │   └── _layout.tsx    # Layout das abas
│   ├── _layout.tsx        # Layout raiz com providers
│   └── +not-found.tsx     # Página 404
├── components/            # Componentes reutilizáveis
│   ├── ReminderItem.tsx   # Item individual de lembrete
│   ├── ReminderForm.tsx   # Formulário de criação/edição
│   └── ui/               # Componentes de UI base
├── services/             # Lógica de negócio
│   ├── ReminderService.ts # Gerenciamento de lembretes
│   └── NotificationService.ts # Gerenciamento de notificações
├── database/             # Camada de dados
│   └── database.ts       # Models e acesso ao SQLite
├── context/              # Estado global
│   └── AppContext.tsx    # Contexto da aplicação
├── constants/            # Constantes do app
│   └── Colors.ts         # Tema e cores
├── hooks/                # Hooks customizados
│   ├── useColorScheme.ts
│   └── useThemeColor.ts
└── assets/               # Recursos estáticos
    ├── fonts/
    └── images/
```

## Funcionalidades Implementadas

### ✅ Banco de Dados

- SQLite com expo-sqlite
- Tabelas: reminders, snooze_history, important_dates, review_stages
- Indexes para performance
- Métodos CRUD completos

### ✅ Serviços

- **ReminderService**: Toda a lógica de negócio dos lembretes
- **NotificationService**: Gerenciamento de notificações locais

### ✅ Componentes

- **ReminderItem**: Exibe lembrete com ações (completar, soneca, etc.)
- **ReminderForm**: Formulário completo para criar/editar lembretes

### ✅ Telas

- **HomeScreen**: Lista de lembretes com filtros (Hoje, Atrasados, Próximos)
- **SettingsScreen**: Configurações, export/import, informações

### ✅ Regras de Negócio Implementadas

1. **Criação e edição de lembretes** ✅

   - Título obrigatório, campos opcionais
   - Cálculo automático do nextFireAt
   - Agendamento de notificações

2. **Status do lembrete** ✅

   - Ativo, Concluído, Atrasado, Arquivado
   - Atualização automática de status

3. **Sistema de soneca** ✅

   - Sequência: 10min → 1h → 20h hoje → 9h amanhã
   - Histórico de sonecas registrado

4. **Recorrência** ✅

   - Suporte a RRULE
   - Cálculo da próxima ocorrência

5. **Revisão espaçada** ✅

   - Intervalos: 1d → 3d → 7d → 14d → 30d → 60d → 90d
   - Penalização por ignorar

6. **Datas importantes** ✅

   - Aniversários, renovações, vencimentos
   - Lead times configuráveis

7. **Export/Import** ✅

   - JSON para backup completo
   - CSV para planilhas

8. **Confiabilidade** ✅
   - Transações atômicas
   - Sincronização notificações/dados
   - Tratamento de erros

## Dependências Instaladas

- expo-sqlite (banco de dados)
- expo-notifications (notificações)
- @react-native-community/datetimepicker (seletor de data)
- rrule (recorrências)
- date-fns (manipulação de datas)
- expo-document-picker (seleção de arquivos)
- expo-file-system (sistema de arquivos)

## Próximos Passos

1. Testar o app no device/simulator
2. Ajustar qualquer problema de UI/UX
3. Adicionar validações extras se necessário
4. Implementar testes unitários
5. Adicionar funcionalidades extras (sincronização, widgets, etc.)

O projeto está seguindo a estrutura padrão do Expo e todas as regras de negócio foram implementadas conforme especificado!
