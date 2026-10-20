import Foundation

/// 한 백신의 N차 접종 규칙. 모든 간격은 출생일 기준.
public struct VaccineDoseRule: Codable, Hashable, Sendable {
    public let doseNo: Int
    /// 이 날부터 접종 가능
    public let earliest: RuleOffset
    public let recommended: RuleOffset
    /// 권장 접종 기간의 끝. 이후에는 "지연"
    public let latest: RuleOffset
    /// 직전 차수 접종일로부터 최소 간격(일)
    public let minIntervalDays: Int?
}

public struct VaccineRule: Codable, Identifiable, Hashable, Sendable {
    public let code: String
    public let name: String
    public let note: String?
    public let doses: [VaccineDoseRule]

    public var id: String { code }
}

public struct VaccineRuleSet: Codable, Sendable {
    public let meta: RuleMeta
    public let vaccines: [VaccineRule]

    public static func bundled() throws -> VaccineRuleSet {
        try RuleLoader.loadBundled("vaccine")
    }
}

/// 사용자가 기록한 접종 완료
public struct VaccineDoseRecord: Hashable, Sendable {
    public let code: String
    public let doseNo: Int
    public let date: Date

    public init(code: String, doseNo: Int, date: Date) {
        self.code = code
        self.doseNo = doseNo
        self.date = date
    }
}

public enum VaccineStatus: Equatable, Sendable {
    case done, upcoming, open, overdue
}

public struct VaccineDose: Identifiable, Hashable, Sendable {
    public let code: String
    public let name: String
    public let doseNo: Int
    public let totalDoses: Int
    /// 접종 가능해지는 날
    public let earliestDate: Date
    /// 권장 접종일(앞 차수가 늦어졌으면 그만큼 밀린다)
    public let scheduledDate: Date
    /// 이 날이 지나면 "지연"
    public let latestDate: Date
    public let doneDate: Date?
    public let status: VaccineStatus

    public var id: String { "\(code)#\(doseNo)" }
}

public enum VaccineScheduler {
    /// 출생일과 접종 기록으로 모든 차수의 일정·상태를 계산한다.
    ///
    /// 앞 차수가 늦어지면 다음 차수는 `앞 차수 접종일 + 최소 간격` 이후로 밀린다(따라잡기).
    /// 앞 차수가 아직 안 끝났다면 그 차수의 *예정일*을 기준으로 이어서 계산한다.
    public static func schedule(
        birth: Date,
        rules: VaccineRuleSet,
        records: [VaccineDoseRecord],
        now: Date,
        calendar: Calendar = .korea
    ) -> [VaccineDose] {
        let today = calendar.startOfDay(for: now)
        let doneByKey = Dictionary(
            records.map { ("\($0.code)#\($0.doseNo)", $0.date) },
            uniquingKeysWith: { first, _ in first }
        )

        var result: [VaccineDose] = []
        for vaccine in rules.vaccines {
            var previous: Date?
            for rule in vaccine.doses.sorted(by: { $0.doseNo < $1.doseNo }) {
                let key = "\(vaccine.code)#\(rule.doseNo)"
                let ageEarliest = rule.earliest.apply(to: birth, calendar: calendar)
                let recommended = rule.recommended.apply(to: birth, calendar: calendar)
                let ageLatest = rule.latest.apply(to: birth, calendar: calendar)

                var earliest = ageEarliest
                if let previous, let interval = rule.minIntervalDays {
                    earliest = max(earliest, calendar.adding(days: interval, to: previous))
                }
                let scheduled = max(recommended, earliest)
                let latest = max(ageLatest, scheduled)

                let done = doneByKey[key].map { calendar.startOfDay(for: $0) }
                let status: VaccineStatus
                if done != nil {
                    status = .done
                } else if today < earliest {
                    status = .upcoming
                } else if today > latest {
                    status = .overdue
                } else {
                    status = .open
                }

                result.append(
                    VaccineDose(
                        code: vaccine.code,
                        name: vaccine.name,
                        doseNo: rule.doseNo,
                        totalDoses: vaccine.doses.count,
                        earliestDate: earliest,
                        scheduledDate: scheduled,
                        latestDate: latest,
                        doneDate: done,
                        status: status
                    )
                )
                // 다음 차수의 기준: 실제 접종일, 없으면 예정일
                previous = done ?? scheduled
            }
        }
        return result.sorted { ($0.scheduledDate, $0.code, $0.doseNo) < ($1.scheduledDate, $1.code, $1.doseNo) }
    }
}
