import Foundation

/// "yyyy-MM-dd" 문자열로 저장되는 달력 날짜(시각·시간대 없음)
public struct CalendarDate: Codable, Hashable, Comparable, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    public init(from decoder: any Decoder) throws {
        let text = try decoder.singleValueContainer().decode(String.self)
        let parts = text.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, text.split(separator: "-").count == 3 else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "날짜는 yyyy-MM-dd 형식이어야 해요: \(text)")
            )
        }
        self.init(year: parts[0], month: parts[1], day: parts[2])
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(String(format: "%04d-%02d-%02d", year, month, day))
    }

    public func date(calendar: Calendar = .korea) -> Date? {
        calendar.date(from: DateComponents(year: year, month: month, day: day))
    }

    public static func < (lhs: CalendarDate, rhs: CalendarDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}

/// 규칙 데이터의 검증 상태. `verified` 만 공식 출처로 확인된 값이다.
public enum RuleStatus: String, Codable, Sendable {
    case verified, unverified, missing
}

/// 모든 규칙 JSON 이 공통으로 가지는 출처·기준일 정보 (화면의 "참고용·기준일·출처" 배너에 쓰인다)
public struct RuleMeta: Codable, Hashable, Sendable {
    public let id: String
    public let schemaVersion: Int
    public let status: RuleStatus
    /// 이 규칙이 적용되는 시작일(시행일)
    public let effectiveFrom: CalendarDate?
    /// 공식 출처로 마지막으로 확인한 날
    public let verifiedAt: CalendarDate?
    public let sourceName: String
    public let sourceURL: String?
    public let note: String?
}

public enum RuleFreshness: Equatable, Sendable {
    /// 검증됨, 확인한 지 `ageDays` 일
    case fresh(ageDays: Int)
    /// 검증됐지만 오래됨(기본 180일 초과) — 재확인 필요
    case stale(ageDays: Int)
    /// 아직 공식 출처로 검증되지 않은 초안 값
    case unverified
    /// 데이터 자체가 없음
    case missing
}

extension RuleMeta {
    public static let defaultMaxAgeDays = 180

    public func freshness(
        now: Date,
        maxAgeDays: Int = RuleMeta.defaultMaxAgeDays,
        calendar: Calendar = .korea
    ) -> RuleFreshness {
        switch status {
        case .missing:
            return .missing
        case .unverified:
            return .unverified
        case .verified:
            guard let verified = verifiedAt?.date(calendar: calendar) else { return .unverified }
            let age = calendar.daysBetween(verified, now)
            return age > maxAgeDays ? .stale(ageDays: age) : .fresh(ageDays: age)
        }
    }

    /// 사용자에게 "확정 값처럼" 보여도 되는지
    public func isTrustworthy(now: Date, calendar: Calendar = .korea) -> Bool {
        if case .fresh = freshness(now: now, calendar: calendar) { return true }
        return false
    }
}
