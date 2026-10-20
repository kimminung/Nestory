import Foundation

public enum LeaveIssueSeverity: String, Hashable, Sendable {
    case error, warning
}

public enum LeaveIssueCode: String, Hashable, Sendable {
    case endBeforeStart
    case overlapSameGuardian
    case maternityTooLong
    case maternityPostBirthTooShort
    case paternityOutsideWindow
    case paternityTooManyDays
    case paternityTooManySplits
    case parentalExceedsMax
    case parentalChildTooOld
    case sixPlusSixChildTooOld
    case sixPlusSixNeedsBothParents
    case reducedHoursMissingHours
    case reducedHoursOutOfRange
    case reducedHoursTooLong
}

/// 검증 결과. 문구는 UI 가 `code` 로 만든다. `limit` 은 위반한 기준값(일수·개월 등).
public struct LeaveIssue: Hashable, Sendable {
    public let code: LeaveIssueCode
    public let severity: LeaveIssueSeverity
    public let guardianID: String?
    public let periodIDs: [String]
    public let limit: Int?

    init(
        _ code: LeaveIssueCode,
        severity: LeaveIssueSeverity = .error,
        guardianID: String? = nil,
        periodIDs: [String] = [],
        limit: Int? = nil
    ) {
        self.code = code
        self.severity = severity
        self.guardianID = guardianID
        self.periodIDs = periodIDs
        self.limit = limit
    }
}

/// 규칙(JSON)과 사용자 입력만으로 휴직 계획을 검증하는 순수 엔진
public struct LeaveEngine: Sendable {
    public let rules: LeaveRuleSet

    public init(rules: LeaveRuleSet) {
        self.rules = rules
    }

    public func validate(
        periods: [LeavePeriodInput],
        child: LeaveChild,
        calendar: Calendar = .korea
    ) -> [LeaveIssue] {
        var issues: [LeaveIssue] = []

        // 1) 기간 자체가 올바른 것만 이후 검사 대상
        var valid: [LeavePeriodInput] = []
        for period in periods {
            if calendar.startOfDay(for: period.end) < calendar.startOfDay(for: period.start) {
                issues.append(LeaveIssue(.endBeforeStart, guardianID: period.guardianID, periodIDs: [period.id]))
            } else {
                valid.append(period)
            }
        }

        let byGuardian = Dictionary(grouping: valid, by: \.guardianID)
        for (guardianID, list) in byGuardian.sorted(by: { $0.key < $1.key }) {
            let sorted = list.sorted { ($0.start, $0.id) < ($1.start, $1.id) }
            issues += overlaps(in: sorted, guardianID: guardianID, calendar: calendar)
            issues += maternityIssues(sorted, guardianID: guardianID, child: child, calendar: calendar)
            issues += paternityIssues(sorted, guardianID: guardianID, child: child, calendar: calendar)
            issues += parentalIssues(sorted, guardianID: guardianID, child: child, calendar: calendar)
            issues += reducedHoursIssues(sorted, guardianID: guardianID, calendar: calendar)
        }
        issues += sixPlusSixCoupleIssues(valid, child: child, calendar: calendar)
        return issues
    }

    /// 사업주에게 신청해야 하는 마감일(시작일 N일 전). 신청 개념이 없는 종류는 nil.
    public func applicationDeadline(for period: LeavePeriodInput, calendar: Calendar = .korea) -> Date? {
        let daysBefore: Int
        switch period.kind {
        case .parental, .parentalSixPlusSix: daysBefore = rules.parental.applyDaysBefore
        case .reducedHours: daysBefore = rules.reducedHours.applyDaysBefore
        default: return nil
        }
        return calendar.adding(days: -daysBefore, to: calendar.startOfDay(for: period.start))
    }

    // MARK: - 종류별 검사

    private func overlaps(in sorted: [LeavePeriodInput], guardianID: String, calendar: Calendar) -> [LeaveIssue] {
        var issues: [LeaveIssue] = []
        var latest: LeavePeriodInput?
        for period in sorted {
            if let latest, calendar.startOfDay(for: period.start) <= calendar.startOfDay(for: latest.end) {
                issues.append(LeaveIssue(.overlapSameGuardian, guardianID: guardianID, periodIDs: [latest.id, period.id]))
            }
            if latest == nil || period.end > latest!.end { latest = period }
        }
        return issues
    }

    private func totalDays(_ periods: [LeavePeriodInput], calendar: Calendar) -> Int {
        periods.reduce(0) { $0 + calendar.inclusiveDays(from: $1.start, to: $1.end) }
    }

    private func maternityIssues(
        _ sorted: [LeavePeriodInput], guardianID: String, child: LeaveChild, calendar: Calendar
    ) -> [LeaveIssue] {
        let list = sorted.filter { $0.kind == .maternity }
        guard !list.isEmpty else { return [] }
        let ids = list.map(\.id)
        var issues: [LeaveIssue] = []

        let limit = child.isMultiple ? rules.maternity.totalDaysMultiple : rules.maternity.totalDaysSingle
        if totalDays(list, calendar: calendar) > limit {
            issues.append(LeaveIssue(.maternityTooLong, guardianID: guardianID, periodIDs: ids, limit: limit))
        }

        if let birth = child.referenceBirth {
            let minPost = child.isMultiple
                ? rules.maternity.minPostBirthDaysMultiple : rules.maternity.minPostBirthDaysSingle
            let birthDay = calendar.startOfDay(for: birth)
            // 출산 당일을 포함해 출산 후 확보된 휴가 일수
            let post = list.reduce(0) { sum, period in
                let from = max(calendar.startOfDay(for: period.start), birthDay)
                return sum + calendar.inclusiveDays(from: from, to: period.end)
            }
            if post < minPost {
                issues.append(
                    LeaveIssue(
                        .maternityPostBirthTooShort,
                        severity: child.isBirthEstimated ? .warning : .error,
                        guardianID: guardianID, periodIDs: ids, limit: minPost
                    )
                )
            }
        }
        return issues
    }

    private func paternityIssues(
        _ sorted: [LeavePeriodInput], guardianID: String, child: LeaveChild, calendar: Calendar
    ) -> [LeaveIssue] {
        let list = sorted.filter { $0.kind == .paternity }
        guard !list.isEmpty else { return [] }
        let ids = list.map(\.id)
        var issues: [LeaveIssue] = []

        if totalDays(list, calendar: calendar) > rules.paternity.days {
            issues.append(
                LeaveIssue(.paternityTooManyDays, guardianID: guardianID, periodIDs: ids, limit: rules.paternity.days)
            )
        }
        if list.count > rules.paternity.maxSplits {
            issues.append(
                LeaveIssue(.paternityTooManySplits, guardianID: guardianID, periodIDs: ids, limit: rules.paternity.maxSplits)
            )
        }
        if let birth = child.referenceBirth {
            let lastDay = calendar.adding(days: rules.paternity.withinDaysOfBirth, to: calendar.startOfDay(for: birth))
            let outside = list.filter { calendar.startOfDay(for: $0.end) > lastDay }
            if !outside.isEmpty {
                issues.append(
                    LeaveIssue(
                        .paternityOutsideWindow,
                        severity: child.isBirthEstimated ? .warning : .error,
                        guardianID: guardianID, periodIDs: outside.map(\.id), limit: rules.paternity.withinDaysOfBirth
                    )
                )
            }
        }
        return issues
    }

    private func parentalIssues(
        _ sorted: [LeavePeriodInput], guardianID: String, child: LeaveChild, calendar: Calendar
    ) -> [LeaveIssue] {
        let list = sorted.filter { $0.kind == .parental || $0.kind == .parentalSixPlusSix }
        guard !list.isEmpty else { return [] }
        var issues: [LeaveIssue] = []

        let limitDays = rules.days(inMonths: rules.parental.maxMonthsPerParent)
        if totalDays(list, calendar: calendar) > limitDays {
            issues.append(
                LeaveIssue(
                    .parentalExceedsMax, guardianID: guardianID, periodIDs: list.map(\.id),
                    limit: rules.parental.maxMonthsPerParent
                )
            )
        }

        if let birth = child.referenceBirth {
            // 만 N세 이하: 자녀가 N+1세 생일을 맞기 전날까지 시작할 수 있다
            let cutoff = calendar.date(
                byAdding: .year, value: rules.parental.childMaxAgeYears + 1, to: calendar.startOfDay(for: birth)
            )
            let tooOld = list.filter { period in
                guard let cutoff else { return false }
                return calendar.startOfDay(for: period.start) >= cutoff
            }
            if !tooOld.isEmpty {
                issues.append(
                    LeaveIssue(
                        .parentalChildTooOld,
                        severity: child.isBirthEstimated ? .warning : .error,
                        guardianID: guardianID, periodIDs: tooOld.map(\.id), limit: rules.parental.childMaxAgeYears
                    )
                )
            }

            let sixPlusSix = list.filter { $0.kind == .parentalSixPlusSix }
            let sixCutoff = calendar.date(
                byAdding: .month, value: rules.parental.sixPlusSix.childMaxAgeMonths, to: calendar.startOfDay(for: birth)
            )
            let tooOldForSix = sixPlusSix.filter { period in
                guard let sixCutoff else { return false }
                return calendar.startOfDay(for: period.start) >= sixCutoff
            }
            if !tooOldForSix.isEmpty {
                issues.append(
                    LeaveIssue(
                        .sixPlusSixChildTooOld,
                        severity: child.isBirthEstimated ? .warning : .error,
                        guardianID: guardianID, periodIDs: tooOldForSix.map(\.id),
                        limit: rules.parental.sixPlusSix.childMaxAgeMonths
                    )
                )
            }
        }
        return issues
    }

    private func reducedHoursIssues(
        _ sorted: [LeavePeriodInput], guardianID: String, calendar: Calendar
    ) -> [LeaveIssue] {
        let list = sorted.filter { $0.kind == .reducedHours }
        guard !list.isEmpty else { return [] }
        var issues: [LeaveIssue] = []

        for period in list {
            guard let hours = period.weeklyHours else {
                issues.append(LeaveIssue(.reducedHoursMissingHours, guardianID: guardianID, periodIDs: [period.id]))
                continue
            }
            if hours < rules.reducedHours.minWeeklyHours || hours > rules.reducedHours.maxWeeklyHours {
                issues.append(
                    LeaveIssue(
                        .reducedHoursOutOfRange, guardianID: guardianID, periodIDs: [period.id],
                        limit: Int(rules.reducedHours.maxWeeklyHours)
                    )
                )
            }
        }
        if totalDays(list, calendar: calendar) > rules.days(inMonths: rules.reducedHours.maxMonths) {
            issues.append(
                LeaveIssue(
                    .reducedHoursTooLong, guardianID: guardianID, periodIDs: list.map(\.id),
                    limit: rules.reducedHours.maxMonths
                )
            )
        }
        return issues
    }

    /// 6+6 은 부모가 모두 육아휴직을 써야 한다는 가정(규칙 검증 필요)에서, 한쪽만 있으면 경고
    private func sixPlusSixCoupleIssues(
        _ periods: [LeavePeriodInput], child: LeaveChild, calendar: Calendar
    ) -> [LeaveIssue] {
        let sixPlusSix = periods.filter { $0.kind == .parentalSixPlusSix }
        guard !sixPlusSix.isEmpty else { return [] }
        let parentalGuardians = Set(
            periods.filter { $0.kind == .parental || $0.kind == .parentalSixPlusSix }.map(\.guardianID)
        )
        guard parentalGuardians.count < 2 else { return [] }
        return [
            LeaveIssue(
                .sixPlusSixNeedsBothParents, severity: .warning,
                guardianID: sixPlusSix.first?.guardianID, periodIDs: sixPlusSix.map(\.id)
            )
        ]
    }
}
