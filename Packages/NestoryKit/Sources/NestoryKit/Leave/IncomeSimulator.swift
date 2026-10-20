import Foundation

public struct IncomeGuardian: Hashable, Sendable {
    public let id: String
    /// 월 통상임금(원)
    public let monthlyOrdinaryWage: Int

    public init(id: String, monthlyOrdinaryWage: Int) {
        self.id = id
        self.monthlyOrdinaryWage = monthlyOrdinaryWage
    }
}

public struct MonthlyIncome: Hashable, Sendable {
    public let monthStart: Date
    public let byGuardian: [String: Int]

    public var total: Int { byGuardian.values.reduce(0, +) }
}

public struct IncomeProjection: Hashable, Sendable {
    public let months: [MonthlyIncome]
    public let totalByGuardian: [String: Int]
    /// 휴가·휴직 없이 계속 일했을 때의 같은 기간 소득 합계
    public let baselineTotal: Int

    public var total: Int { totalByGuardian.values.reduce(0, +) }
    /// 계속 일했을 때보다 줄어드는 금액 (음수면 늘어남)
    public var shortfall: Int { baselineTotal - total }
}

/// 휴직 시나리오의 월별 예상 소득. 세전 금액이며 근사치다.
///
/// 단순화 가정(문서 §2.4 / 규칙 JSON 의 note 참고):
/// - 월 금액을 그 달의 일수로 나눠 하루 단위로 더한다(부분 월 안분).
/// - 한 날에 여러 종류가 겹치면 출산전후 > 배우자 출산휴가 > 6+6 > 육아휴직 > 근로시간 단축 > 연차 > 가족돌봄 순.
/// - 휴직 기간이 없는 날은 통상임금 전액.
public struct IncomeSimulator: Sendable {
    public let rules: LeaveRuleSet

    public init(rules: LeaveRuleSet) {
        self.rules = rules
    }

    public func project(
        guardians: [IncomeGuardian],
        periods: [LeavePeriodInput],
        calendar: Calendar = .korea
    ) -> IncomeProjection {
        let valid = periods.filter {
            calendar.startOfDay(for: $0.start) <= calendar.startOfDay(for: $0.end)
        }
        guard let first = valid.map(\.start).min(),
              let last = valid.map(\.end).max(),
              let firstMonth = calendar.dateInterval(of: .month, for: first),
              let lastMonth = calendar.dateInterval(of: .month, for: last) else {
            return IncomeProjection(months: [], totalByGuardian: [:], baselineTotal: 0)
        }

        let periodsByGuardian = Dictionary(grouping: valid, by: \.guardianID)
        var sixPlusSixDays: [String: Int] = [:]
        var months: [MonthlyIncome] = []
        var monthStart = firstMonth.start

        while monthStart <= lastMonth.start {
            let dayCount = calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 30
            var sums: [String: Double] = [:]

            for offset in 0..<dayCount {
                let day = calendar.startOfDay(for: calendar.adding(days: offset, to: monthStart))
                for guardian in guardians {
                    let active = (periodsByGuardian[guardian.id] ?? [])
                        .filter {
                            calendar.startOfDay(for: $0.start) <= day && day <= calendar.startOfDay(for: $0.end)
                        }
                        .min { Self.priority($0.kind) < Self.priority($1.kind) }

                    let monthly: Double
                    if let active {
                        let used = sixPlusSixDays[guardian.id, default: 0]
                        monthly = monthlyAmount(for: active, wage: guardian.monthlyOrdinaryWage, sixPlusSixDaysUsed: used)
                        if active.kind == .parentalSixPlusSix { sixPlusSixDays[guardian.id] = used + 1 }
                    } else {
                        monthly = Double(guardian.monthlyOrdinaryWage)
                    }
                    sums[guardian.id, default: 0] += monthly / Double(dayCount)
                }
            }

            months.append(
                MonthlyIncome(
                    monthStart: monthStart,
                    byGuardian: sums.mapValues { Int($0.rounded()) }
                )
            )
            guard let next = calendar.date(byAdding: .month, value: 1, to: monthStart) else { break }
            monthStart = next
        }

        var totals: [String: Int] = [:]
        for month in months {
            for (id, amount) in month.byGuardian { totals[id, default: 0] += amount }
        }
        let baseline = guardians.reduce(0) { $0 + $1.monthlyOrdinaryWage * months.count }
        return IncomeProjection(months: months, totalByGuardian: totals, baselineTotal: baseline)
    }

    // MARK: - 금액 규칙

    static func priority(_ kind: LeaveKind) -> Int {
        switch kind {
        case .maternity: 0
        case .paternity: 1
        case .parentalSixPlusSix: 2
        case .parental: 3
        case .reducedHours: 4
        case .annual: 5
        case .familyCare: 6
        }
    }

    /// 통상임금 `wage` 인 보호자가 `period` 상태일 때의 월 금액
    func monthlyAmount(for period: LeavePeriodInput, wage: Int, sixPlusSixDaysUsed: Int) -> Double {
        let wage = Double(wage)
        switch period.kind {
        case .maternity:
            let paid = wage * rules.maternity.paidRate
            return rules.maternity.monthlyCap.map { min(paid, Double($0)) } ?? paid
        case .paternity:
            return wage * rules.paternity.paidRate
        case .annual:
            return wage
        case .familyCare:
            return 0
        case .parental:
            return parentalBenefit(wage: wage)
        case .parentalSixPlusSix:
            let special = rules.parental.sixPlusSix
            guard sixPlusSixDaysUsed < rules.days(inMonths: special.months), !special.monthlyCapByMonth.isEmpty else {
                return parentalBenefit(wage: wage)
            }
            let month = min(Int(Double(sixPlusSixDaysUsed) / 30.4375), special.monthlyCapByMonth.count - 1)
            return min(wage * special.rate, Double(special.monthlyCapByMonth[month]))
        case .reducedHours:
            let reduced = rules.reducedHours
            let ratio = min(max((period.weeklyHours ?? reduced.fullTimeWeeklyHours) / reduced.fullTimeWeeklyHours, 0), 1)
            let support = min(Double(reduced.supportMonthlyCap), wage * (1 - ratio) * reduced.supportRate)
            return wage * ratio + support
        }
    }

    /// 육아휴직급여: 통상임금 × 비율, 하한·상한 적용
    func parentalBenefit(wage: Double) -> Double {
        let benefit = rules.parental.benefit
        return min(max(wage * benefit.rate, Double(benefit.monthlyFloor)), Double(benefit.monthlyCap))
    }
}
