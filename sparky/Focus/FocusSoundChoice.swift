import Foundation

enum FocusSoundChoice: String, CaseIterable, Hashable, Identifiable {
    case glass
    case bell
    case chime
    case ping
    case pop

    var id: String { rawValue }

    var title: String {
        rawValue.capitalized
    }
}
