# Sparky App Store Metadata

Ready-to-paste English metadata and release notes for App Store Connect.

---

## App Name

**Sparky**

## Subtitle

```text
Your second brain, on device.
```

---

## Description

```text
Sparky is a private memory and reminder app for iPhone.

Capture thoughts, organize ideas into hierarchical categories called Minds, and set reminders that appear at the right time or place. Sparky is built for personal organization without accounts, cloud sync, analytics, or tracking.

KEY FEATURES

• Minds - Organize memories into nested categories with custom icons and colors.
• Smart Reminders - Schedule one-time or recurring reminders with daily, weekly, monthly, yearly, weekday, or custom interval patterns.
• Location Triggers - Get notified when you arrive at or leave a selected place.
• Rich Attachments - Add photos, audio recordings, files, and links to any memory.
• Checklists - Break memories into actionable items and track completion.
• Calendar Timeline - Browse memories through day, month, and timeline views.
• Search & Filters - Find memories by text, mind, content type, status, and context.
• Import & Export - Back up and restore Sparky data with JSON exports.

PRIVACY FIRST

Sparky does not require sign-up, email, a Sparky server account, analytics, ads, or tracking. Your memories are stored locally on your device using native iOS storage.

Some optional system features, such as maps, location search, reverse geocoding, and link previews, may use Apple or destination network services when you choose to use them.

Built with SwiftUI and SwiftData for a native iOS experience.
```

---

## Keywords

```text
memory,reminder,notes,organizer,checklist,location,geofence,offline,privacy,journal
```

---

## Category

- Primary: Productivity
- Secondary: Utilities

---

## URLs

Support URL:

```text
https://sparky-app.com/support
```

Privacy Policy URL:

```text
https://sparky-app.com/privacy
```

Marketing URL:

```text
https://sparky-app.com
```

---

## Pricing

Free

---

## Age Rating Questionnaire

| Question | Answer |
| --- | --- |
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

Expected rating: 4+.

---

## App Review Notes

```text
Sparky is a personal memory and reminder app that stores user-created content locally on the device. There is no account creation, login flow, custom backend account, analytics SDK, advertising SDK, or tracking SDK.

HOW TO TEST:

1. Open the app.
   - No sign-up is required.
   - Complete the onboarding flow and grant permissions if you want to test notifications, location triggers, camera capture, or audio recording.

2. Create a Memory.
   - Tap the central create button.
   - Enter a title and optional note.
   - Save the memory.

3. Test Checklists.
   - Edit a memory.
   - Add checklist items.
   - Toggle completion.

4. Test Attachments.
   - Edit a memory.
   - Add a photo, audio recording, file, or link.
   - Link previews may use system-provided LinkPresentation behavior.

5. Test Scheduled Reminders.
   - Edit a memory and add a Schedule Trigger.
   - Set a date/time a few minutes in the future.
   - Confirm a local notification is delivered.

6. Test Location Triggers.
   - Edit a memory and add a Location Trigger.
   - Search for a location or choose a point on the map.
   - Set the radius and choose arrival or departure.
   - The app uses CLLocationManager region monitoring.
   - In Simulator, use Debug > Location to test location changes.

7. Test Import/Export.
   - Go to Me > Settings > Data Management.
   - Export data to JSON.
   - Import a previously exported Sparky JSON file.

BACKGROUND LOCATION:

Sparky requests Always location permission for user-created geofence reminders. The app uses region monitoring for selected reminder areas. It does not upload location data to a custom Sparky backend.

PERMISSIONS REQUESTED:

- Location Always / When In Use: For geofence-based reminders and location selection.
- Notifications: For scheduled and location-triggered reminders.
- Camera: To capture photos for memories.
- Microphone: To record audio notes.
- Photo Library: To attach existing images.

PRIVACY:

- No Sparky account.
- No custom Sparky backend.
- No analytics SDK.
- No advertising SDK.
- No tracking SDK.
- User-created content is stored locally through SwiftData and local attachment files.
- Map search, reverse geocoding, map display, and link previews may rely on Apple/system or destination network services when those features are used.
- Privacy Manifest is included.
```

---

## App Privacy Declarations

### Data Collection

Select: Data Not Collected.

The app does not collect data into a custom backend or analytics system. User-created content remains local to the device unless the user explicitly exports or shares it through iOS system features.

### Tracking

Does this app track users? No.

This matches `NSPrivacyTracking = false` in `sparky/PrivacyInfo.xcprivacy`.

### Privacy Nutrition Label

| Data Type | Collected | Linked to Identity | Used for Tracking |
| --- | --- | --- | --- |
| Location | No | Not applicable | No |
| Photos or Videos | No | Not applicable | No |
| Audio Data | No | Not applicable | No |
| User Content | No | Not applicable | No |
| Search History | No | Not applicable | No |
| Identifiers | No | Not applicable | No |
| Usage Data | No | Not applicable | No |
| Diagnostics | No | Not applicable | No |

Note: The app can store user content locally on the device, including locations, photos, files, audio, and notes. "Data Not Collected" here refers to App Store privacy collection by the developer.

---

## Promotional Text

```text
Capture memories, reminders, checklists, files, links, and place-based prompts privately on your iPhone.
```

---

## Release Checklist

- [ ] Apple Developer Program active.
- [ ] Bundle ID `polterware.sparky` registered in the Developer portal.
- [ ] Development team `VCF3DS6BTV` confirmed.
- [ ] Distribution certificate created.
- [ ] App Store provisioning profile created.
- [ ] App record created in App Store Connect.
- [ ] Version `1.0` and build `1` confirmed or updated.
- [ ] Screenshots captured and uploaded.
- [ ] Description, subtitle, keywords, category, and URLs filled.
- [ ] Support URL set to `https://sparky-app.com/support`.
- [ ] Privacy Policy URL set to `https://sparky-app.com/privacy`.
- [ ] Age Rating questionnaire completed.
- [ ] App Review notes filled.
- [ ] App Privacy declarations completed.
- [ ] Privacy Manifest reviewed against current framework/API usage.
- [ ] App tested on a real device.
- [ ] Scheduled notifications tested.
- [ ] Location triggers tested.
- [ ] Import/export tested.
- [ ] Archive built and validated in Xcode.
- [ ] Build uploaded to App Store Connect.
- [ ] TestFlight tested.
- [ ] Submitted for review.
