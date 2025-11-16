import Foundation

enum MemoryEditorContentType: CaseIterable, Identifiable {
    case richText
    case checklist
    case photos
    case links
    case audio
    case files

    var id: Self { self }

    var iconName: String {
        switch self {
        case .richText:
            return "text.justify.leading"
        case .checklist:
            return "checklist"
        case .photos:
            return "photo.on.rectangle.angled"
        case .links:
            return "link"
        case .audio:
            return "waveform"
        case .files:
            return "doc"
        }
    }

    var title: String {
        switch self {
        case .richText:
            return "Rich text"
        case .checklist:
            return "Checklist"
        case .photos:
            return "Photos"
        case .links:
            return "Links"
        case .audio:
            return "Audio"
        case .files:
            return "Files"
        }
    }

    var subtitle: String {
        switch self {
        case .richText:
            return "Capture detailed notes"
        case .checklist:
            return "Track actionable items"
        case .photos:
            return "Attach reference images"
        case .links:
            return "Reference relevant webpages"
        case .audio:
            return "Record or attach clips"
        case .files:
            return "Attach documents or files"
        }
    }
}
