enum MemoryTriggerPickerDestination: Hashable {
    case dateAndTime
    case location
    case person
    case sequential
}


extension MemoryTriggerPickerDestination: Identifiable {
    var id: Self { self }
}
