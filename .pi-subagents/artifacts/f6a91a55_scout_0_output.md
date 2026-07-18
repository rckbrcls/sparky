# Scout Report

## Entry points
- `sparky/sparkyApp.swift` — Root app declaration setting up the window group scene, environment objects, and lifecycles.
- `sparky/ContentView.swift` — Controls the root tab structure (Calendar, Mind, Focus, Me) and global modal sheet presentations.

## Key symbols
- `AppEnvironment` in `sparky/AppEnvironment.swift` — DI container managing models, services, and executors.
- `CustomTabBar` in `sparky/Views/Shared/CustomTabBar.swift` — Custom UIKit `UISegmentedControl`-based segmented bar.
- `CameraCaptureView` in `sparky/Views/Memories/Editor/Components/MemoryEditorCameraCaptureView.swift` — Wraps `UIImagePickerController`.
- `LocationTriggerExecutor` in `sparky/Executors/LocationTriggerExecutor.swift` — Implements `CLLocationManager` location geofencing.

## Relationships
- `sparkyApp` instantiates and injects `AppEnvironment` → `ContentView` drives navigation/active tab → view hierarchies fetch model data from the SwiftData container and call services for updates.

## Likely change surface
- `sparky.xcodeproj/project.pbxproj` — Needs target configuration and macOS SDK/deployment settings.
- `sparky/ContentView.swift` — Needs adaptation from bottom tab-bar navigation to sidebar-friendly layouts on macOS.
- `sparky/Views/Shared/CustomTabBar.swift` — Needs macOS alternative or platform-conditional UI.
- `sparky/Views/Memories/Editor/Components/MemoryEditorCameraCaptureView.swift` — Needs exclusion/alternative logic.
- `sparky/Views/Memories/Editor/Components/AudioRecorderSheet.swift` — Uses `AVAudioSession` which must be bypassed on macOS.
- `sparky/Views/Memories/Editor/Components/FilePreviewController.swift` — Uses `UIViewControllerRepresentable` for QuickLook.
- `sparky/Views/Memories/Editor/Components/LinkPreviewView.swift` — Uses UIKit version of `LPLinkView`.
- `sparky/Views/Minds/MindComposerView.swift` / `sparky/Views/Memories/Editor/QuickMemorySheet.swift` — Both use UIKit `UITextField` wrappers.
- `sparky/Managers/AppIconManager.swift` — Uses iOS alternate icon APIs.
- `sparky/Extensions/LiquidGlassModifier.swift` — Uses bottom spacer/insets tied to iOS tab bar height.

## Uncertainties
- CoreLocation circular region monitoring (`CLCircularRegion`) reliability on macOS compared to iOS.
- Whether a multi-column sidebar or simple single-window layout is preferred for macOS.

## Shareable Assets
- Core Data models (`sparky/Model/...`), draft struct conversions, persistence controller (`DataController.swift`), and business services (`MindService`, `MemoryService`).