import Foundation

struct MindDTO: Codable {
    var id: String
    var name: String
    var colorHex: String?
    var iconName: String?
    var sortOrder: Int
    var isDefault: Bool
    var parentId: String?
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, colorHex, iconName, sortOrder, isDefault, parentId, updatedAt
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(colorHex, forKey: .colorHex)
        try container.encode(iconName, forKey: .iconName)
        try container.encode(sortOrder, forKey: .sortOrder)
        try container.encode(isDefault, forKey: .isDefault)
        try container.encode(parentId, forKey: .parentId)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}

struct ChecklistItemDTO: Codable {
    var id: String
    var title: String
    var detail: String
    var isCompleted: Bool
    var sortOrder: Int
}

struct RecurrenceDTO: Codable {
    var frequency: String
    var interval: Int
    var weekdays: [String]
    var endDate: Date?
    var occurrenceCount: Int?

    enum CodingKeys: String, CodingKey {
        case frequency, interval, weekdays, endDate, occurrenceCount
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(frequency, forKey: .frequency)
        try container.encode(interval, forKey: .interval)
        if frequency == "weekly" {
            try container.encode(weekdays, forKey: .weekdays)
        }
        try container.encode(endDate, forKey: .endDate)
        try container.encode(occurrenceCount, forKey: .occurrenceCount)
    }
}

extension RecurrenceDTO {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        frequency = try container.decode(String.self, forKey: .frequency)
        interval = try container.decode(Int.self, forKey: .interval)
        weekdays = try container.decodeIfPresent([String].self, forKey: .weekdays) ?? []
        endDate = try container.decodeIfPresent(Date.self, forKey: .endDate)
        occurrenceCount = try container.decodeIfPresent(Int.self, forKey: .occurrenceCount)
    }
}

struct FocusDTO: Codable {
    var enabled: Bool
    var workMinutes: Int
    var shortBreakMinutes: Int
    var longBreakMinutes: Int
    var pomodorosUntilLongBreak: Int
    var autoContinue: Bool
}

struct ScheduleDTO: Codable {
    var fireDate: Date
    var isAllDay: Bool
    var timeZone: String
    var isActive: Bool
    var recurrence: RecurrenceDTO?
    var focus: FocusDTO?

    enum CodingKeys: String, CodingKey {
        case fireDate, isAllDay, timeZone, isActive, recurrence, focus
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(fireDate, forKey: .fireDate)
        try container.encode(isAllDay, forKey: .isAllDay)
        try container.encode(timeZone, forKey: .timeZone)
        try container.encode(isActive, forKey: .isActive)
        try container.encode(recurrence, forKey: .recurrence)
        try container.encode(focus, forKey: .focus)
    }
}

struct LocationDTO: Codable {
    var name: String
    var latitude: Double
    var longitude: Double
    var radiusMeters: Double
    var event: String
    var isActive: Bool
}

struct LinkDTO: Codable {
    var url: String
    var title: String?

    enum CodingKeys: String, CodingKey {
        case url, title
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(url, forKey: .url)
        try container.encode(title, forKey: .title)
    }
}

struct MemoryDTO: Codable {
    var id: String
    var title: String
    var note: String?
    var status: String
    var isPinned: Bool
    var priority: Int?
    var dueDate: Date?
    var mindId: String?
    var completedAt: Date?
    var completedDates: [Date]
    var autoCompleteOnChecklistCompletion: Bool
    var checklist: [ChecklistItemDTO]
    var schedule: ScheduleDTO?
    var location: LocationDTO?
    var links: [LinkDTO]
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, title, note, status, isPinned, priority, dueDate, mindId, completedAt, completedDates, autoCompleteOnChecklistCompletion, checklist, schedule, location, links, createdAt, updatedAt
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(note, forKey: .note)
        try container.encode(status, forKey: .status)
        try container.encode(isPinned, forKey: .isPinned)
        try container.encode(priority, forKey: .priority)
        try container.encode(dueDate, forKey: .dueDate)
        try container.encode(mindId, forKey: .mindId)
        try container.encode(completedAt, forKey: .completedAt)
        try container.encode(completedDates, forKey: .completedDates)
        try container.encode(autoCompleteOnChecklistCompletion, forKey: .autoCompleteOnChecklistCompletion)
        try container.encode(checklist, forKey: .checklist)
        try container.encode(schedule, forKey: .schedule)
        try container.encode(location, forKey: .location)
        try container.encode(links, forKey: .links)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}

struct MirrorDTO: Codable {
    var syncedAt: Date
    var minds: [MindDTO]
    var memories: [MemoryDTO]
}

struct CommandDTO: Codable {
    var id: String
    var type: String
    var targetId: String?
    var baseVersion: Date?
    var payload: RemoteJSONValue
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, type, targetId, baseVersion, payload, createdAt
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(targetId, forKey: .targetId)
        try container.encode(baseVersion, forKey: .baseVersion)
        try container.encode(payload, forKey: .payload)
        try container.encode(createdAt, forKey: .createdAt)
    }
}

struct CommandResultDTO: Codable {
    var status: String
    var result: RemoteJSONValue
    var error: String?

    enum CodingKeys: String, CodingKey {
        case status, result, error
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(status, forKey: .status)
        try container.encode(result, forKey: .result)
        try container.encodeIfPresent(error, forKey: .error)
    }
}

enum RemoteJSONValue: Codable {
    case null, bool(Bool), number(Double), string(String), array([RemoteJSONValue]), object([String: RemoteJSONValue])

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(Double.self) { self = .number(v) }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode([RemoteJSONValue].self) { self = .array(v) }
        else { self = .object(try c.decode([String: RemoteJSONValue].self)) }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let v): try c.encode(v)
        case .number(let v): try c.encode(v)
        case .string(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .object(let v): try c.encode(v)
        }
    }

    static func from<T: Encodable>(_ value: T) throws -> Self {
        try RemoteJSON.decoder().decode(Self.self, from: RemoteJSON.encoder().encode(value))
    }
}

enum RemoteJSON {
    nonisolated static func version(updatedAt: Date?, createdAt: Date? = nil) -> Date {
        let date = updatedAt ?? createdAt ?? Date(timeIntervalSince1970: 0)
        return Date(timeIntervalSince1970: floor(date.timeIntervalSince1970 * 1000) / 1000)
    }

    nonisolated static func formatter() -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        f.isLenient = false
        return f
    }

    nonisolated static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var c = encoder.singleValueContainer()
            try c.encode(formatter().string(from: version(updatedAt: date)))
        }
        return encoder
    }

    nonisolated static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let c = try decoder.singleValueContainer()
            let value = try c.decode(String.self)
            guard let date = formatter().date(from: value), formatter().string(from: date) == value else {
                throw DecodingError.dataCorruptedError(in: c, debugDescription: "Invalid UTC millisecond date")
            }
            return date
        }
        return decoder
    }
}
