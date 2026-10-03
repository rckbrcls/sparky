import Foundation
import Testing
@testable import sparky

@MainActor
@Suite("Location geofence plans")
struct LocationGeofencePlannerTests {
    @Test func onlyActiveMemoriesWithAPositiveRadiusAreSelected() {
        let active = memory(name: "Office", radius: 200)
        let inactiveConfig = memory(
            updatedAt: TriggerTestSupport.date(2026, 10, 3),
            location: TriggerTestSupport.location(name: "Closed", isActive: false)
        )
        let zeroRadius = memory(
            updatedAt: TriggerTestSupport.date(2026, 10, 3, 1),
            location: TriggerTestSupport.location(radius: 0, name: "Zero")
        )
        let negativeRadius = memory(
            updatedAt: TriggerTestSupport.date(2026, 10, 3, 2),
            location: TriggerTestSupport.location(radius: -10, name: "Negative")
        )
        let completed = TriggerTestSupport.memory(
            status: .completed,
            updatedAt: TriggerTestSupport.date(2026, 10, 3, 3),
            location: TriggerTestSupport.location(name: "Done")
        )

        let regions = LocationGeofencePlanner.regions(
            for: [inactiveConfig, zeroRadius, negativeRadius, completed, active]
        )

        #expect(regions.map(\.memoryID) == [active.id])
        #expect(regions[0].latitude == 37.33)
        #expect(regions[0].longitude == -122.01)
        #expect(regions[0].radius == 200)
        #expect(regions[0].title == active.title)
        #expect(regions[0].body == active.body)
        #expect(regions[0].locationName == "Office")
    }

    @Test func newestMemoriesWinAndTheCapIsTwenty() {
        let base = TriggerTestSupport.date(2026, 10, 1)
        let active = (0..<21).map { index in
            memory(
                name: "Place \(index)",
                updatedAt: TriggerTestSupport.adding(.hour, index, to: base)
            )
        }
        let completed = TriggerTestSupport.memory(
            status: .completed,
            updatedAt: TriggerTestSupport.adding(.day, 2, to: base),
            location: TriggerTestSupport.location(name: "Finished")
        )

        let regions = LocationGeofencePlanner.regions(for: active + [completed])

        #expect(regions.count == LocationGeofencePlanner.maxGeofences)
        #expect(regions.map(\.memoryID).contains(active[0].id) == false)
        #expect(regions.map(\.memoryID).contains(completed.id) == false)
        #expect(regions.first?.memoryID == active[20].id)
        #expect(regions.last?.memoryID == active[1].id)
    }

    @Test func radiusAboveOneKilometerIsClamped() {
        let wide = memory(radius: 1_500)
        let exact = memory(radius: LocationGeofencePlanner.maxRadius)
        let regions = LocationGeofencePlanner.regions(for: [wide, exact])

        #expect(regions.first { $0.memoryID == wide.id }?.radius == 1_000)
        #expect(regions.first { $0.memoryID == exact.id }?.radius == 1_000)
    }

    @Test func entryAndExitArmOnlyTheirOwnTransition() {
        let arrival = memory(event: .onEntry)
        let departure = memory(event: .onExit)
        let regions = LocationGeofencePlanner.regions(for: [arrival, departure])
        let arrivalRegion = regions.first { $0.memoryID == arrival.id }!
        let departureRegion = regions.first { $0.memoryID == departure.id }!

        #expect(arrivalRegion.notifyOnEntry)
        #expect(arrivalRegion.notifyOnExit == false)
        #expect(departureRegion.notifyOnEntry == false)
        #expect(departureRegion.notifyOnExit)
    }

    @Test func identifierIncludesMemoryAndTriggerIDs() {
        let config = TriggerTestSupport.location()
        let stored = memory(location: config)
        let regions = LocationGeofencePlanner.regions(for: [stored])

        #expect(regions[0].identifier == "memory-\(stored.id.uuidString)-location-\(config.id.uuidString)")
        #expect(regions[0].triggerID == config.id)
    }

    @Test func reminderCopyUsesThePlaceNameAndFallsBackWhenTheNoteIsEmpty() {
        let arrival = LocationGeofencePlanner.reminderCopy(didEnter: true, locationName: "Office", body: nil)
        #expect(arrival.subtitle == "Arriving at Office")
        #expect(arrival.body == "You have a reminder for this location.")

        let departure = LocationGeofencePlanner.reminderCopy(didEnter: false, locationName: "Office", body: " ")
        #expect(departure.subtitle == "Leaving Office")
        #expect(departure.body == " ")

        let noted = LocationGeofencePlanner.reminderCopy(didEnter: true, locationName: "Office", body: "Pack the bag")
        #expect(noted.subtitle == "Arriving at Office")
        #expect(noted.body == "Pack the bag")

        let leaving = LocationGeofencePlanner.reminderCopy(didEnter: false, locationName: "Office", body: nil)
        #expect(leaving.subtitle == "Leaving Office")
        #expect(leaving.body == "You are leaving the reminder area.")
    }

    @Test func placeholderAndEmptyNamesDoNotBecomeASubtitle() {
        for name in ["Select a location", "", nil] as [String?] {
            let copy = LocationGeofencePlanner.reminderCopy(didEnter: true, locationName: name, body: nil)
            #expect(copy.subtitle == nil, "name \(name ?? "nil")")
            #expect(copy.body == nil, "name \(name ?? "nil")")
            #expect(LocationGeofencePlanner.validLocationName(name) == nil)
        }

        let noted = LocationGeofencePlanner.reminderCopy(
            didEnter: false,
            locationName: "Select a location",
            body: "Still remind me"
        )
        #expect(noted.subtitle == nil)
        #expect(noted.body == "Still remind me")
    }

    private func memory(
        name: String = "Office",
        radius: Double = 200,
        event: LocationEvent = .onEntry,
        updatedAt: Date? = nil,
        location: LocationConfig? = nil
    ) -> Memory {
        TriggerTestSupport.memory(
            updatedAt: updatedAt,
            location: location ?? TriggerTestSupport.location(radius: radius, name: name, event: event)
        )
    }
}
