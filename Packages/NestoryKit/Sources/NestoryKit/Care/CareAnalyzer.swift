import Foundation

/// 저장 모델과 분리된 육아 기록 한 건(계산용 순수 값)
public struct CareEntry: Hashable, Sendable {
    public let type: CareLogType
    public let start: Date
    /// 진행 중(타이머가 도는 중)이면 nil
    public let end: Date?
    public let amount: Double?
    public let unit: CareUnit?
    /// 기저귀 종류·모유 방향 등 (DiaperKind / BreastSide 의 rawValue)
    public let detail: String?

    public init(
        type: CareLogType, start: Date, end: Date? = nil,
        amount: Double? = nil, unit: CareUnit? = nil, detail: String? = nil
    ) {
        self.type = type
        self.start = start
        self.end = end
        self.amount = amount
        self.unit = unit
        self.detail = detail
    }

    public var isOngoing: Bool { end == nil }
}

/// 하루치 요약
public struct DailyCareSummary: Hashable, Sendable {
    public let day: Date
    /// 모유·분유·이유식을 합친 수유 횟수
    public var feedingCount = 0
    public var breastMinutes = 0.0
    public var formulaMilliliters = 0.0
    /// 하루 경계(자정)를 넘는 수면은 날짜별로 나눠 센다
    public var sleepMinutes = 0.0
    public var sleepSessions = 0
    public var wetDiapers = 0
    public var dirtyDiapers = 0
    public var medicationCount = 0
    public var maxTemperatureCelsius: Double?

    public var diaperCount: Int { wetDiapers + dirtyDiapers }
}

public enum CareAnalyzer {
    public static let millilitersPerOunce = 29.5735
    public static let feedingTypes: Set<CareLogType> = [.breastFeeding, .formula, .solidFood]

    /// `day`(그날 0시~24시)의 요약. 진행 중인 기록은 `now` 까지로 계산한다.
    public static func summary(
        _ entries: [CareEntry],
        on day: Date,
        now: Date,
        calendar: Calendar = .korea
    ) -> DailyCareSummary {
        let dayStart = calendar.startOfDay(for: day)
        let dayEnd = calendar.adding(days: 1, to: dayStart)
        var result = DailyCareSummary(day: dayStart)

        for entry in entries {
            let startsToday = entry.start >= dayStart && entry.start < dayEnd

            if entry.type == .sleep {
                let end = min(entry.end ?? now, now)
                let from = max(entry.start, dayStart)
                let to = min(end, dayEnd)
                if to > from { result.sleepMinutes += to.timeIntervalSince(from) / 60 }
                if startsToday { result.sleepSessions += 1 }
                continue
            }
            guard startsToday else { continue }

            if feedingTypes.contains(entry.type) { result.feedingCount += 1 }
            switch entry.type {
            case .breastFeeding:
                result.breastMinutes += minutes(of: entry, now: now)
            case .formula:
                result.formulaMilliliters += milliliters(of: entry)
            case .diaper:
                switch entry.detail.flatMap(DiaperKind.init(rawValue:)) {
                case .dirty: result.dirtyDiapers += 1
                case .both: result.wetDiapers += 1; result.dirtyDiapers += 1
                case .wet, nil: result.wetDiapers += 1
                }
            case .medication:
                result.medicationCount += 1
            case .temperature:
                if let celsius = celsius(of: entry) {
                    result.maxTemperatureCelsius = max(result.maxTemperatureCelsius ?? celsius, celsius)
                }
            case .sleep, .solidFood:
                break
            }
        }
        return result
    }

    /// `lastDay` 를 마지막 날로 하는 최근 `days` 일의 요약 (오래된 날 → 최근 날)
    public static func series(
        _ entries: [CareEntry],
        endingOn lastDay: Date,
        days: Int = 7,
        now: Date,
        calendar: Calendar = .korea
    ) -> [DailyCareSummary] {
        let lastStart = calendar.startOfDay(for: lastDay)
        return (0..<max(0, days)).reversed().map { offset in
            summary(entries, on: calendar.adding(days: -offset, to: lastStart), now: now, calendar: calendar)
        }
    }

    /// 주어진 종류 중 가장 최근에 *시작한* 기록 (미래 기록은 제외)
    public static func lastEntry(of types: Set<CareLogType>, in entries: [CareEntry], now: Date) -> CareEntry? {
        entries.filter { types.contains($0.type) && $0.start <= now }.max { $0.start < $1.start }
    }

    // MARK: - 단위 변환

    static func minutes(of entry: CareEntry, now: Date) -> Double {
        if entry.unit == .minutes, let amount = entry.amount { return amount }
        let end = entry.end ?? now
        return max(0, end.timeIntervalSince(entry.start) / 60)
    }

    static func milliliters(of entry: CareEntry) -> Double {
        guard let amount = entry.amount else { return 0 }
        return entry.unit == .ounces ? amount * millilitersPerOunce : amount
    }

    static func celsius(of entry: CareEntry) -> Double? {
        guard let amount = entry.amount else { return nil }
        return entry.unit == .fahrenheit ? (amount - 32) * 5 / 9 : amount
    }
}

/// 직전 기록 기억(분유량 등)
public enum QuickLogDefaults {
    public static let defaultFormulaMilliliters = 120.0

    /// 가장 최근 분유 기록의 양(ml). 없으면 기본값.
    public static func formulaMilliliters(from entries: [CareEntry]) -> Double {
        let last = entries.filter { $0.type == .formula && $0.amount != nil }.max { $0.start < $1.start }
        return last.map(CareAnalyzer.milliliters(of:)) ?? defaultFormulaMilliliters
    }
}

/// "2시간 5분 전" 같은 한국어 경과 시간 표기
public enum DurationFormatter {
    /// 60초 미만 "방금", 1시간 미만 "N분 전", 하루 미만 "N시간 M분 전"(분이 0이면 생략), 그 이상 "N일 전"
    public static func agoLabel(_ seconds: TimeInterval) -> String {
        let total = Int(max(0, seconds))
        switch total {
        case ..<60: return "방금"
        case 60..<3600: return "\(total / 60)분 전"
        case 3600..<86400:
            let hours = total / 3600
            let minutes = (total % 3600) / 60
            return minutes == 0 ? "\(hours)시간 전" : "\(hours)시간 \(minutes)분 전"
        default: return "\(total / 86400)일 전"
        }
    }

    /// "1시간 20분", 60분 미만 "35분"
    public static func spanLabel(minutes: Double) -> String {
        let total = Int(minutes.rounded())
        guard total >= 60 else { return "\(total)분" }
        let hours = total / 60
        let rest = total % 60
        return rest == 0 ? "\(hours)시간" : "\(hours)시간 \(rest)분"
    }
}
