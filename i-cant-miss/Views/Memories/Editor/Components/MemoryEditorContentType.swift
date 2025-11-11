import Foundation

enum MemoryEditorContentType: CaseIterable, Identifiable {
    case richText
    case checklist
    case photos

    var id: Self { self }

    var iconName: String {
        switch self {
        case .richText:
            return "text.justify.leading"
        case .checklist:
            return "checklist"
        case .photos:
            return "photo.on.rectangle.angled"
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
        }
    }
}
