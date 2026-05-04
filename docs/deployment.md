# Deployment

Sparky is a native iOS app intended for App Store distribution. The repository contains App Store metadata, privacy manifest data, app icons, screenshot planning, and Xcode project settings, but no CI/CD workflow or automated release pipeline was identified.

## Release Target

Detected project settings:

| Setting | Value |
| --- | --- |
| App target | `sparky` |
| Bundle identifier | `polterware.sparky` |
| Marketing version | `1.0` |
| Build version | `1` |
| Deployment target | iOS `26.0` |
| Development team | `VCF3DS6BTV` |
| Background mode | `location` |

Confirm these values in Xcode before every release.

## Release Inputs

App Store release requires external Apple configuration that is not fully represented in this repository:

- Active Apple Developer Program membership.
- Registered bundle identifier `polterware.sparky`.
- Distribution certificate.
- App Store provisioning profile.
- App Store Connect app record.
- Valid signing configuration in Xcode.
- Archive uploaded from Xcode or another verified release environment.
- TestFlight validation on at least one real device.

## Repository Release Assets

Relevant files:

- `AppStoreMetadata.md`: App Store name, subtitle, description, keywords, category, review notes, privacy declarations, and submission checklist.
- `sparky/PrivacyInfo.xcprivacy`: Privacy Manifest.
- `sparky/Assets.xcassets/AppIcon/`: app icon sets and previews.
- `screenshots/README.md`: screenshot capture checklist.
- `sparky.xcodeproj/project.pbxproj`: bundle ID, signing team, Info.plist generated keys, background modes, and version/build settings.

## Metadata Alignment

Sparky also has a companion landing/legal site at:

```text
../sparky-landing
```

Keep public claims aligned across:

- Native app behavior.
- `AppStoreMetadata.md`.
- `PrivacyInfo.xcprivacy`.
- `../sparky-landing` marketing, privacy, support, and terms pages.

Important privacy wording: the current app has no custom backend, account system, analytics, or tracking implementation. However, Apple/system frameworks such as MapKit and LinkPresentation may use network services for maps, location search, reverse geocoding, and link metadata. Public copy should not claim "zero network calls" unless that has been specifically validated.

## Permissions To Review

The project declares usage descriptions for:

- Camera.
- Photo Library.
- Microphone.
- Location When In Use.
- Location Always.

The app also requests notification authorization at runtime.

Review App Store privacy declarations whenever these permissions or data flows change.

## Screenshots

The current repository has a screenshot planning folder, but final App Store screenshots still need to be captured and added.

Capture real app states for:

- Calendar/timeline.
- Memory editor.
- Mind hierarchy/detail.
- Schedule trigger.
- Location trigger/map.
- Attachments.
- Data management/settings.

See `screenshots/README.md` for the detailed checklist.

## Pre-Submission Checklist

- Confirm app opens from a clean install.
- Complete onboarding and verify permission prompts.
- Create and edit a Memory.
- Add and complete checklist items.
- Add photos, audio, files, and links.
- Create and test a scheduled notification.
- Create and test a location trigger on simulator or device.
- Validate import/export with and without attachments.
- Check attachment cache clearing behavior.
- Confirm Privacy Manifest matches current API usage.
- Confirm App Store privacy declarations match current behavior.
- Confirm `../sparky-landing` public claims match the app and metadata.
- Capture final screenshots.
- Archive, validate, upload, and TestFlight test in Xcode or another verified release environment.

## Rollback

No automated rollback process exists in this repository. App Store rollback options depend on App Store Connect version management, phased release controls, and the availability of previously approved builds.

TODO: not identified in the current codebase - automated release, CI/CD, or rollback scripts.
