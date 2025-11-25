enum MemoryTriggerPickerDestination: Hashable {
    case dateAndTime
    case location
    case person
    case sequential
    case focus
}


extension MemoryTriggerPickerDestination: Identifiable {
    var id: Self { self }
}
