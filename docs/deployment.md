# Deployment

Sparky has **two** distribution tracks:

| Track | Target | Channel |
| --- | --- | --- |
| iOS | `sparky` | App Store / TestFlight (manual Xcode) |
| macOS | `sparkyMac` → product **`Sparky.app`** | GitHub Releases + Sparkle + curl install |

Shared macOS playbook (Converge + Sparky):

```text
/Users/erickpatrickbarcelos/codes/docs/macos-desktop-distribution.md
```

---

## macOS desktop distribution (implemented)

### Overview

```text
Actions Release
  → build sparkyMac (Release, universal)
  → ad-hoc sign
  → Sparky-macos-universal-v{version}.zip
  → Sparkle EdDSA sign
  → appcast.xml
  → GitHub Release
  → GitHub Pages (appcast.xml + install)
  → optional Vercel proxy on rckbrcls.com
```

### Canonical IDs

| Item | Value |
| --- | --- |
| Local path | `/Users/erickpatrickbarcelos/codes/migration/sparky` |
| GitHub | `rckbrcls/sparky` |
| Default branch | `master` |
| Xcode project | `sparky.xcodeproj` |
| Scheme | `sparkyMac` |
| Product name | `Sparky` → **`Sparky.app`** |
| Bundle ID | `polterware.sparky.mac` |
| Sparkle | SPM product linked on `sparkyMac` |
| Updater UI | `sparkyMac/sparkyMacApp.swift` → menu **Check for Updates…** |
| Plist | `sparkyMac/Info.plist` |
| Entitlements | `sparkyMac/sparkyMac.entitlements` (no App Sandbox today) |
| Appcast (repo) | `appcast.xml` |
| Appcast script | `scripts/update_appcast.py` |
| Installer | `scripts/install.sh` |
| CI | `.github/workflows/release.yml` |
| Runner | `macos-26` |
| Secret | `SPARKLE_EDDSA_PRIVATE_KEY` |

### URLs

| Resource | URL |
| --- | --- |
| Releases | https://github.com/rckbrcls/sparky/releases |
| Appcast (Pages) | https://rckbrcls.github.io/sparky/appcast.xml |
| Appcast (proxy) | https://rckbrcls.com/api/sparky/appcast.xml |
| Install (proxy) | https://rckbrcls.com/api/sparky/install |
| `SUFeedURL` | `https://rckbrcls.com/api/sparky/appcast.xml` |

### Sparkle configuration

`sparkyMac/Info.plist`:

- `SUFeedURL`
- `SUPublicEDKey`
- `SUEnableAutomaticChecks = true`
- `SUScheduledCheckInterval = 86400`

App code:

- `SPUStandardUpdaterController(startingUpdater: true, …)`
- `updater.updateCheckInterval = 86400`
- Menu button calls `updaterController.checkForUpdates(nil)`

Public key must match the private key stored in GitHub Actions.

### Release (operator)

1. Push to `master`
2. GitHub → **Actions** → **Release** → **Run workflow**
3. Optional input `version` (e.g. `0.0.2`) overrides marketing version
4. Build number = `GITHUB_RUN_NUMBER`
5. Confirm jobs: `release`, `deploy-pages`
6. Verify release asset + appcast item (`sparkle:version`, `edSignature`, enclosure URL)

CI also:

- commits updated `appcast.xml`
- publishes Pages artifact with `appcast.xml` and `install` (copy of `scripts/install.sh`)

### Install (end user)

```bash
curl -fsSL https://rckbrcls.com/api/sparky/install | bash
open /Applications/Sparky.app
```

Specific version:

```bash
curl -fsSL https://rckbrcls.com/api/sparky/install | bash -s -- --version 0.0.2
```

Fallback:

```bash
curl -fsSL https://cdn.jsdelivr.net/gh/rckbrcls/sparky@master/scripts/install.sh | bash
```

Installer details: GitHub API → ZIP → `ditto` extract → `/Applications` or `~/Applications` → clear quarantine.

### Portfolio / Vercel proxy

Repo: `/Users/erickpatrickbarcelos/codes/portfolio`

| Piece | Role |
| --- | --- |
| `vercel.json` rewrite | `/api/sparky/appcast.xml` → Pages appcast |
| `public/api/sparky/install` | static bash installer (source of curl URL) |
| `git.deploymentEnabled.main` | `true` so push to `main` deploys |

Keep `develop` and `main` in sync when changing install/proxy files.

After portfolio changes:

```bash
# with git deploy on main, push is enough; otherwise:
cd /Users/erickpatrickbarcelos/codes/portfolio && vercel --prod
```

Validate:

```bash
curl -fsSL https://rckbrcls.com/api/sparky/appcast.xml | head
curl -fsSL https://rckbrcls.com/api/sparky/install | head
```

### Test auto-update

1. Install `N`
2. Ship `N+1` via Actions
3. Open `N` → **Sparky → Check for Updates…**
4. Accept update; confirm app becomes `N+1`

### macOS signing reality

- CI: unsigned build + **ad-hoc** resign
- No Developer ID / notarization yet
- First launch may need Finder → right-click → Open

### macOS pre-release checklist

- [ ] `PRODUCT_NAME=Sparky` / workflow `APP_BUNDLE_NAME=Sparky.app`
- [ ] `Info.plist` contains SU keys (not only `INFOPLIST_KEY_*`)
- [ ] Secret `SPARKLE_EDDSA_PRIVATE_KEY` present
- [ ] Pages enabled for the repo
- [ ] Portfolio proxy deployed
- [ ] Local Release build embeds `Sparkle.framework`
- [ ] Appcast enclosure URL hits the new ZIP
- [ ] Install one-liner works on a clean Mac

### macOS rollback

1. Fix or replace GitHub Release asset
2. Correct `appcast.xml` entry (version + signature + URL)
3. Ensure Pages serves the fixed feed
4. Clients pick up on next Sparkle check

---

## iOS App Store distribution (manual)

Still the App Store path for the `sparky` iPhone target. No App Store CI in this repo.

### Detected iOS settings

| Setting | Value |
| --- | --- |
| App target | `sparky` |
| Bundle identifier | `polterware.sparky` |
| Marketing version | `1.0` |
| Build version | `1` |
| Deployment target | iOS `26.0` |
| Development team | `VCF3DS6BTV` |
| Background mode | `location` |

Confirm in Xcode before every App Store submission.

### External Apple inputs

- Apple Developer Program membership
- App ID `polterware.sparky`
- Distribution cert + provisioning
- App Store Connect record
- Archive / upload from Xcode
- TestFlight on a real device

### Repository assets for iOS

- `AppStoreMetadata.md`
- `sparky/PrivacyInfo.xcprivacy`
- `sparky/Assets.xcassets/AppIcon/`
- `screenshots/` checklist
- `sparky.xcodeproj/project.pbxproj`

### Landing alignment

Companion site: `../sparky-landing`

Keep claims aligned across app behavior, App Store metadata, Privacy Manifest, and landing legal/marketing pages.

Do **not** claim “zero network calls”: MapKit / LinkPresentation / Sparkle (Mac) may use the network.

### iOS permissions to review

- Camera, Photo Library, Microphone
- Location When In Use / Always
- Notifications (runtime)

### iOS pre-submission checklist

- Clean install + onboarding permissions
- Memory CRUD, checklist, attachments
- Scheduled + location triggers
- Import/export
- Privacy Manifest + App Store privacy answers
- Screenshots
- Archive → validate → TestFlight

### iOS rollback

App Store Connect version management / previous builds. No automated rollback in-repo.

---

## Related docs

- [Architecture](architecture.md)
- [Security](security.md)
- [Getting Started](getting-started.md)
- Shared: `/Users/erickpatrickbarcelos/codes/docs/macos-desktop-distribution.md`
