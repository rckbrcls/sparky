# Sparky — App Store Metadata

Ready-to-paste texts for App Store Connect submission.

---

## App Name

**Sparky**

## Subtitle (max 30 characters)

`Your second brain, on device.`

---

## Description — English (EN)

```
Sparky is your personal memory and reminder app — private, offline, and completely under your control.

Capture thoughts, organize ideas into hierarchical categories called Minds, and set smart reminders that trigger at the right time or place. All your data stays on your device. No accounts, no cloud, no tracking.

KEY FEATURES

• Minds — Organize memories into nested categories with custom icons and colors.
• Smart Reminders — Schedule one-time or recurring reminders: daily, weekly, monthly, or custom intervals.
• Location Triggers — Get notified when you arrive at or leave a specific place.
• Rich Attachments — Add photos, audio recordings, files, and links to any memory.
• Checklists — Break memories into actionable items and track progress.
• Calendar Timeline — Browse all your memories on a visual day, week, or month timeline.
• Search & Filter — Find any memory instantly by text, mind, tag, or status.

PRIVACY FIRST

Sparky requires no sign-up, no email, and no internet connection. There are zero analytics, zero third-party SDKs, and zero servers. Your memories belong to you — always.

Built with SwiftUI and SwiftData for a native iOS experience.
```

## Description — Portuguese (PT-BR)

```
Sparky é seu app pessoal de memórias e lembretes — privado, offline e completamente sob seu controle.

Capture pensamentos, organize ideias em categorias hierárquicas chamadas Minds, e defina lembretes inteligentes que disparam na hora ou no lugar certo. Todos os seus dados ficam no seu dispositivo. Sem contas, sem nuvem, sem rastreamento.

RECURSOS PRINCIPAIS

• Minds — Organize memórias em categorias aninhadas com ícones e cores personalizados.
• Lembretes Inteligentes — Agende lembretes únicos ou recorrentes: diários, semanais, mensais ou intervalos personalizados.
• Gatilhos de Localização — Seja notificado ao chegar ou sair de um local específico.
• Anexos Ricos — Adicione fotos, gravações de áudio, arquivos e links a qualquer memória.
• Checklists — Divida memórias em itens acionáveis e acompanhe o progresso.
• Linha do Tempo — Navegue por todas as suas memórias em uma timeline visual por dia, semana ou mês.
• Busca e Filtros — Encontre qualquer memória instantaneamente por texto, mind, tag ou status.

PRIVACIDADE EM PRIMEIRO LUGAR

Sparky não exige cadastro, email ou conexão com a internet. Zero analytics, zero SDKs de terceiros e zero servidores. Suas memórias são suas — sempre.

Construído com SwiftUI e SwiftData para uma experiência iOS nativa.
```

---

## Keywords (max 100 characters)

```
memory,reminder,notes,organizer,checklist,location,geofence,offline,privacy,journal
```

---

## Category

- **Primary:** Productivity
- **Secondary:** Utilities

---

## Support URL

```
https://sparky-app.com/support
```

## Privacy Policy URL

```
https://sparky-app.com/privacy
```

## Marketing URL (optional)

```
https://sparky-app.com
```

---

## Pricing

**Free**

---

## Age Rating Questionnaire

| Question | Answer |
|----------|--------|
| Cartoon or Fantasy Violence | None |
| Realistic Violence | None |
| Prolonged Graphic or Sadistic Violence | None |
| Profanity or Crude Humor | None |
| Mature/Suggestive Themes | None |
| Horror/Fear Themes | None |
| Medical/Treatment Information | None |
| Alcohol, Tobacco, or Drug Use | None |
| Simulated Gambling | None |
| Sexual Content or Nudity | None |
| Unrestricted Web Access | No |
| Gambling with Real Currency | No |

**Expected Rating:** 4+ (suitable for all ages)

---

## App Review Notes

```
Sparky is a personal memory and reminder app that stores all data locally on the device. There are no accounts, no login, and no server communication.

HOW TO TEST:

1. Open the app — no sign-up required, you'll see the main timeline view.

2. Create a Memory:
   - Tap the "+" button
   - Enter a title and optional note
   - Save the memory

3. Test Location Triggers:
   - Edit a memory and add a Location Trigger
   - Search for a location or drop a pin on the map
   - Set the radius and whether to trigger on arrival or departure
   - The app uses CLLocationManager geofences (region monitoring)
   - To test: set a geofence around your current location, then toggle location in the Simulator via Debug > Location

4. Test Scheduled Reminders:
   - Edit a memory and add a Schedule Trigger
   - Set a date/time a few minutes in the future
   - The notification should appear at the scheduled time

5. Background Location:
   - The app requests "Always" location permission for geofence monitoring
   - This is required because CLLocationManager region monitoring needs background location authorization
   - The app does NOT continuously track location — it only monitors entry/exit of user-defined geofence regions
   - Location data is never transmitted off the device

PERMISSIONS REQUESTED:
- Location (Always): For geofence-based reminders
- Camera: To capture photos for memories
- Microphone: To record audio notes
- Photo Library: To attach existing photos
- Speech Recognition: To transcribe voice input
- Notifications: For scheduled and location-triggered reminders

PRIVACY:
- Zero network calls — the app works entirely offline
- No analytics, no third-party SDKs
- Privacy Manifest included with all required API declarations
```

---

## App Privacy Declarations (App Store Connect)

### Data Collection

**Select:** "Data Not Collected"

The app does not collect any data from users. All data is stored locally on the device.

### Tracking

**Does this app track users?** No

Consistent with `NSPrivacyTracking = false` in the Privacy Manifest.

### Privacy Nutrition Label

| Data Type | Collected | Linked to Identity | Used for Tracking |
|-----------|-----------|-------------------|-------------------|
| Location | No | — | — |
| Photos or Videos | No | — | — |
| Audio Data | No | — | — |
| Health & Fitness | No | — | — |
| Contacts | No | — | — |
| User Content | No | — | — |
| Search History | No | — | — |
| Identifiers | No | — | — |
| Usage Data | No | — | — |
| Diagnostics | No | — | — |

---

## Promotional Text (can be updated without new version, max 170 characters)

```
Your thoughts, organized. Capture memories, set smart reminders, and stay on track — all privately on your device.
```

---

## Checklist Before Submission

- [ ] Apple Developer Program active (Team ID: VCF3DS6BTV)
- [ ] Bundle ID `polterware.sparky` registered in Developer portal
- [ ] Distribution Certificate created
- [ ] App Store Provisioning Profile created
- [ ] App created in App Store Connect
- [ ] Screenshots uploaded (6.7" and 6.1" required)
- [ ] Description filled (EN, optionally PT-BR)
- [ ] Keywords filled
- [ ] Category set (Productivity / Utilities)
- [ ] Support URL set to https://sparky-app.com/support
- [ ] Privacy Policy URL set to https://sparky-app.com/privacy
- [ ] Age Rating questionnaire completed
- [ ] App Review notes filled
- [ ] App Privacy declarations completed ("Data Not Collected")
- [ ] Pricing set to Free
- [ ] Archive built and validated in Xcode
- [ ] Uploaded to App Store Connect
- [ ] TestFlight tested on real device
- [ ] Submitted for review
