import Foundation
import Testing
@testable import NestoryKit

struct PregnancyCalculatorTests {
    @Test func dueDateFromLMPIs280DaysLater() {
        #expect(PregnancyCalculator.dueDate(lastMenstrualPeriod: day(2026, 1, 1)) == day(2026, 10, 8))
        // 윤년을 건너는 경우도 일수 기준
        #expect(PregnancyCalculator.dueDate(lastMenstrualPeriod: day(2027, 6, 1)) == day(2028, 3, 7))
    }

    @Test func ultrasoundCorrectionUsesMeasuredAge() {
        // 3/1 초음파에서 12주 3일(87일) → 남은 193일
        let due = PregnancyCalculator.dueDate(
            ultrasoundDate: day(2026, 3, 1), measuredAge: GestationalAge(weeks: 12, days: 3)
        )
        #expect(due == day(2026, 9, 10))
    }

    @Test func ivfDueDateDependsOnEmbryoAge() {
        #expect(PregnancyCalculator.dueDate(ivfTransferDate: day(2026, 2, 1), embryoAgeDays: 5) == day(2026, 10, 20))
        #expect(PregnancyCalculator.dueDate(ivfTransferDate: day(2026, 2, 1), embryoAgeDays: 3) == day(2026, 10, 22))
    }

    @Test func lmpAndDueDateAreInverse() {
        let lmp = day(2026, 4, 17)
        let due = PregnancyCalculator.dueDate(lastMenstrualPeriod: lmp)
        #expect(PregnancyCalculator.lastMenstrualPeriod(fromDueDate: due) == lmp)
    }

    @Test(arguments: [
        (day(2026, 1, 1), 0, 0),    // LMP 당일 = 0주 0일
        (day(2026, 1, 7), 0, 6),
        (day(2026, 1, 8), 1, 0),
        (day(2026, 10, 7), 39, 6),
        (day(2026, 10, 8), 40, 0),  // 예정일
        (day(2026, 10, 22), 42, 0), // 만 42주
    ])
    func gestationalAgeBoundaries(date: Date, weeks: Int, days: Int) throws {
        let age = try #require(PregnancyCalculator.gestationalAge(on: date, dueDate: day(2026, 10, 8)))
        #expect(age.weeks == weeks)
        #expect(age.days == days)
    }

    @Test func beforeLMPHasNoGestationalAge() {
        #expect(PregnancyCalculator.gestationalAge(on: day(2025, 12, 31), dueDate: day(2026, 10, 8)) == nil)
    }

    @Test func daysUntilDueIsNegativeAfterDueDate() {
        let due = day(2026, 10, 8)
        #expect(PregnancyCalculator.daysUntilDue(from: day(2026, 10, 1), dueDate: due) == 7)
        #expect(PregnancyCalculator.daysUntilDue(from: due, dueDate: due) == 0)
        #expect(PregnancyCalculator.daysUntilDue(from: day(2026, 10, 10), dueDate: due) == -2)
    }

    @Test(arguments: [
        (0, 0, Trimester.first), (13, 6, .first),
        (14, 0, .second), (27, 6, .second),
        (28, 0, .third), (41, 0, .third),
    ])
    func trimesterBoundaries(weeks: Int, days: Int, expected: Trimester) {
        #expect(PregnancyCalculator.trimester(for: GestationalAge(weeks: weeks, days: days)) == expected)
    }

    @Test func dateAtWeekRoundTrips() throws {
        let due = day(2026, 10, 8)
        let date = PregnancyCalculator.date(atWeeks: 20, days: 3, dueDate: due)
        let age = try #require(PregnancyCalculator.gestationalAge(on: date, dueDate: due))
        #expect(age == GestationalAge(weeks: 20, days: 3))
    }

    @Test func gestationalAgeRejectsNegativeDays() {
        #expect(GestationalAge(totalDays: -1) == nil)
        #expect(GestationalAge(weeks: -3, days: 0).totalDays == 0)
    }
}

struct AgeFormatterTests {
    private let birth = day(2026, 1, 15)

    @Test func pregnancyLabels() {
        #expect(AgeFormatter.pregnancyLabel(GestationalAge(weeks: 20, days: 3)) == "20주 3일")
        #expect(AgeFormatter.pregnancyLabel(GestationalAge(weeks: 12)) == "12주")
    }

    @Test(arguments: [(137, "D-137"), (1, "D-1"), (0, "D-Day"), (-3, "D+3")])
    func dDayLabels(daysUntil: Int, expected: String) {
        #expect(AgeFormatter.dDayLabel(daysUntil: daysUntil) == expected)
    }

    @Test(arguments: [
        (day(2026, 1, 14), "출생 전"),
        (day(2026, 1, 15), "생후 1일"),          // 태어난 날 = 1일째
        (day(2026, 2, 14), "생후 31일"),         // 한 달이 되기 전날
        (day(2026, 2, 15), "만 1개월"),
        (day(2027, 1, 14), "만 11개월"),
        (day(2027, 1, 15), "만 12개월"),
        (day(2027, 12, 14), "만 22개월"),
        (day(2028, 1, 15), "만 2세"),
        (day(2028, 4, 15), "만 2세 3개월"),
    ])
    func infantLabels(date: Date, expected: String) {
        #expect(AgeFormatter.infantLabel(birth: birth, on: date) == expected)
    }

    @Test func hundredthDayCountsBirthDayAsFirst() {
        #expect(AgeFormatter.hundredthDay(birth: birth) == day(2026, 4, 24))
        #expect(AgeFormatter.firstBirthday(birth: birth) == day(2027, 1, 15))
    }
}
