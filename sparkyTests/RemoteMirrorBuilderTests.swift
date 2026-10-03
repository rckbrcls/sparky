import Foundation
import Testing
@testable import sparky

@MainActor
struct RemoteMirrorBuilderTests {
    @Test(arguments: ["minutely", "hourly", "daily", "weekly", "monthly", "yearly"])
    func allFrequenciesRoundTripWithFocusAndTimeZone(frequency: String) async throws {
        let f = try RemoteTestFixture(); defer { f.cleanup() }
        var memory = try await f.createMemory(["schedule": try f.schedule(frequency, count: 8)])
        #expect(memory.schedule?.recurrence?.frequency == frequency)
        #expect(memory.schedule?.recurrence?.interval == 2)
        #expect(memory.schedule?.recurrence?.occurrenceCount == 8)
        #expect(memory.schedule?.recurrence?.weekdays == (frequency == "weekly" ? ["mon", "fri"] : []))
        #expect(memory.schedule?.timeZone == "America/Sao_Paulo")
        #expect(memory.schedule?.isActive == false)
        #expect(memory.schedule?.focus?.enabled == true)
        #expect(memory.schedule?.focus?.workMinutes == 25)
        #expect(memory.schedule?.focus?.shortBreakMinutes == 5)
        #expect(memory.schedule?.focus?.longBreakMinutes == 15)
        #expect(memory.schedule?.focus?.pomodorosUntilLongBreak == 4)
        #expect(memory.schedule?.focus?.autoContinue == false)
        let fireDate = Date(timeIntervalSince1970: 1_709_251_200)
        #expect(memory.schedule?.fireDate == fireDate)
        let endDate = fireDate.addingTimeInterval(365 * 24 * 3600)
        let allDay = ScheduleDTO(fireDate: fireDate, isAllDay: true, timeZone: "UTC", isActive: false,
            recurrence: RecurrenceDTO(frequency: frequency, interval: 1, weekdays: [], endDate: endDate, occurrenceCount: nil), focus: nil)
        memory = try await f.update(memory, ["schedule": try .from(allDay)])
        #expect(memory.schedule?.isAllDay == true)
        #expect(memory.schedule?.timeZone == "UTC")
        #expect(memory.schedule?.focus == nil)
        #expect(memory.schedule?.recurrence?.endDate == endDate)
        #expect(memory.schedule?.recurrence?.occurrenceCount == nil)
        let mirror = try await f.builder.build()
        let mirrored = try #require(mirror.memories.first { $0.id == memory.id })
        #expect(mirrored.schedule?.fireDate == fireDate)
        let json = try RemoteJSON.encoder().encode(mirror)
        let decoded = try RemoteJSON.decoder().decode(MirrorDTO.self, from: json)
        #expect(decoded.memories.first?.schedule?.fireDate == fireDate)
    }

    @Test func locationAndLinkUpdatesPreserveOmissionsAndRemoveExplicitly() async throws {
        let f = try RemoteTestFixture(); defer { f.cleanup() }
        var memory = try await f.createMemory([
            "location": try .from(LocationDTO(name: "South pole", latitude: -90, longitude: -180,
                                              radiusMeters: 1, event: "onEntry", isActive: false)),
            "links": try .from([LinkDTO(url: "https://example.com/a", title: "A"), LinkDTO(url: "https://example.com/b", title: nil)])
        ])
        #expect(memory.location?.latitude == -90 && memory.location?.longitude == -180)
        #expect(memory.links.count == 2)
        let linkIDs = await f.attachments.attachments(for: UUID(uuidString: memory.id)!).map(\.id)
        memory = try await f.update(memory, ["title": .string("Preserve attachments")])
        let preservedIDs = await f.attachments.attachments(for: UUID(uuidString: memory.id)!).map(\.id)
        #expect(Set(linkIDs) == Set(preservedIDs))
        #expect(memory.location?.name == "South pole")
        memory = try await f.update(memory, [
            "location": try .from(LocationDTO(name: "North pole", latitude: 90, longitude: 180,
                                              radiusMeters: 1000, event: "onExit", isActive: false)),
            "links": try .from([LinkDTO(url: "https://example.com/updated", title: "Updated")])
        ])
        #expect(memory.location?.latitude == 90 && memory.location?.event == "onExit")
        #expect(memory.links.count == 1 && memory.links[0].title == "Updated")
        memory = try await f.update(memory, ["location": .null, "links": .array([])])
        #expect(memory.location == nil && memory.links.isEmpty)
    }

    @Test func invalidSchedulesLocationsAndFocusAreRejected() async throws {
        let f = try RemoteTestFixture(); defer { f.cleanup() }
        let date = Date(timeIntervalSince1970: 1_709_251_200)
        var cases: [[String: RemoteJSONValue]] = []
        for recurrence in [
            RecurrenceDTO(frequency: "unknown", interval: 1, weekdays: [], endDate: nil, occurrenceCount: nil),
            RecurrenceDTO(frequency: "daily", interval: 0, weekdays: [], endDate: nil, occurrenceCount: nil),
            RecurrenceDTO(frequency: "daily", interval: -1, weekdays: [], endDate: nil, occurrenceCount: nil),
            RecurrenceDTO(frequency: "weekly", interval: 1, weekdays: ["invalid"], endDate: nil, occurrenceCount: nil),
            RecurrenceDTO(frequency: "daily", interval: 1, weekdays: [], endDate: date, occurrenceCount: 2),
            RecurrenceDTO(frequency: "daily", interval: 1, weekdays: [], endDate: nil, occurrenceCount: 0)
        ] {
            cases.append(["schedule": try .from(ScheduleDTO(fireDate: date, isAllDay: false, timeZone: "UTC", isActive: false,
                                                           recurrence: recurrence, focus: nil))])
        }
        // Construct the JSON directly: RecurrenceDTO encoding omits weekdays for non-weekly rules.
        cases.append(["schedule": .object(["fireDate": try .from(date), "isAllDay": .bool(false), "timeZone": .string("UTC"),
            "isActive": .bool(false), "recurrence": .object(["frequency": .string("daily"), "interval": .number(1),
                "weekdays": .array([.string("mon")])]), "focus": .null])])
        cases.append(["schedule": try .from(ScheduleDTO(fireDate: date, isAllDay: false, timeZone: "Invalid/Zone", isActive: false,
                                                       recurrence: nil, focus: nil))])
        for index in 0..<4 {
            let values = (0..<4).map { $0 == index ? -1 : 5 }
            cases.append(["schedule": try .from(ScheduleDTO(fireDate: date, isAllDay: false, timeZone: "UTC", isActive: false,
                recurrence: nil, focus: FocusDTO(enabled: true, workMinutes: values[0], shortBreakMinutes: values[1],
                                                longBreakMinutes: values[2], pomodorosUntilLongBreak: values[3], autoContinue: true)))])
        }
        for location in [
            LocationDTO(name: "Invalid latitude", latitude: 90.01, longitude: 0, radiusMeters: 1, event: "onEntry", isActive: false),
            LocationDTO(name: "Invalid longitude", latitude: 0, longitude: -180.01, radiusMeters: 1, event: "onEntry", isActive: false),
            LocationDTO(name: "Invalid radius", latitude: 0, longitude: 0, radiusMeters: 0, event: "onEntry", isActive: false),
            LocationDTO(name: "Invalid event", latitude: 0, longitude: 0, radiusMeters: 1, event: "invalid", isActive: false)
        ] { cases.append(["location": try .from(location)]) }
        for fields in cases {
            var payload = fields
            payload["title"] = .string("Invalid config")
            let result = await f.executor.execute(f.command("memory.create", payload: payload))
            #expect(result.status == "failed")
        }
        #expect(f.memories.memories.isEmpty)
    }

    @Test func mirrorUsesDeterministicIDsAndChecklistTieBreaking() async throws {
        let f = try RemoteTestFixture(); defer { f.cleanup() }
        _ = try await f.createMind("B")
        _ = try await f.createMind("A")
        _ = try await f.createMemory()
        let ids = ["00000000-0000-0000-0000-000000000002", "00000000-0000-0000-0000-000000000001"]
        let memory = try await f.createMemory(["checklist": .array(ids.map {
            .object(["id": .string($0), "title": .string($0), "sortOrder": .number(0)])
        })])
        let mirror = try await f.builder.build()
        #expect(mirror.minds.map(\.id) == mirror.minds.map(\.id).sorted())
        #expect(mirror.memories.map(\.id) == mirror.memories.map(\.id).sorted())
        #expect(memory.checklist.map(\.id) == ids.sorted())
    }

    @Test func UTCMillisecondDatesRejectImpossibleDatesAndRetainLeapDay() throws {
        let valid = "2024-02-29T23:59:59.123Z"
        let decoded = try RemoteJSON.decoder().decode(Date.self, from: Data("\"\(valid)\"".utf8))
        #expect(RemoteJSON.formatter().string(from: decoded) == valid)
        for invalid in ["2023-02-29T00:00:00.000Z", "2026-13-01T00:00:00.000Z", "2026-01-01T24:00:00.000Z",
                        "2026-01-01T00:00:00Z", "2026-01-01T00:00:00.000-03:00", "not-a-date"] {
            #expect(throws: (any Error).self) {
                try RemoteJSON.decoder().decode(Date.self, from: Data("\"\(invalid)\"".utf8))
            }
        }
    }
}
