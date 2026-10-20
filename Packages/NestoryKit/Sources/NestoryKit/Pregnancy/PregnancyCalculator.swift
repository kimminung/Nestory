import Foundation

/// 임신 주수 표기: "20주 3일"의 (20, 3). 음수는 허용하지 않는다.
public struct GestationalAge: Hashable, Comparable, Sendable {
    public let totalDays: Int
    public var weeks: Int { totalDays / 7 }
    public var days: Int { totalDays % 7 }

    public init?(totalDays: Int) {
        guard totalDays >= 0 else { return nil }
        self.totalDays = totalDays
    }

    public init(weeks: Int, days: Int = 0) {
        self.totalDays = max(0, weeks * 7 + days)
    }

    public static func < (lhs: GestationalAge, rhs: GestationalAge) -> Bool {
        lhs.totalDays < rhs.totalDays
    }
}

public enum Trimester: Int, Sendable {
    case first = 1, second, third
}

/// 출산예정일·임신 주수 계산. 모든 기준은 "만삭 = 마지막 생리 시작일(LMP)로부터 280일".
public enum PregnancyCalculator {
    public static let fullTermDays = 280
    /// 체외수정(IVF) 이식일 기준: 이식일로부터 266일에서 배아 일령을 뺀다.
    public static let ivfDaysFromTransfer = 266

    /// 네겔레 법칙과 같은 결과: LMP + 280일
    public static func dueDate(lastMenstrualPeriod lmp: Date, calendar: Calendar = .korea) -> Date {
        calendar.adding(days: fullTermDays, to: calendar.startOfDay(for: lmp))
    }

    /// 초음파로 잰 주수를 기준으로 예정일을 보정한다.
    public static func dueDate(
        ultrasoundDate: Date,
        measuredAge: GestationalAge,
        calendar: Calendar = .korea
    ) -> Date {
        calendar.adding(
            days: fullTermDays - measuredAge.totalDays,
            to: calendar.startOfDay(for: ultrasoundDate)
        )
    }

    /// - Parameter embryoAgeDays: 이식한 배아의 일령(3일 배아 = 3, 배반포 = 5)
    public static func dueDate(
        ivfTransferDate: Date,
        embryoAgeDays: Int,
        calendar: Calendar = .korea
    ) -> Date {
        calendar.adding(
            days: ivfDaysFromTransfer - embryoAgeDays,
            to: calendar.startOfDay(for: ivfTransferDate)
        )
    }

    public static func lastMenstrualPeriod(fromDueDate due: Date, calendar: Calendar = .korea) -> Date {
        calendar.adding(days: -fullTermDays, to: calendar.startOfDay(for: due))
    }

    /// `date` 시점의 임신 주수. LMP 이전(음수)이면 nil. 42주를 넘어도 그대로 돌려준다.
    public static func gestationalAge(
        on date: Date,
        dueDate: Date,
        calendar: Calendar = .korea
    ) -> GestationalAge? {
        GestationalAge(totalDays: fullTermDays - calendar.daysBetween(date, dueDate))
    }

    /// 출산예정일까지 남은 일수. 지났으면 음수.
    public static func daysUntilDue(from date: Date, dueDate: Date, calendar: Calendar = .korea) -> Int {
        calendar.daysBetween(date, dueDate)
    }

    public static func trimester(for age: GestationalAge) -> Trimester {
        switch age.weeks {
        case ..<14: .first
        case 14..<28: .second
        default: .third
        }
    }

    /// 임신 `weeks`주 `days`일이 되는 날짜
    public static func date(
        atWeeks weeks: Int,
        days: Int = 0,
        dueDate: Date,
        calendar: Calendar = .korea
    ) -> Date {
        calendar.adding(
            days: weeks * 7 + days - fullTermDays,
            to: calendar.startOfDay(for: dueDate)
        )
    }
}
