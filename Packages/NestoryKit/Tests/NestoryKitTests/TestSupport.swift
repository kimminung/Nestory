import Foundation
@testable import NestoryKit

/// 테스트 공용: 한국 달력의 날짜 만들기
let kst = Calendar.korea

func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
    kst.date(from: DateComponents(year: year, month: month, day: day))!
}

func decode<T: Decodable>(_ type: T.Type = T.self, _ json: String) throws -> T {
    try RuleLoader.decode(type, from: Data(json.utf8))
}

/// 번들 규칙(초안)이 교정돼도 계산 로직 테스트가 흔들리지 않도록 고정한 휴직 규칙
enum LeaveFixture {
    static let json = """
    {
      "meta": {"id":"leave-fixture","schemaVersion":1,"status":"verified","effectiveFrom":"2026-01-01",
               "verifiedAt":"2026-10-01","sourceName":"fixture","sourceURL":null,"note":null},
      "maternity": {"totalDaysSingle":90,"minPostBirthDaysSingle":45,"totalDaysMultiple":120,
                    "minPostBirthDaysMultiple":60,"paidRate":1.0,"monthlyCap":null},
      "paternity": {"days":20,"withinDaysOfBirth":120,"maxSplits":3,"paidRate":1.0},
      "parental": {"maxMonthsPerParent":12,"childMaxAgeYears":8,"applyDaysBefore":30,
        "benefit":{"rate":0.8,"monthlyCap":1500000,"monthlyFloor":700000},
        "sixPlusSix":{"childMaxAgeMonths":18,"months":6,"rate":1.0,
                      "monthlyCapByMonth":[2500000,2500000,3000000,3500000,4000000,4500000]}},
      "reducedHours": {"fullTimeWeeklyHours":40,"minWeeklyHours":15,"maxWeeklyHours":35,"maxMonths":36,
                       "supportRate":0.8,"supportMonthlyCap":1500000,"applyDaysBefore":30}
    }
    """

    static func rules() throws -> LeaveRuleSet { try decode(LeaveRuleSet.self, json) }
}

func period(
    _ id: String, _ guardian: String, _ kind: LeaveKind,
    _ start: Date, _ end: Date, hours: Double? = nil
) -> LeavePeriodInput {
    LeavePeriodInput(id: id, guardianID: guardian, kind: kind, start: start, end: end, weeklyHours: hours)
}
