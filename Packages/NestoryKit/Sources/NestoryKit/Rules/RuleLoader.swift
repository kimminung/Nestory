import Foundation

/// 번들된 규칙 JSON(`Resources/rules/*.json`) 로더
public enum RuleLoader {
    public enum LoadError: Error, Equatable {
        case fileNotFound(String)
    }

    public static func decode<T: Decodable>(_ type: T.Type = T.self, from data: Data) throws -> T {
        try JSONDecoder().decode(type, from: data)
    }

    public static func loadBundled<T: Decodable>(_ name: String, as type: T.Type = T.self) throws -> T {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "rules") else {
            throw LoadError.fileNotFound(name)
        }
        return try decode(type, from: Data(contentsOf: url))
    }
}

/// 기준 시점으로부터의 간격. 있는 항목을 모두 더한다(년·월 → 일 순서로 적용, 음수 허용).
public struct RuleOffset: Codable, Hashable, Sendable {
    public var years: Int?
    public var months: Int?
    public var weeks: Int?
    public var days: Int?

    public init(years: Int? = nil, months: Int? = nil, weeks: Int? = nil, days: Int? = nil) {
        self.years = years
        self.months = months
        self.weeks = weeks
        self.days = days
    }

    public func apply(to date: Date, calendar: Calendar = .korea) -> Date {
        var components = DateComponents()
        components.year = years
        components.month = months
        components.day = (weeks ?? 0) * 7 + (days ?? 0)
        return calendar.date(byAdding: components, to: calendar.startOfDay(for: date)) ?? date
    }
}
