# Catálogo de triggers com suporte nativo

Este documento detalha todos os gatilhos que podemos suportar hoje ou em um futuro próximo aproveitando APIs nativas da Apple. A ideia é concentrar, por tipo, qual rotina desejamos habilitar, quais frameworks usar e quais cuidados de implementação precisamos observar.

## 1. Gatilhos já implementados

| Trigger | Rotina típica | APIs principais | Observações |
| --- | --- | --- | --- |
| Data & hora (`scheduled`) | Lembretes pontuais ou recorrentes com hora/data fixa | `UNUserNotificationCenter`, `UNCalendarNotificationTrigger`, `UNTimeIntervalNotificationTrigger` | Já em produção. Respeita `MemoryStatus.active`, gera múltiplas notificações para máscaras de dias e segue `SettingsStore.notificationSoundEnabled`. |
| Localização (`location`) | Chegada/saída de locais específicos, check-in/out em zonas | `CoreLocation`, `CLLocationManager`, `CLCircularRegion` | Já em produção com limite de 20 geofences e raio ≤ 1000 m. Eventos disparam notificação genérica e dependem de autorização Always. |

## 2. Gatilhos informativos atuais

| Trigger | Situação atual | Próximo passo com API nativa |
| --- | --- | --- |
| Pessoa (`person`) | Apenas metadado para filtros e cards; nenhum motor automatizado | Integrar com `CallKit` + `CNContactStore` para disparar após ligações com contatos monitorados ou expor como App Intent para Shortcuts. |
| Sequencial (`sequential`) | Relacionamento informativo entre memórias sem replanejamento | Normalizar em `MemorySequenceLink` e observar `MemoryService.toggleCompletion` para agendar automaticamente a próxima memória (usando `BGProcessingTask` + `UNUserNotificationCenter`). |

## 3. Novos gatilhos com APIs disponíveis

| Trigger | Rotina alvo | APIs principais | Considerações |
| --- | --- | --- | --- |
| Recorrência relativa pós-conclusão | “Recrie o lembrete X dias após completar” | `BGTaskScheduler`, `UNTimeIntervalNotificationTrigger`, `CoreData` para histórico | Necessita persistir `completionDate` e reagendar em background mesmo fora do app. |
| Modo Foco | Entrar em Foco Pessoal/Trabalho dispara memórias relacionadas | `FocusStatusCenter`, `NotificationCenter` | iOS 15+. Precisa de permissão do usuário ao compartilhar status de foco. |
| Carro/CarPlay | Ao conectar ao carro, mostrar checklist de viagem | `CarPlay` (`CPInterfaceController` notifications), `CoreBluetooth` para periféricos específicos | CarPlay exige entitlement; alternativa é monitorar Bluetooth do veículo. |
| Headphones/Áudio | Ao plugar fones, iniciar rotina de podcast/meditação | `AVAudioSession.routeChangeNotification` | Sem autorização especial; apenas observar mudanças de rota de áudio. |
| Bateria/Carregamento | Lembrar rotinas noturnas ao conectar carregador | `UIDevice.batteryStateDidChangeNotification`, `ProcessInfo` | Habilitar `UIDevice.current.isBatteryMonitoringEnabled`. |
| Conectividade de rede | Backup automático ao entrar no Wi-Fi de casa | `Network` (`NWPathMonitor`), `CNCopyCurrentNetworkInfo` | Para SSID específico, precisa de “Access WiFi Information” entitlement. |
| Calendário/Eventos | Abrir memória ao iniciar reunião determinada | `EventKit`, `EKEventStore` | Requer permissão de calendário, sincronizar periodicamente e mapear palavras-chave/ID. |
| Contatos/Ligações | Após ligação com pessoa marcada, disparar ação | `CallKit`, `CNContactStore` | Necessário `CXCallObserver` e consentimento explícito. Ideal para evoluir o trigger de pessoa. |
| NFC / Shortcuts | Usuário toca tag NFC ou executa atalho para lembrar algo | `CoreNFC`, `AppIntents`, `Shortcuts` automations | NFC funciona apenas com app em foreground; para background, usar automações de Shortcuts acionando App Intent. |
| Saúde / Movimento | Após terminar exercício, revisar checklist | `CoreMotion` (`CMMotionActivityManager`), `HealthKit` | Precisa de permissões HealthKit segmentadas por tipo de dado. |
| Home / Automação residencial | Porta abriu, lembrar de checklist de saída | `HomeKit`, `HMEventTrigger` | Requer acesso ao HomeKit do usuário e configuração dentro do app Casa. |
| Visitas significativas | Detectar chegada/saída sem definir geofence manual | `CLLocationManager.startMonitoringVisits()` | Consome menos energia, ideal para rotinas “quando chegar ao trabalho” sem desenhar região. |

## 4. Priorização sugerida

1. **Automação dos triggers atuais**: evoluir pessoa (via CallKit) e sequencial (background + nextFireDate) para alinhar promessa da UI com comportamento real.
2. **Rotina relativa e modo Foco**: entregam valor amplo sem hardware extra e usam APIs relativamente estáveis.
3. **Contexto de dispositivo (carro, fones, bateria)**: dependem só do dispositivo e cobrem casos diários.
4. **Integrações avançadas (HomeKit, HealthKit, NFC)**: liberar depois de validar experiências básicas, pois exigem onboarding mais complexo.

## 5. Próximos passos técnicos

- Definir modelo unificado para `TriggerCapability` (tipo, requisitos, nível de suporte) para refletir esta tabela no app e na documentação interna.
- Atualizar `MemoryEditorViewModel` para suportar novos tipos gradualmente, garantindo conversão consistente entre drafts e models.
- Ajustar `MemoryService`/`NotificationScheduler`/`GeofenceManager` (ou novos managers) para cada trigger, mantendo o princípio de centralização do `refresh`.
- Documentar onboarding/autorizações por trigger (ex.: fluxo dedicado para Focus, CallKit, HealthKit) e expor na UI mensagens claras sobre o que já dispara automaticamente.

Com este catálogo, mantemos clareza sobre o que é apenas metadado e o que possui rotina real, facilitando tanto o roadmap quanto a comunicação com os usuários.
