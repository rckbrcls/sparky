# Architecture Analysis

## Problem
Sparky precisa entregar um app Mac nativo sem duplicar domínio ou enfraquecer o iPhone. O v1 deve priorizar paridade funcional essencial, adaptando apenas navegação e capacidades de plataforma.

## Evidence
- **Fato:** `ContentView.swift` concentra tabs, quick-create, onboarding, deep links e apresentações; usa UIKit, haptics, `fullScreenCover` e safe area do iPhone.
- **Fato:** `MemoryEditorView.swift` ultrapassa 1.600 linhas e contém chamadas diretas a `UIApplication`; há bridges UIKit para câmera, QuickLook, links e campos de texto.
- **Fato:** `AppEnvironment` compartilha serviços, SwiftData, anexos e executores, mas instancia `LocationTriggerExecutor` incondicionalmente.
- **Fato:** SwiftData usa armazenamento padrão local; anexos ficam em Application Support; `sparky.entitlements` está vazio. Não existe CloudKit ou sync.
- **Fato:** o projeto possui somente `SDKROOT = iphoneos`; portanto ainda não existe validação real para macOS.
- **Inferência:** domínio e CRUD são reutilizáveis, mas compilar todos os arquivos no Mac exigirá fronteiras explícitas para shell, permissões e bridges.

## Alternatives
1. **Mac nativo com fontes compartilhadas — recomendada:** preserva domínio e oferece comportamento desktop idiomático.
2. **Mac Catalyst/“Designed for iPad”:** menor custo inicial, mas mantém chrome e dependências de iPhone; conflita com a Constituição.
3. **Fork separado para Mac:** acelera telas isoladas, porém duplica lógica e aumenta risco de divergência de dados e triggers.

## Trade-offs
- Sidebar mais apresentação adaptativa entrega experiência Mac suficiente sem redesenhar todas as features em três colunas.
- Limitar geofences, câmera e gravação de áudio reduz paridade, mas evita prometer capacidades pouco confiáveis no desktop.
- Dados estritamente locais simplificam o v1, porém impedem continuidade automática entre iPhone e Mac.
- Refatorar shell e editor simultaneamente oferece arquitetura “ideal”, mas amplia muito o risco de regressão em deep links, drafts e triggers.

## Recommendation
- **Builds:** o produto **MUST** gerar artefatos nativos distintos para iPhone e Mac a partir das mesmas fontes compartilhadas; Catalyst e reescrita paralela são proibidos.
- **Escopo Mac P1:** **MUST** funcionar Calendar/timeline, busca/filtros/conclusão, Minds e hierarquia, Me/métricas/settings, import/export e CRUD completo de Memory.
- O editor **MUST** suportar título, nota, checklist, pin/status, Mind, agenda/recorrência/focus e anexos compatíveis: imagem importada, arquivo, link e reprodução de áudio.
- Focus **MUST** suportar sessões rápidas e vinculadas a Memory, com iniciar, pausar, continuar e encerrar.
- Notificações agendadas **MUST** funcionar após consentimento, inclusive fora do primeiro plano; clicar **MUST** abrir a Memory correta.
- Focus **MUST** manter tempo correto enquanto Sparky estiver executando; continuidade após encerrar o app e handoff entre dispositivos são não objetivos.
- **Shell:** iPhone **MUST** manter tabs inferiores e comportamento atual. Mac **MUST** usar sidebar recolhível com Calendar, Mind, Focus e Me/Settings, sem tab bar ou espaçadores de iPhone.
- No Mac, editor/composer **MUST** abrir no detail ou em sheet redimensionável, nunca como telefone esticado em tela cheia.
- Ações primárias **MUST** ter caminho explícito por toolbar/teclado; long press ou haptic não podem ser o único acesso.
- **Geofence:** Mac v1 **MUST NOT** criar, ativar ou executar localização. Configurações importadas **MUST** ser preservadas e exibidas como “iPhone-only; not synced automatically”, sem descarte silencioso.
- **Câmera:** “Take Photo” **MUST** virar “Choose Image…”; captura direta no Mac é não objetivo.
- **Áudio:** reprodução existente **MUST** funcionar; gravação por microfone no Mac é não objetivo e seu controle deve ser omitido.
- **Background:** lembretes agendados usam entrega do sistema; v1 **MUST NOT** prometer daemon, menu-bar helper, geofence ou Focus após Quit.
- **Haptics:** Mac **MUST** usar feedback visual/estado; nenhum aviso de indisponibilidade é necessário.
- **Ícone alternativo:** controle **MUST** ser omitido no Mac; o ícone empacotado permanece.
- Onboarding Mac **MUST** pedir somente permissões realmente usadas e explicar armazenamento “on this Mac”.
- **Dados:** cada instalação **MUST** possuir store, anexos e preferências independentes. Mesmo Apple ID não implica compartilhamento.
- Import/export **MUST** ser descrito como cópia/backup manual, não sync ou merge contínuo; fluxos principais **MUST** funcionar offline.
- **Limite de refatoração:** v1 **SHOULD** preservar modelos, drafts, serviços e semântica de triggers; divergência deve ficar no shell e em adaptadores finos.
- **Não objetivos:** cloud sync, contas, multiwindow/document architecture, menu-bar app, cross-device Focus, Mac geofences, captura de câmera/áudio, drag-and-drop avançado e redesign integral das features.
- **Sucesso:** 100% dos fluxos P1 concluíveis sem iPhone; criação e agendamento em até 2 minutos; lembrete entregue em até 60 segundos do horário sob condições permitidas.
- **Sucesso:** criação, busca, edição, conclusão e Focus concluíveis apenas por teclado; nenhum controle indisponível pode falhar silenciosamente.
- **Sucesso:** dados e anexos persistem após Quit/relaunch e CRUD funciona offline; janela permanece utilizável entre 800×600 e tela cheia.
- **Sucesso:** a matriz equivalente de jornadas do iPhone continua passando sem mudança visível não especificada.

## Conditions that would change this
- Cloud sync exigiria primeiro emenda constitucional, modelo de conflitos e nova promessa de localização entre dispositivos.
- Geofences no Mac só deveriam entrar após validação de confiabilidade em background e demanda comprovada.
- Multiwindow exigiria revisar ownership de rotas, estado de Focus e concorrência sobre `AppEnvironment`.
- Evidência de que sheets prejudicam produtividade justificaria editor permanente em uma terceira coluna após o v1.