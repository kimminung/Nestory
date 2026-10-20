import Foundation
import Testing
@testable import NestoryKit

struct RuleMetaTests {
    private func meta(_ status: String, verifiedAt: String?) throws -> RuleMeta {
        let verified = verifiedAt.map { "\"\($0)\"" } ?? "null"
        return try decode(RuleMeta.self, """
        {"id":"t","schemaVersion":1,"status":"\(status)","effectiveFrom":null,"verifiedAt":\(verified),
         "sourceName":"s","sourceURL":null,"note":null}
        """)
    }

    @Test func calendarDateDecodesAndRoundTrips() throws {
        let date = try decode(CalendarDate.self, "\"2026-10-20\"")
        #expect(date == CalendarDate(year: 2026, month: 10, day: 20))
        #expect(date.date() == day(2026, 10, 20))
        let encoded = try JSONEncoder().encode(date)
        #expect(String(decoding: encoded, as: UTF8.self) == "\"2026-10-20\"")
    }

    @Test func malformedCalendarDateFails() {
        #expect(throws: DecodingError.self) { try decode(CalendarDate.self, "\"2026/10/20\"") }
        #expect(throws: DecodingError.self) { try decode(CalendarDate.self, "\"2026-10\"") }
    }

    @Test func verifiedBecomesStaleAfter180Days() throws {
        let m = try meta("verified", verifiedAt: "2026-01-01")
        #expect(m.freshness(now: day(2026, 6, 30)) == .fresh(ageDays: 180))   // 정확히 180일은 아직 유효
        #expect(m.freshness(now: day(2026, 7, 1)) == .stale(ageDays: 181))
    }

    @Test func unverifiedAndMissingAreNeverTrusted() throws {
        let draft = try meta("unverified", verifiedAt: nil)
        let missing = try meta("missing", verifiedAt: nil)
        #expect(draft.freshness(now: day(2026, 10, 20)) == .unverified)
        #expect(missing.freshness(now: day(2026, 10, 20)) == .missing)
        #expect(!draft.isTrustworthy(now: day(2026, 10, 20)))
        #expect(!missing.isTrustworthy(now: day(2026, 10, 20)))
    }

    @Test func verifiedWithoutDateIsTreatedAsUnverified() throws {
        let m = try meta("verified", verifiedAt: nil)
        #expect(m.freshness(now: day(2026, 10, 20)) == .unverified)
    }

    @Test func offsetAppliesMonthsThenDays() {
        let birth = day(2026, 1, 15)
        #expect(RuleOffset(months: 7, days: -1).apply(to: birth) == day(2026, 8, 14))
        #expect(RuleOffset(weeks: 2, days: 3).apply(to: birth) == day(2026, 2, 1))
        #expect(RuleOffset(years: 4).apply(to: birth) == day(2030, 1, 15))
    }
}

/// 번들된 규칙 JSON 이 읽히고, 아직 검증되지 않은 값이 확정처럼 보이지 않는지 확인한다.
struct BundledRulesTests {
    @Test func everyBundledFileDecodes() throws {
        _ = try ScheduleRuleSet.bundledPrenatal()
        _ = try ScheduleRuleSet.bundledInfantCheckups()
        _ = try VaccineRuleSet.bundled()
        _ = try LeaveRuleSet.bundled()
        _ = try GrowthReference.bundled()
    }

    @Test func unverifiedDraftsAreNotTrustworthy() throws {
        let metas = [
            try ScheduleRuleSet.bundledPrenatal().meta,
            try ScheduleRuleSet.bundledInfantCheckups().meta,
            try VaccineRuleSet.bundled().meta,
            try LeaveRuleSet.bundled().meta,
        ]
        // 공식 출처로 검증하면 verified + verifiedAt 으로 바꾸고 이 테스트의 기대를 갱신한다(P1.1).
        for meta in metas where meta.status != .verified {
            #expect(!meta.isTrustworthy(now: day(2026, 10, 20)), "\(meta.id)")
        }
        for meta in metas {
            #expect(!meta.sourceName.isEmpty, "\(meta.id): 출처 이름 필요")
        }
    }

    @Test func growthReferenceIsMissingUntilRealDataIsImported() throws {
        let growth = try GrowthReference.bundled()
        #expect(growth.meta.status == .missing)
        #expect(growth.tables.isEmpty, "공식 LMS 표 없이 값을 추정해 넣으면 안 돼요")
    }

    @Test func scheduleRulesAreConsistent() throws {
        let anchors = ScheduleAnchors(lmp: day(2026, 1, 1))
        for set in [try ScheduleRuleSet.bundledPrenatal(), try ScheduleRuleSet.bundledInfantCheckups()] {
            #expect(Set(set.rules.map(\.id)).count == set.rules.count, "\(set.meta.id): 규칙 id 중복")
            for item in ScheduleGenerator.generate(set.rules, anchors: anchors) {
                #expect(item.windowStart <= item.recommended, "\(item.ruleID)")
                #expect(item.recommended <= item.windowEnd, "\(item.ruleID)")
            }
        }
    }

    @Test func vaccineRulesAreConsistent() throws {
        let set = try VaccineRuleSet.bundled()
        #expect(Set(set.vaccines.map(\.code)).count == set.vaccines.count)
        for vaccine in set.vaccines {
            let numbers = vaccine.doses.map(\.doseNo)
            #expect(numbers == Array(1...numbers.count), "\(vaccine.code): 차수는 1부터 연속이어야 해요")
        }
        // 모든 차수에서 earliest ≤ recommended ≤ latest
        let doses = VaccineScheduler.schedule(
            birth: day(2026, 1, 1), rules: set, records: [], now: day(2026, 1, 1)
        )
        for dose in doses {
            #expect(dose.earliestDate <= dose.scheduledDate, "\(dose.id)")
            #expect(dose.scheduledDate <= dose.latestDate, "\(dose.id)")
        }
    }

    @Test func leaveRulesAreInternallyConsistent() throws {
        let leave = try LeaveRuleSet.bundled()
        let special = leave.parental.sixPlusSix
        #expect(special.monthlyCapByMonth.count >= special.months)
        #expect(leave.parental.benefit.monthlyFloor <= leave.parental.benefit.monthlyCap)
        #expect(leave.reducedHours.minWeeklyHours <= leave.reducedHours.maxWeeklyHours)
        #expect(leave.reducedHours.maxWeeklyHours < leave.reducedHours.fullTimeWeeklyHours)
    }
}
