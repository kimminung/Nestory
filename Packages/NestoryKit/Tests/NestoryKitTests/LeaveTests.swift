import Foundation
import Testing
@testable import NestoryKit

struct LeaveEngineTests {
    private let engine = LeaveEngine(rules: try! LeaveFixture.rules())
    private let single = LeaveChild(birthDate: day(2026, 6, 1))

    private func codes(_ issues: [LeaveIssue]) -> [LeaveIssueCode] { issues.map(\.code) }

    @Test func validMaternityLeaveHasNoIssues() {
        // 5/1~7/29 = 90일, 출산(6/1) 후 59일
        let issues = engine.validate(periods: [period("m", "mom", .maternity, day(2026, 5, 1), day(2026, 7, 29))], child: single)
        #expect(issues.isEmpty)
    }

    @Test func maternityTotalLimitDependsOnMultiples() {
        let long = [period("m", "mom", .maternity, day(2026, 5, 1), day(2026, 7, 30))]   // 91일
        #expect(codes(engine.validate(periods: long, child: single)) == [.maternityTooLong])
        let twins = LeaveChild(birthDate: day(2026, 6, 1), isMultiple: true)
        #expect(engine.validate(periods: long, child: twins).isEmpty)                     // 120일까지 가능, 출산 후 60일 이상
    }

    @Test func maternityNeedsEnoughDaysAfterBirth() throws {
        let early = [period("m", "mom", .maternity, day(2026, 4, 1), day(2026, 6, 10))]   // 출산 후 10일뿐
        let issue = try #require(engine.validate(periods: early, child: single).first)
        #expect(issue.code == .maternityPostBirthTooShort)
        #expect(issue.severity == .error)
        #expect(issue.limit == 45)

        // 출산일을 예정일로 추정한 경우는 경고
        let estimated = LeaveChild(dueDate: day(2026, 6, 1))
        #expect(engine.validate(periods: early, child: estimated).first?.severity == .warning)
    }

    @Test func maternityPostBirthBoundaryIs45DaysInclusive() {
        // 출산 당일 포함 45일 = 6/1 ~ 7/15
        let exact = [period("m", "mom", .maternity, day(2026, 5, 1), day(2026, 7, 15))]
        #expect(engine.validate(periods: exact, child: single).isEmpty)
        let oneShort = [period("m", "mom", .maternity, day(2026, 5, 1), day(2026, 7, 14))]
        #expect(codes(engine.validate(periods: oneShort, child: single)) == [.maternityPostBirthTooShort])
    }

    @Test func paternityWindowEndsOn120thDayAfterBirth() {
        // 6/1 + 120일 = 9/29
        let ok = [period("p", "dad", .paternity, day(2026, 9, 20), day(2026, 9, 29))]
        #expect(engine.validate(periods: ok, child: single).isEmpty)
        let late = [period("p", "dad", .paternity, day(2026, 9, 25), day(2026, 9, 30))]
        #expect(codes(engine.validate(periods: late, child: single)) == [.paternityOutsideWindow])
    }

    @Test func paternityDayAndSplitLimits() {
        let tooLong = [period("p", "dad", .paternity, day(2026, 6, 2), day(2026, 6, 22))]    // 21일
        #expect(codes(engine.validate(periods: tooLong, child: single)) == [.paternityTooManyDays])

        let split = (0..<4).map { i in
            period("p\(i)", "dad", .paternity, day(2026, 6, 2 + i * 3), day(2026, 6, 2 + i * 3))
        }
        #expect(codes(engine.validate(periods: split, child: single)) == [.paternityTooManySplits])
        #expect(engine.validate(periods: Array(split.prefix(3)), child: single).isEmpty)
    }

    @Test func parentalLeaveLengthLimitIs365DaysPerParent() {
        let year = [period("a", "mom", .parental, day(2026, 9, 1), day(2027, 8, 31))]        // 365일
        #expect(engine.validate(periods: year, child: single).isEmpty)
        let over = [period("a", "mom", .parental, day(2026, 9, 1), day(2027, 9, 1))]          // 366일
        #expect(codes(engine.validate(periods: over, child: single)) == [.parentalExceedsMax])

        // 부모가 각각 쓰면 각자 한도
        let both = year + [period("b", "dad", .parental, day(2026, 9, 1), day(2027, 8, 31))]
        #expect(engine.validate(periods: both, child: single).isEmpty)
    }

    @Test func parentalLeaveLimitCountsAcrossSplitPeriods() {
        let split = [
            period("a", "mom", .parental, day(2026, 9, 1), day(2027, 1, 31)),    // 153일
            period("b", "mom", .parental, day(2027, 6, 1), day(2027, 12, 31)),   // 214일 → 합 367일
        ]
        #expect(codes(engine.validate(periods: split, child: single)) == [.parentalExceedsMax])
    }

    @Test func parentalLeaveMustStartBeforeNinthBirthday() {
        let child = LeaveChild(birthDate: day(2018, 6, 1))
        let lastDay = [period("a", "mom", .parental, day(2027, 5, 31), day(2027, 6, 30))]
        #expect(engine.validate(periods: lastDay, child: child).isEmpty)
        let tooLate = [period("a", "mom", .parental, day(2027, 6, 1), day(2027, 6, 30))]
        #expect(codes(engine.validate(periods: tooLate, child: child)) == [.parentalChildTooOld])
    }

    @Test func sixPlusSixRequiresBothParentsAndYoungChild() {
        let momOnly = [period("a", "mom", .parentalSixPlusSix, day(2026, 9, 1), day(2027, 2, 28))]
        let issue = engine.validate(periods: momOnly, child: single).first
        #expect(issue?.code == .sixPlusSixNeedsBothParents)
        #expect(issue?.severity == .warning)

        let both = momOnly + [period("b", "dad", .parentalSixPlusSix, day(2026, 9, 1), day(2027, 2, 28))]
        #expect(engine.validate(periods: both, child: single).isEmpty)

        // 생후 18개월(2027-12-01) 이후 시작은 불가
        let late = [
            period("a", "mom", .parentalSixPlusSix, day(2027, 11, 30), day(2027, 12, 31)),
            period("b", "dad", .parentalSixPlusSix, day(2027, 12, 1), day(2027, 12, 31)),
        ]
        let lateIssues = engine.validate(periods: late, child: single)
        #expect(lateIssues.map(\.code) == [.sixPlusSixChildTooOld])
        #expect(lateIssues.first?.guardianID == "dad")
    }

    @Test func overlappingPeriodsOfSameGuardianAreFlagged() {
        let overlap = [
            period("a", "mom", .parental, day(2026, 9, 1), day(2026, 11, 30)),
            period("b", "mom", .annual, day(2026, 11, 30), day(2026, 12, 5)),
        ]
        let issue = engine.validate(periods: overlap, child: single).first
        #expect(issue?.code == .overlapSameGuardian)
        #expect(issue?.periodIDs == ["a", "b"])

        // 서로 다른 보호자의 겹침은 문제 없다(동시 휴직 가능)
        let different = [
            period("a", "mom", .parental, day(2026, 9, 1), day(2026, 11, 30)),
            period("b", "dad", .parental, day(2026, 10, 1), day(2026, 12, 5)),
        ]
        #expect(engine.validate(periods: different, child: single).isEmpty)
    }

    @Test func endBeforeStartIsReportedAndSkipsOtherChecks() {
        let broken = [period("a", "mom", .maternity, day(2026, 7, 1), day(2026, 6, 1))]
        #expect(codes(engine.validate(periods: broken, child: single)) == [.endBeforeStart])
    }

    @Test func reducedHoursRules() {
        let missing = [period("a", "mom", .reducedHours, day(2027, 1, 1), day(2027, 6, 30))]
        #expect(codes(engine.validate(periods: missing, child: single)) == [.reducedHoursMissingHours])

        let outOfRange = [period("a", "mom", .reducedHours, day(2027, 1, 1), day(2027, 6, 30), hours: 10)]
        #expect(codes(engine.validate(periods: outOfRange, child: single)) == [.reducedHoursOutOfRange])
        let nearFull = [period("a", "mom", .reducedHours, day(2027, 1, 1), day(2027, 6, 30), hours: 36)]
        #expect(codes(engine.validate(periods: nearFull, child: single)) == [.reducedHoursOutOfRange])

        let fine = [period("a", "mom", .reducedHours, day(2027, 1, 1), day(2027, 6, 30), hours: 30)]
        #expect(engine.validate(periods: fine, child: single).isEmpty)

        // 36개월 = 1,096일 초과
        let tooLong = [period("a", "mom", .reducedHours, day(2027, 1, 1), day(2030, 1, 31), hours: 30)]
        #expect(codes(engine.validate(periods: tooLong, child: single)) == [.reducedHoursTooLong])
    }

    @Test func applicationDeadlineIs30DaysBeforeStart() {
        let parental = period("a", "mom", .parental, day(2026, 9, 1), day(2026, 11, 30))
        #expect(engine.applicationDeadline(for: parental) == day(2026, 8, 2))
        let reduced = period("b", "mom", .reducedHours, day(2027, 1, 1), day(2027, 3, 1), hours: 30)
        #expect(engine.applicationDeadline(for: reduced) == day(2026, 12, 2))
        #expect(engine.applicationDeadline(for: period("c", "mom", .maternity, day(2026, 5, 1), day(2026, 7, 1))) == nil)
    }
}

struct IncomeSimulatorTests {
    private let simulator = IncomeSimulator(rules: try! LeaveFixture.rules())

    private func monthly(_ projection: IncomeProjection, _ guardian: String, month index: Int) -> Int {
        projection.months[index].byGuardian[guardian] ?? 0
    }

    @Test func parentalBenefitAppliesRateCapAndFloor() {
        let rules = try! LeaveFixture.rules()
        let sim = IncomeSimulator(rules: rules)
        #expect(sim.parentalBenefit(wage: 3_000_000) == 1_500_000)   // 80% = 240만 → 상한
        #expect(sim.parentalBenefit(wage: 1_000_000) == 800_000)     // 상한·하한 사이
        #expect(sim.parentalBenefit(wage: 800_000) == 700_000)       // 64만 → 하한
    }

    @Test func fullMonthOfParentalLeave() {
        let projection = simulator.project(
            guardians: [IncomeGuardian(id: "mom", monthlyOrdinaryWage: 3_000_000)],
            periods: [period("a", "mom", .parental, day(2026, 3, 1), day(2026, 3, 31))]
        )
        #expect(projection.months.count == 1)
        #expect(monthly(projection, "mom", month: 0) == 1_500_000)
        #expect(projection.baselineTotal == 3_000_000)
        #expect(projection.shortfall == 1_500_000)
    }

    @Test func partialMonthIsProratedByDays() {
        let projection = simulator.project(
            guardians: [IncomeGuardian(id: "mom", monthlyOrdinaryWage: 3_000_000)],
            periods: [period("a", "mom", .parental, day(2026, 3, 16), day(2026, 3, 31))]
        )
        // 15일 근무(월급 3,000,000 / 31) + 16일 휴직(1,500,000 / 31)
        let expected = (15 * 3_000_000.0 + 16 * 1_500_000.0) / 31
        #expect(abs(Double(monthly(projection, "mom", month: 0)) - expected) <= 1)
    }

    @Test func monthsBetweenPeriodsKeepFullWage() {
        let projection = simulator.project(
            guardians: [IncomeGuardian(id: "mom", monthlyOrdinaryWage: 3_000_000)],
            periods: [
                period("a", "mom", .parental, day(2026, 1, 1), day(2026, 1, 31)),
                period("b", "mom", .parental, day(2026, 3, 1), day(2026, 3, 31)),
            ]
        )
        #expect(projection.months.count == 3)
        #expect(monthly(projection, "mom", month: 1) == 3_000_000)   // 2월은 근무
    }

    @Test func sixPlusSixUsesMonthlyCapsThenFallsBack() {
        let projection = simulator.project(
            guardians: [IncomeGuardian(id: "mom", monthlyOrdinaryWage: 3_000_000)],
            periods: [period("a", "mom", .parentalSixPlusSix, day(2026, 1, 1), day(2026, 7, 31))]
        )
        #expect(monthly(projection, "mom", month: 0) == 2_500_000)   // 1개월차 상한 250만
        #expect(monthly(projection, "mom", month: 1) == 2_500_000)
        // 7월: 특례 6개월(183일) 마지막 2일은 월 300만(통상임금 100%), 이후 29일은 일반 육아휴직급여 150만
        let july = (2 * 3_000_000.0 + 29 * 1_500_000.0) / 31
        #expect(abs(Double(monthly(projection, "mom", month: 6)) - july) <= 1)
    }

    @Test func maternityAndPaternityPayOrdinaryWage() {
        let projection = simulator.project(
            guardians: [
                IncomeGuardian(id: "mom", monthlyOrdinaryWage: 3_000_000),
                IncomeGuardian(id: "dad", monthlyOrdinaryWage: 4_000_000),
            ],
            periods: [
                period("m", "mom", .maternity, day(2026, 6, 1), day(2026, 6, 30)),
                period("p", "dad", .paternity, day(2026, 6, 1), day(2026, 6, 30)),
            ]
        )
        #expect(monthly(projection, "mom", month: 0) == 3_000_000)
        #expect(monthly(projection, "dad", month: 0) == 4_000_000)
        #expect(projection.shortfall == 0)
    }

    @Test func reducedHoursAddsSupportForReducedPart() {
        let projection = simulator.project(
            guardians: [IncomeGuardian(id: "mom", monthlyOrdinaryWage: 4_000_000)],
            periods: [period("a", "mom", .reducedHours, day(2027, 1, 1), day(2027, 1, 31), hours: 30)]
        )
        // 근로 75% = 300만 + 지원 min(150만, 400만 × 25% × 80% = 80만) = 380만
        #expect(monthly(projection, "mom", month: 0) == 3_800_000)
    }

    @Test func familyCareIsUnpaidAndAnnualIsPaid() {
        let projection = simulator.project(
            guardians: [IncomeGuardian(id: "mom", monthlyOrdinaryWage: 3_100_000)],
            periods: [
                period("a", "mom", .familyCare, day(2026, 2, 1), day(2026, 2, 28)),
                period("b", "mom", .annual, day(2026, 3, 1), day(2026, 3, 31)),
            ]
        )
        #expect(monthly(projection, "mom", month: 0) == 0)
        #expect(monthly(projection, "mom", month: 1) == 3_100_000)
    }

    @Test func overlappingKindsUseHigherPriority() {
        // 같은 날 출산휴가와 연차가 겹치면 출산휴가로 계산(연차는 무시)
        let projection = simulator.project(
            guardians: [IncomeGuardian(id: "mom", monthlyOrdinaryWage: 3_000_000)],
            periods: [
                period("a", "mom", .annual, day(2026, 6, 1), day(2026, 6, 30)),
                period("b", "mom", .familyCare, day(2026, 6, 1), day(2026, 6, 30)),
            ]
        )
        #expect(monthly(projection, "mom", month: 0) == 3_000_000)   // 연차(5) 가 가족돌봄(6) 보다 우선
    }

    @Test func twoParentScenarioComparison() {
        let guardians = [
            IncomeGuardian(id: "mom", monthlyOrdinaryWage: 3_000_000),
            IncomeGuardian(id: "dad", monthlyOrdinaryWage: 4_000_000),
        ]
        let momFirst = simulator.project(guardians: guardians, periods: [
            period("a", "mom", .parental, day(2026, 9, 1), day(2027, 2, 28)),
        ])
        let dadFirst = simulator.project(guardians: guardians, periods: [
            period("a", "dad", .parental, day(2026, 9, 1), day(2027, 2, 28)),
        ])
        // 엄마가 쉬면 월 150만 감소, 아빠가 쉬면 월 250만 감소 (상한 150만 적용)
        #expect(momFirst.shortfall == 6 * 1_500_000)
        #expect(dadFirst.shortfall == 6 * 2_500_000)
        #expect(momFirst.total > dadFirst.total)
    }

    @Test func noPeriodsProducesEmptyProjection() {
        let projection = simulator.project(guardians: [IncomeGuardian(id: "mom", monthlyOrdinaryWage: 3_000_000)], periods: [])
        #expect(projection.months.isEmpty)
        #expect(projection.total == 0)
        #expect(projection.shortfall == 0)
    }

    @Test func invalidPeriodsAreIgnored() {
        let projection = simulator.project(
            guardians: [IncomeGuardian(id: "mom", monthlyOrdinaryWage: 3_000_000)],
            periods: [period("a", "mom", .parental, day(2026, 5, 31), day(2026, 5, 1))]
        )
        #expect(projection.months.isEmpty)
    }
}
