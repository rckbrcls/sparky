enum MemoryTriggerPickerDestination: Hashable {
    case dueDate
    case exactTime
    case weekdayRoutine
    case location
    case person
    case sequential
}


extension MemoryTriggerPickerDestination: Identifiable {
    var id: Self { self }
}
