import Foundation

/// 일정의 기준점
public enum ScheduleAnchor: String, Codable, Sendable {
    /// 마지막 생리 시작일
    case lmp
    /// 출산예정일
    case due
    /// 출생일 (출생 전에는 출산예정일로 추정)
    case birth
}

/// 하나의 일정 규칙: 기준점에서 start~end 사이에 하면 되고, recommended 가 권장일.
public struct ScheduleRule: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let note: String?
    public let category: TaskCategory
    public let anchor: ScheduleAnchor
    public let start: RuleOffset
    public let end: RuleOffset
    public let recommended: RuleOffset?
    /// 신청·안내 공식 사이트 (없으면 nil)
    public let link: String?
}

public struct ScheduleRuleSet: Codable, Sendable {
    public let meta: RuleMeta
    public let rules: [ScheduleRule]

    /// 임신·출산 준비 일정 (검진, 바우처, 준비물, 출생 후 행정)
    public static func bundledPrenatal() throws -> ScheduleRuleSet {
        try RuleLoader.loadBundled("prenatal")
    }

    /// 영유아 건강검진 시기
    public static func bundledInfantCheckups() throws -> ScheduleRuleSet {
        try RuleLoader.loadBundled("infant-checkup")
    }
}

/// 일정 생성에 쓰는 기준 날짜들. 하나만 알아도 나머지를 유도한다.
public struct ScheduleAnchors: Sendable {
    public let lmp: Date?
    public let due: Date?
    public let birth: Date?

    public init(lmp: Date? = nil, due: Date? = nil, birth: Date? = nil, calendar: Calendar = .korea) {
        self.lmp = lmp ?? due.map { PregnancyCalculator.lastMenstrualPeriod(fromDueDate: $0, calendar: calendar) }
        self.due = due ?? lmp.map { PregnancyCalculator.dueDate(lastMenstrualPeriod: $0, calendar: calendar) }
        self.birth = birth
    }
}

public struct ScheduledItem: Identifiable, Hashable, Sendable {
    public let ruleID: String
    public let title: String
    public let note: String?
    public let category: TaskCategory
    public let windowStart: Date
    public let windowEnd: Date
    public let recommended: Date
    public let link: String?
    /// 출생일을 몰라 출산예정일로 추정한 일정인지
    public let isEstimated: Bool

    public var id: String { ruleID }
}

public enum ScheduleStatus: Equatable, Sendable {
    case upcoming, open, overdue, done
}

extension ScheduledItem {
    public func status(now: Date, isDone: Bool, calendar: Calendar = .korea) -> ScheduleStatus {
        if isDone { return .done }
        let today = calendar.startOfDay(for: now)
        if today < calendar.startOfDay(for: windowStart) { return .upcoming }
        if today > calendar.startOfDay(for: windowEnd) { return .overdue }
        return .open
    }
}

public enum ScheduleGenerator {
    /// 기준 날짜가 없는 규칙은 건너뛴다. 결과는 권장일 순.
    public static func generate(
        _ rules: [ScheduleRule],
        anchors: ScheduleAnchors,
        calendar: Calendar = .korea
    ) -> [ScheduledItem] {
        rules.compactMap { rule -> ScheduledItem? in
            let base: Date?
            var estimated = false
            switch rule.anchor {
            case .lmp: base = anchors.lmp
            case .due: base = anchors.due
            case .birth:
                base = anchors.birth ?? anchors.due
                estimated = anchors.birth == nil
            }
            guard let base else { return nil }

            let start = rule.start.apply(to: base, calendar: calendar)
            let end = rule.end.apply(to: base, calendar: calendar)
            let recommended = rule.recommended?.apply(to: base, calendar: calendar) ?? start
            return ScheduledItem(
                ruleID: rule.id,
                title: rule.title,
                note: rule.note,
                category: rule.category,
                windowStart: start,
                windowEnd: end,
                recommended: recommended,
                link: rule.link,
                isEstimated: estimated
            )
        }
        .sorted { ($0.recommended, $0.ruleID) < ($1.recommended, $1.ruleID) }
    }
}
