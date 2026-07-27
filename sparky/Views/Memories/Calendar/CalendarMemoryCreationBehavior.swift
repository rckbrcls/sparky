import Foundation

enum CalendarMemoryCreationBehavior {
    case action((CalendarQuickMemoryTarget) -> Void)

    #if os(macOS)
    case desktopPopover((CalendarQuickMemoryTarget) -> MemoryEditorRoute)
    #endif
}
