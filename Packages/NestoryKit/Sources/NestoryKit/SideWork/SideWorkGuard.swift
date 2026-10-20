import Foundation

/// 휴직 중 아르바이트 사전 점검 항목 (PRD §2.5)
public enum SideWorkPreCheckItem: String, CaseIterable, Hashable, Sendable {
    /// 현 직장의 취업규칙·겸업 허용 여부
    case employerPolicy
    /// 휴직 급여 수급에 미치는 영향(고용센터 확인)
    case benefitImpact
    /// 세금·4대보험
    case taxAndInsurance
    /// 일하는 동안의 아이 돌봄 공백
    case childcareCoverage
}

public struct SideWorkShiftInput: Hashable, Sendable {
    public let date: Date
    public let hours: Double
    public let earned: Int

    public init(date: Date, hours: Double, earned: Int) {
        self.date = date
        self.hours = hours
        self.earned = earned
    }
}

/// 사용자가 정하는 경고 임계값. nil 이면 해당 검사를 하지 않는다.
public struct SideWorkGuardConfig: Hashable, Sendable {
    public var monthlyIncomeThreshold: Int?
    public var weeklyHoursThreshold: Double?

    public init(monthlyIncomeThreshold: Int? = nil, weeklyHoursThreshold: Double? = nil) {
        self.monthlyIncomeThreshold = monthlyIncomeThreshold
        self.weeklyHoursThreshold = weeklyHoursThreshold
    }
}

public enum SideWorkAdvisoryCode: Hashable, Sendable {
    case workedDuringParentalLeave
    case monthlyIncomeOverThreshold
    case weeklyHoursOverThreshold
    case preCheckIncomplete
    /// 위 경고가 하나라도 있을 때 마지막에 붙는 안내: 고용센터(1350)에 먼저 확인
    case confirmWithEmploymentCenter
}

public enum SideWorkSeverity: Int, Comparable, Sendable {
    case notice = 0
    case caution = 1

    public static func < (lhs: SideWorkSeverity, rhs: SideWorkSeverity) -> Bool { lhs.rawValue < rhs.rawValue }
}

public struct SideWorkAdvisory: Hashable, Sendable {
    public let code: SideWorkAdvisoryCode
    public let severity: SideWorkSeverity
    /// 월·주 단위 경고일 때 해당 구간의 시작일
    public let periodStart: Date?
    public let value: Double?
    public let limit: Double?
    /// preCheckIncomplete 일 때 아직 안 한 항목
    public let missingItems: [SideWorkPreCheckItem]
}

/// 휴직 중 아르바이트의 *영향 가능성*을 알려 주는 경고 생성기.
/// 수급 가능 여부를 판정하지 않는다 — 결과는 항상 "확인 필요" 수준의 안내다.
public enum SideWorkGuard {
    public static func evaluate(
        shifts: [SideWorkShiftInput],
        leavePeriods: [LeavePeriodInput],
        completedPreChecks: Set<SideWorkPreCheckItem>,
        config: SideWorkGuardConfig = SideWorkGuardConfig(),
        calendar: Calendar = .korea
    ) -> [SideWorkAdvisory] {
        var advisories: [SideWorkAdvisory] = []

        let missing = SideWorkPreCheckItem.allCases.filter { !completedPreChecks.contains($0) }
        if !missing.isEmpty {
            advisories.append(
                SideWorkAdvisory(
                    code: .preCheckIncomplete, severity: .notice,
                    periodStart: nil, value: nil, limit: nil, missingItems: missing
                )
            )
        }

        // 육아휴직(6+6 포함) 기간에 근무한 날
        let leaveRanges = leavePeriods
            .filter { $0.kind == .parental || $0.kind == .parentalSixPlusSix }
            .map { (calendar.startOfDay(for: $0.start), calendar.startOfDay(for: $0.end)) }
        let workedLeaveDays = Set(
            shifts.map { calendar.startOfDay(for: $0.date) }
                .filter { day in leaveRanges.contains { $0.0 <= day && day <= $0.1 } }
        )
        if !workedLeaveDays.isEmpty {
            advisories.append(
                SideWorkAdvisory(
                    code: .workedDuringParentalLeave, severity: .caution,
                    periodStart: workedLeaveDays.min(), value: Double(workedLeaveDays.count), limit: nil, missingItems: []
                )
            )
        }

        if let threshold = config.monthlyIncomeThreshold {
            let byMonth = Dictionary(grouping: shifts) {
                calendar.dateInterval(of: .month, for: $0.date)?.start ?? calendar.startOfDay(for: $0.date)
            }
            for (month, list) in byMonth.sorted(by: { $0.key < $1.key }) {
                let income = list.reduce(0) { $0 + $1.earned }
                if income > threshold {
                    advisories.append(
                        SideWorkAdvisory(
                            code: .monthlyIncomeOverThreshold, severity: .caution,
                            periodStart: month, value: Double(income), limit: Double(threshold), missingItems: []
                        )
                    )
                }
            }
        }

        if let threshold = config.weeklyHoursThreshold {
            let byWeek = Dictionary(grouping: shifts) {
                calendar.dateInterval(of: .weekOfYear, for: $0.date)?.start ?? calendar.startOfDay(for: $0.date)
            }
            for (week, list) in byWeek.sorted(by: { $0.key < $1.key }) {
                let hours = list.reduce(0) { $0 + $1.hours }
                if hours > threshold {
                    advisories.append(
                        SideWorkAdvisory(
                            code: .weeklyHoursOverThreshold, severity: .caution,
                            periodStart: week, value: hours, limit: threshold, missingItems: []
                        )
                    )
                }
            }
        }

        if advisories.contains(where: { $0.severity == .caution }) {
            advisories.append(
                SideWorkAdvisory(
                    code: .confirmWithEmploymentCenter, severity: .caution,
                    periodStart: nil, value: nil, limit: nil, missingItems: []
                )
            )
        }
        return advisories
    }
}
