import Foundation

/// 휴가·휴직 제도 규칙. 숫자는 `rules/leave.json` 에만 존재한다(코드에 넣지 않는다).
public struct LeaveRuleSet: Codable, Sendable {
    public struct Maternity: Codable, Hashable, Sendable {
        public let totalDaysSingle: Int
        public let minPostBirthDaysSingle: Int
        public let totalDaysMultiple: Int
        public let minPostBirthDaysMultiple: Int
        /// 휴가 중 소득 비율(통상임금 대비)
        public let paidRate: Double
        public let monthlyCap: Int?
    }

    public struct Paternity: Codable, Hashable, Sendable {
        public let days: Int
        public let withinDaysOfBirth: Int
        public let maxSplits: Int
        public let paidRate: Double
    }

    public struct Parental: Codable, Hashable, Sendable {
        public struct Benefit: Codable, Hashable, Sendable {
            public let rate: Double
            public let monthlyCap: Int
            public let monthlyFloor: Int
        }

        /// 부모 동시/순차 사용 특례(6+6)
        public struct SixPlusSix: Codable, Hashable, Sendable {
            public let childMaxAgeMonths: Int
            /// 특례가 적용되는 휴직 첫 N개월
            public let months: Int
            public let rate: Double
            /// 휴직 n번째 달(0부터)의 월 상한
            public let monthlyCapByMonth: [Int]
        }

        public let maxMonthsPerParent: Int
        public let childMaxAgeYears: Int
        public let applyDaysBefore: Int
        public let benefit: Benefit
        public let sixPlusSix: SixPlusSix
    }

    public struct ReducedHours: Codable, Hashable, Sendable {
        public let fullTimeWeeklyHours: Double
        public let minWeeklyHours: Double
        public let maxWeeklyHours: Double
        public let maxMonths: Int
        /// 줄어든 근로시간만큼의 소득에 대한 지원 비율
        public let supportRate: Double
        public let supportMonthlyCap: Int
        public let applyDaysBefore: Int
    }

    public let meta: RuleMeta
    public let maternity: Maternity
    public let paternity: Paternity
    public let parental: Parental
    public let reducedHours: ReducedHours

    public static func bundled() throws -> LeaveRuleSet {
        try RuleLoader.loadBundled("leave")
    }

    /// 한 달을 30.4375일로 본 일수 (12개월 → 365일)
    public func days(inMonths months: Int) -> Int {
        Int((Double(months) * 30.4375).rounded())
    }
}

/// 검증·시뮬레이션에 넘기는 휴가·휴직 기간 (저장 모델과 분리된 순수 값)
public struct LeavePeriodInput: Hashable, Identifiable, Sendable {
    public let id: String
    public let guardianID: String
    public let kind: LeaveKind
    public let start: Date
    /// 마지막 날(포함)
    public let end: Date
    /// 육아기 근로시간 단축일 때 주당 근로시간
    public let weeklyHours: Double?

    public init(
        id: String,
        guardianID: String,
        kind: LeaveKind,
        start: Date,
        end: Date,
        weeklyHours: Double? = nil
    ) {
        self.id = id
        self.guardianID = guardianID
        self.kind = kind
        self.start = start
        self.end = end
        self.weeklyHours = weeklyHours
    }
}

public struct LeaveChild: Hashable, Sendable {
    public let birthDate: Date?
    public let dueDate: Date?
    public let isMultiple: Bool

    public init(birthDate: Date? = nil, dueDate: Date? = nil, isMultiple: Bool = false) {
        self.birthDate = birthDate
        self.dueDate = dueDate
        self.isMultiple = isMultiple
    }

    /// 출생일, 없으면 출산예정일
    public var referenceBirth: Date? { birthDate ?? dueDate }
    public var isBirthEstimated: Bool { birthDate == nil }
}
