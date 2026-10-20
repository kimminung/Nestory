import Foundation
import Testing
@testable import NestoryKit

struct ScheduleGeneratorTests {
    private let rules: [ScheduleRule] = {
        let set = try! ScheduleRuleSet.bundledPrenatal()
        return set.rules
    }()

    @Test func lmpAnchoredWindowsUseWeekOffsets() throws {
        let items = ScheduleGenerator.generate(rules, anchors: ScheduleAnchors(lmp: day(2026, 1, 1)))
        let first = try #require(items.first { $0.ruleID == "prenatal.firstScreening" })
        // 11주 0일 ~ 13주 6일, 권장 12주
        #expect(first.windowStart == day(2026, 3, 19))
        #expect(first.windowEnd == day(2026, 4, 8))   // 13주 6일 = 97일
        #expect(first.recommended == day(2026, 3, 26))
        #expect(!first.isEstimated)
    }

    @Test func dueDateAloneDerivesLMP() throws {
        let fromLMP = ScheduleGenerator.generate(rules, anchors: ScheduleAnchors(lmp: day(2026, 1, 1)))
        let fromDue = ScheduleGenerator.generate(rules, anchors: ScheduleAnchors(due: day(2026, 10, 8)))
        #expect(fromLMP == fromDue)
    }

    @Test func birthRulesAreEstimatedFromDueDateUntilBirth() throws {
        let estimated = ScheduleGenerator.generate(rules, anchors: ScheduleAnchors(due: day(2026, 10, 8)))
        let registration = try #require(estimated.first { $0.ruleID == "birth.registration" })
        #expect(registration.isEstimated)
        #expect(registration.windowEnd == day(2026, 11, 7))

        let actual = ScheduleGenerator.generate(
            rules, anchors: ScheduleAnchors(due: day(2026, 10, 8), birth: day(2026, 10, 1))
        )
        let real = try #require(actual.first { $0.ruleID == "birth.registration" })
        #expect(!real.isEstimated)
        #expect(real.windowEnd == day(2026, 10, 31))
    }

    @Test func rulesWithoutAnchorAreSkipped() {
        #expect(ScheduleGenerator.generate(rules, anchors: ScheduleAnchors()).isEmpty)
    }

    @Test func resultIsSortedByRecommendedDate() {
        let items = ScheduleGenerator.generate(rules, anchors: ScheduleAnchors(lmp: day(2026, 1, 1)))
        #expect(items.map(\.recommended) == items.map(\.recommended).sorted())
    }

    @Test(arguments: [
        (day(2026, 3, 18), false, ScheduleStatus.upcoming),
        (day(2026, 3, 19), false, .open),      // 창 시작일 포함
        (day(2026, 4, 8), false, .open),       // 창 마지막 날 포함
        (day(2026, 4, 9), false, .overdue),
        (day(2026, 4, 9), true, .done),        // 완료는 시기와 무관
    ])
    func statusBoundaries(now: Date, isDone: Bool, expected: ScheduleStatus) throws {
        let items = ScheduleGenerator.generate(rules, anchors: ScheduleAnchors(lmp: day(2026, 1, 1)))
        let item = try #require(items.first { $0.ruleID == "prenatal.firstScreening" })
        #expect(item.status(now: now, isDone: isDone) == expected)
    }

    @Test func infantCheckupsFollowBirthDate() throws {
        let set = try ScheduleRuleSet.bundledInfantCheckups()
        let items = ScheduleGenerator.generate(set.rules, anchors: ScheduleAnchors(birth: day(2026, 1, 15)))
        #expect(items.count == 8)
        let first = try #require(items.first { $0.ruleID == "checkup.1" })
        #expect(first.windowStart == day(2026, 1, 29))   // 생후 14일
        #expect(first.windowEnd == day(2026, 2, 19))     // 생후 35일
        let second = try #require(items.first { $0.ruleID == "checkup.2" })
        #expect(second.windowStart == day(2026, 5, 15))  // 4개월
        #expect(second.windowEnd == day(2026, 8, 14))    // 6개월 + 29일 (7개월 − 1일)
    }
}

struct VaccineSchedulerTests {
    /// 3차 접종 백신 하나. 간격 규칙(28일)과 따라잡기를 검증하기 위한 고정 규칙.
    private let rules: VaccineRuleSet = try! decode(VaccineRuleSet.self, """
    {"meta":{"id":"v","schemaVersion":1,"status":"verified","effectiveFrom":null,"verifiedAt":"2026-10-01",
             "sourceName":"fixture","sourceURL":null,"note":null},
     "vaccines":[{"code":"X","name":"테스트 백신","note":null,"doses":[
       {"doseNo":1,"earliest":{"months":2},"recommended":{"months":2},"latest":{"months":3},"minIntervalDays":null},
       {"doseNo":2,"earliest":{"months":4},"recommended":{"months":4},"latest":{"months":5},"minIntervalDays":28},
       {"doseNo":3,"earliest":{"months":6},"recommended":{"months":6},"latest":{"months":7},"minIntervalDays":28}]}]}
    """)

    private let birth = day(2026, 1, 1)

    private func dose(_ doses: [VaccineDose], _ no: Int) -> VaccineDose {
        doses.first { $0.doseNo == no }!
    }

    @Test(arguments: [
        (day(2026, 2, 28), VaccineStatus.upcoming),
        (day(2026, 3, 1), .open),        // earliest 당일부터 가능
        (day(2026, 4, 1), .open),        // latest 당일까지 가능
        (day(2026, 4, 2), .overdue),
    ])
    func firstDoseStatusBoundaries(now: Date, expected: VaccineStatus) {
        let doses = VaccineScheduler.schedule(birth: birth, rules: rules, records: [], now: now)
        #expect(dose(doses, 1).status == expected)
    }

    @Test func lateDoseShiftsNextDoseByMinimumInterval() {
        let records = [VaccineDoseRecord(code: "X", doseNo: 1, date: day(2026, 4, 10))]
        let doses = VaccineScheduler.schedule(birth: birth, rules: rules, records: records, now: day(2026, 4, 11))
        let second = dose(doses, 2)
        #expect(dose(doses, 1).status == .done)
        #expect(second.earliestDate == day(2026, 5, 8))    // 4/10 + 28일 (나이 기준 5/1 보다 늦음)
        #expect(second.scheduledDate == day(2026, 5, 8))
        #expect(second.latestDate == day(2026, 6, 1))
    }

    @Test func onTimeDoseKeepsAgeBasedSchedule() {
        let records = [VaccineDoseRecord(code: "X", doseNo: 1, date: day(2026, 3, 1))]
        let second = dose(
            VaccineScheduler.schedule(birth: birth, rules: rules, records: records, now: day(2026, 3, 2)), 2
        )
        #expect(second.scheduledDate == day(2026, 5, 1))
    }

    @Test func undoneDoseProjectsLaterDosesFromItsScheduledDate() {
        let doses = VaccineScheduler.schedule(birth: birth, rules: rules, records: [], now: day(2026, 1, 2))
        #expect(doses.map(\.doseNo) == [1, 2, 3])
        #expect(dose(doses, 3).scheduledDate == day(2026, 7, 1))
        #expect(doses.allSatisfy { $0.totalDoses == 3 })
    }

    @Test func overdueDoseDoesNotBecomeOpenAgainWhenNextIsPending() {
        // 1차를 놓친 채 시간이 흘러 2차 시기가 됐다: 1차는 지연, 2차는 열려 있다
        let doses = VaccineScheduler.schedule(birth: birth, rules: rules, records: [], now: day(2026, 5, 10))
        #expect(dose(doses, 1).status == .overdue)
        #expect(dose(doses, 2).status == .open)
    }

    @Test func bundledDraftProducesDosesForEveryVaccine() throws {
        let set = try VaccineRuleSet.bundled()
        let doses = VaccineScheduler.schedule(birth: birth, rules: set, records: [], now: birth)
        #expect(doses.count == set.vaccines.reduce(0) { $0 + $1.doses.count })
        #expect(doses.map(\.scheduledDate) == doses.map(\.scheduledDate).sorted())
        let hepB1 = try #require(doses.first { $0.id == "HepB#1" })
        #expect(hepB1.scheduledDate == birth)
    }
}

struct GrowthPercentileTests {
    private let unit = LMSPoint(ageMonths: 0, l: 1, m: 10, s: 0.1)

    @Test func zScoreFollowsLMSFormula() {
        #expect(abs(GrowthPercentile.zScore(value: 11, point: unit) - 1) < 1e-9)    // L=1: (x/M − 1)/S
        #expect(abs(GrowthPercentile.zScore(value: 10, point: unit)) < 1e-9)
        let logPoint = LMSPoint(ageMonths: 0, l: 0, m: 10, s: 0.1)                  // L=0: ln(x/M)/S
        #expect(abs(GrowthPercentile.zScore(value: 10 * exp(0.1), point: logPoint) - 1) < 1e-9)
    }

    @Test func percentileMatchesNormalDistribution() {
        #expect(abs(GrowthPercentile.percentile(z: 0) - 50) < 1e-9)
        #expect(abs(GrowthPercentile.percentile(z: 1) - 84.1345) < 0.001)
        for (percentile, z) in GrowthPercentile.bands {
            #expect(abs(GrowthPercentile.percentile(z: z) - Double(percentile)) < 0.1, "P\(percentile)")
        }
    }

    @Test func valueInvertsZScore() {
        for l in [1.0, -0.5, 0.0, 2.0] {
            let point = LMSPoint(ageMonths: 3, l: l, m: 6, s: 0.12)
            for z in [-1.8808, 0, 1.0364] {
                let x = GrowthPercentile.value(z: z, point: point)
                #expect(abs(GrowthPercentile.zScore(value: x, point: point) - z) < 1e-9, "L=\(l) z=\(z)")
            }
        }
    }

    @Test func interpolationIsLinearInAge() throws {
        let table = GrowthTable(measure: .weight, sex: .male, points: [
            LMSPoint(ageMonths: 0, l: 1, m: 3, s: 0.1),
            LMSPoint(ageMonths: 12, l: 0, m: 9, s: 0.2),
        ])
        let mid = try #require(GrowthPercentile.interpolate(table, ageMonths: 6))
        #expect(abs(mid.l - 0.5) < 1e-12)
        #expect(abs(mid.m - 6) < 1e-12)
        #expect(abs(mid.s - 0.15) < 1e-12)
        #expect(GrowthPercentile.interpolate(table, ageMonths: 0)?.m == 3)
        #expect(GrowthPercentile.interpolate(table, ageMonths: 12)?.m == 9)
        #expect(GrowthPercentile.interpolate(table, ageMonths: -0.1) == nil)
        #expect(GrowthPercentile.interpolate(table, ageMonths: 12.1) == nil)
    }

    @Test func evaluateNeedsTableForMeasureAndSex() throws {
        let meta: RuleMeta = try decode(RuleMeta.self, """
        {"id":"g","schemaVersion":1,"status":"verified","effectiveFrom":null,"verifiedAt":"2026-10-01",
         "sourceName":"fixture","sourceURL":null,"note":null}
        """)
        let reference = GrowthReference(meta: meta, tables: [
            GrowthTable(measure: .weight, sex: .female, points: [unit, LMSPoint(ageMonths: 24, l: 1, m: 12, s: 0.1)])
        ])
        let result = try #require(
            GrowthPercentile.evaluate(value: 11, measure: .weight, sex: .female, ageMonths: 0, reference: reference)
        )
        #expect(abs(result.percentile - 84.1345) < 0.001)
        #expect(GrowthPercentile.evaluate(value: 11, measure: .weight, sex: .male, ageMonths: 0, reference: reference) == nil)
        #expect(GrowthPercentile.evaluate(value: 11, measure: .height, sex: .female, ageMonths: 0, reference: reference) == nil)
        #expect(GrowthPercentile.evaluate(value: 0, measure: .weight, sex: .female, ageMonths: 0, reference: reference) == nil)
    }

    @Test func bundledMissingDataYieldsNoResult() throws {
        let reference = try GrowthReference.bundled()
        #expect(reference.meta.freshness(now: day(2026, 10, 20)) == .missing)
        #expect(
            GrowthPercentile.evaluate(value: 5, measure: .weight, sex: .female, ageMonths: 3, reference: reference) == nil
        )
    }

    @Test func ageMonthsUsesMeanMonthLength() {
        #expect(abs(GrowthPercentile.ageMonths(birth: day(2026, 1, 1), on: day(2027, 1, 1)) - 365 / 30.4375) < 1e-9)
    }
}
