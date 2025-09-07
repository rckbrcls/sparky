# I Can't Miss - App de Lembretes Pessoais

Um aplicativo de lembretes inteligente desenvolvido em React Native com Expo, projetado para ajudar você a nunca mais esquecer das coisas importantes.

## 🚀 Características Principais

### Tipos de Lembretes

- **Únicos**: Lembretes para data/hora específica
- **Recorrentes**: Com suporte a RRULE para repetições complexas
- **Por Pessoa/Projeto**: Lembretes organizados por contexto
- **Por Localização**: Lembretes baseados em local

### Sistema de Soneca Inteligente

- **1ª soneca**: +10 minutos
- **2ª soneca**: +1 hora
- **3ª soneca**: hoje às 20h
- **4ª+ soneca**: amanhã às 9h

### Revisão Espaçada

Para lembretes sem prazo rígido, com intervalos progressivos:

- 1 dia → 3 dias → 7 dias → 14 dias → 30 dias → 60 dias → 90 dias

### Datas Importantes

- Aniversários, renovações e vencimentos
- Notificações antecipadas configuráveis (D-7, D-1, H-2, etc.)
- Geração automática de lembretes derivados

### Gerenciamento de Status

- **Ativo**: aguardando execução
- **Concluído**: marcado como feito
- **Atrasado**: passou do prazo
- **Arquivado**: guardado para referência

## 🛠 Tecnologias Utilizadas

- **React Native** com Expo
- **TypeScript** para type safety
- **SQLite** (expo-sqlite) para persistência local
- **Expo Notifications** para notificações push
- **RRULE** para recorrências complexas
- **Date-fns** para manipulação de datas

## 📱 Funcionalidades

### Interface Principal

- Lista de lembretes filtrada por: Hoje, Atrasados, Próximos
- Badges com contadores de lembretes por categoria
- Pull-to-refresh para atualizar a lista
- Interface limpa e intuitiva

### Criação de Lembretes

- Formulário completo com todos os campos
- Seletor de data/hora
- Suporte a recorrência
- Validação de dados

### Ações nos Lembretes

- Marcar como concluído
- Soneca (adiamento inteligente)
- Lembrar depois (revisão espaçada)
- Arquivar
- Editar/excluir

### Exportação e Importação

- Export em JSON (backup completo)
- Export em CSV (para planilhas)
- Import de dados de backup
- Compartilhamento de arquivos

## 🏗 Arquitetura

### Estrutura de Pastas

```
src/
├── database/          # Modelos e acesso ao SQLite
├── services/          # Lógica de negócio
├── components/        # Componentes reutilizáveis
├── context/           # Estado global da aplicação
└── utils/            # Utilitários auxiliares
```

### Camadas da Aplicação

1. **Interface** (Components/Screens)
2. **Lógica de Negócio** (Services)
3. **Persistência** (Database)
4. **Notificações** (NotificationService)

### Padrões Implementados

- Separation of Concerns
- Repository Pattern (Database)
- Service Layer (Business Logic)
- Context API (State Management)

## 🔧 Regras de Negócio Implementadas

### 1. Criação e Edição

- Título obrigatório, demais campos opcionais
- Cálculo automático do `nextFireAt`
- Agendamento de notificações
- Cancelamento de notificações antigas ao editar

### 2. Recorrência

- Suporte a RRULE para padrões complexos
- Cálculo da próxima ocorrência automaticamente
- Continuidade da série após conclusão

### 3. Sistema de Soneca

- Sequência progressiva de adiamentos
- Histórico de sonecas registrado
- Reagendamento automático de notificações

### 4. Revisão Espaçada

- Intervalos crescentes para reforço de memória
- Penalização por ignorar lembretes
- Adaptação baseada no comportamento do usuário

### 5. Confiabilidade

- Transações atômicas no banco
- Sincronização entre dados e notificações
- Tratamento de erros robusto
- Recuperação de estado consistente

## 🚀 Como Executar

1. **Instalar dependências**:

   ```bash
   npm install
   ```

2. **Executar no iOS**:

   ```bash
   npm run ios
   ```

3. **Executar no Android**:

   ```bash
   npm run android
   ```

4. **Executar na Web**:
   ```bash
   npm run web
   ```

## 📋 Dependências Principais

```json
{
  "expo-sqlite": "^15.0.0",
  "expo-notifications": "^0.29.0",
  "@react-native-community/datetimepicker": "^8.0.0",
  "rrule": "^2.8.1",
  "date-fns": "^3.6.0",
  "expo-document-picker": "^12.0.0",
  "expo-file-system": "^17.0.0"
}
```

## 🎯 Próximas Funcionalidades

- [ ] Sincronização na nuvem
- [ ] Compartilhamento de lembretes
- [ ] Temas personalizáveis
- [ ] Widgets para tela inicial
- [ ] Integração com calendário
- [ ] Lembretes por voz
- [ ] Analytics de produtividade

## 🤝 Contribuição

Este é um projeto pessoal para aprendizado e organização. Sugestões e melhorias são bem-vindas!

## 📄 Licença

MIT License - veja o arquivo LICENSE para detalhes.
