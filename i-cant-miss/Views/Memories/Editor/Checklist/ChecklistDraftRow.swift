import Foundation

struct ChecklistDraftRow: Identifiable, Equatable {
    let id: UUID
    var title: String
    var detail: String

    init(id: UUID = UUID(), title: String = "", detail: String = "") {
        self.id = id
        self.title = title
        self.detail = detail
    }

    var isEffectivelyEmpty: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
