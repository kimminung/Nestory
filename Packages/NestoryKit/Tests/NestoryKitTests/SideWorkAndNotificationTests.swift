import Foundation
import Testing
@testable import NestoryKit

struct SideWorkGuardTests {
    private let leave = [period("a", "mom", .parental, day(2026, 3, 1), day(2026, 8, 31))]
    private let allChecked = Set(SideWorkPreCheckItem.allCases)

    private func codes(_ advisories: [SideWorkAdvisory]) -> [SideWorkAdvisoryCode] { advisories.map(\.code) }

    @Test func nothingToReportWhenPreCheckedAndNoShifts() {
        #expect(SideWorkGuard.evaluate(shifts: [], leavePeriods: leave, completedPreChecks: allChecked).isEmpty)
    }

    @Test func incompletePreCheckIsOnlyANotice() throws {
        let advisories = SideWorkGuard.evaluate(
            shifts: [], leavePeriods: leave, completedPreChecks: [.employerPolicy, .taxAndInsurance]
        )
        let notice = try #require(advisories.first)
        #expect(advisories.count == 1)
        #expect(notice.code == .preCheckIncomplete)
        #expect(notice.severity == .notice)
        #expect(Set(notice.missingItems) == [.benefitImpact, .childcareCoverage])
    }

    @Test func workingDuringParentalLeaveRaisesCautionAndConfirmation() throws {
        let shifts = [
            SideWorkShiftInput(date: day(2026, 4, 2), hours: 4, earned: 40_000),
            SideWorkShiftInput(date: day(2026, 4, 2), hours: 2, earned: 20_000),   // 같은 날은 1일로 센다
            SideWorkShiftInput(date: day(2026, 4, 9), hours: 4, earned: 40_000),
        ]
        let advisories = SideWorkGuard.evaluate(shifts: shifts, leavePeriods: leave, completedPreChecks: allChecked)
        #expect(codes(advisories) == [.workedDuringParentalLeave, .confirmWithEmploymentCenter])
        let worked = try #require(advisories.first)
        #expect(worked.severity == .caution)
        #expect(worked.value == 2)
        #expect(worked.periodStart == day(2026, 4, 2))
    }

    @Test func shiftsOutsideLeaveDoNotWarn() {
        let shifts = [SideWorkShiftInput(date: day(2026, 2, 27), hours: 4, earned: 40_000)]
        #expect(SideWorkGuard.evaluate(shifts: shifts, leavePeriods: leave, completedPreChecks: allChecked).isEmpty)
        // 육아휴직이 아닌 종류(연차 등)의 기간에는 이 경고를 내지 않는다
        let annual = [period("b", "mom", .annual, day(2026, 3, 1), day(2026, 3, 31))]
        let inAnnual = [SideWorkShiftInput(date: day(2026, 3, 10), hours: 4, earned: 40_000)]
        #expect(SideWorkGuard.evaluate(shifts: inAnnual, leavePeriods: annual, completedPreChecks: allChecked).isEmpty)
    }

    @Test func leaveBoundaryDaysAreInclusive() {
        let first = [SideWorkShiftInput(date: day(2026, 3, 1), hours: 1, earned: 0)]
        let last = [SideWorkShiftInput(date: day(2026, 8, 31), hours: 1, earned: 0)]
        let after = [SideWorkShiftInput(date: day(2026, 9, 1), hours: 1, earned: 0)]
        #expect(!SideWorkGuard.evaluate(shifts: first, leavePeriods: leave, completedPreChecks: allChecked).isEmpty)
        #expect(!SideWorkGuard.evaluate(shifts: last, leavePeriods: leave, completedPreChecks: allChecked).isEmpty)
        #expect(SideWorkGuard.evaluate(shifts: after, leavePeriods: leave, completedPreChecks: allChecked).isEmpty)
    }

    @Test func monthlyIncomeThresholdWarnsOnlyWhenExceeded() throws {
        let config = SideWorkGuardConfig(monthlyIncomeThreshold: 1_000_000)
        let atLimit = [SideWorkShiftInput(date: day(2026, 10, 5), hours: 40, earned: 1_000_000)]
        #expect(SideWorkGuard.evaluate(shifts: atLimit, leavePeriods: [], completedPreChecks: allChecked, config: config).isEmpty)

        let over = atLimit + [SideWorkShiftInput(date: day(2026, 10, 20), hours: 1, earned: 1)]
        let advisories = SideWorkGuard.evaluate(shifts: over, leavePeriods: [], completedPreChecks: allChecked, config: config)
        let first = try #require(advisories.first)
        #expect(first.code == .monthlyIncomeOverThreshold)
        #expect(first.value == 1_000_001)
        #expect(first.limit == 1_000_000)
        #expect(first.periodStart == day(2026, 10, 1))
        #expect(advisories.last?.code == .confirmWithEmploymentCenter)
    }

    @Test func weeklyHoursAreGroupedByWeek() throws {
        let config = SideWorkGuardConfig(weeklyHoursThreshold: 10)
        // 2026-03-02(월)·03-03(화)는 같은 주, 03-10 은 다음 주
        let shifts = [
            SideWorkShiftInput(date: day(2026, 3, 2), hours: 6, earned: 0),
            SideWorkShiftInput(date: day(2026, 3, 3), hours: 5, earned: 0),
            SideWorkShiftInput(date: day(2026, 3, 10), hours: 6, earned: 0),
        ]
        let advisories = SideWorkGuard.evaluate(shifts: shifts, leavePeriods: [], completedPreChecks: allChecked, config: config)
        let weekly = advisories.filter { $0.code == .weeklyHoursOverThreshold }
        #expect(weekly.count == 1)
        #expect(weekly.first?.value == 11)
    }

    @Test func confirmationIsAlwaysLastAndOnlyWithCaution() {
        let noticeOnly = SideWorkGuard.evaluate(shifts: [], leavePeriods: [], completedPreChecks: [])
        #expect(!codes(noticeOnly).contains(.confirmWithEmploymentCenter))

        let shifts = [SideWorkShiftInput(date: day(2026, 4, 2), hours: 4, earned: 0)]
        let withCaution = SideWorkGuard.evaluate(shifts: shifts, leavePeriods: leave, completedPreChecks: [])
        #expect(codes(withCaution).first == .preCheckIncomplete)
        #expect(codes(withCaution).last == .confirmWithEmploymentCenter)
    }
}

struct NotificationPlannerTests {
    private let event = PlannableEvent(id: "e1", title: "정밀 초음파", date: day(2026, 5, 20))
    private func at(_ month: Int, _ dayOfMonth: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        kst.date(from: DateComponents(year: 2026, month: month, day: dayOfMonth, hour: hour, minute: minute))!
    }

    @Test func defaultPlanNotifiesSevenDaysOneDayAndSameDay() {
        let plan = NotificationPlanner.plan(events: [event], now: at(5, 1, 8))
        #expect(plan.map(\.fireDate) == [at(5, 13, 9), at(5, 19, 9), at(5, 20, 9)])
        #expect(plan.map(\.leadDays) == [7, 1, 0])
        #expect(plan.map(\.id) == ["e1#7", "e1#1", "e1#0"])
        #expect(plan.map(\.title) == ["D-7", "내일 일정", "오늘 일정"])
        #expect(plan.allSatisfy { $0.body == "정밀 초음파" })
    }

    @Test func pastNotificationsAreDropped() {
        let plan = NotificationPlanner.plan(events: [event], now: at(5, 13, 9, 30))
        #expect(plan.map(\.leadDays) == [1, 0])
        // 정확히 발송 시각이면 이미 지난 것으로 본다
        let onTime = NotificationPlanner.plan(events: [event], now: at(5, 19, 9))
        #expect(onTime.map(\.leadDays) == [0])
    }

    @Test func quietHoursMoveDeliveryIntoAllowedWindow() {
        let late = NotificationConfig(leadDays: [0], deliveryHour: 23)
        #expect(NotificationPlanner.plan(events: [event], config: late, now: at(5, 1, 0)).first?.fireDate == at(5, 20, 21))
        let early = NotificationConfig(leadDays: [0], deliveryHour: 3)
        #expect(NotificationPlanner.plan(events: [event], config: early, now: at(5, 1, 0)).first?.fireDate == at(5, 20, 7))
        let boundary = NotificationConfig(leadDays: [0], deliveryHour: 22)
        #expect(NotificationPlanner.plan(events: [event], config: boundary, now: at(5, 1, 0)).first?.fireDate == at(5, 20, 21))
        let allowedEdge = NotificationConfig(leadDays: [0], deliveryHour: 7)
        #expect(NotificationPlanner.plan(events: [event], config: allowedEdge, now: at(5, 1, 0)).first?.fireDate == at(5, 20, 7))
    }

    @Test func pendingLimitKeepsEarliestNotifications() {
        let events = (0..<30).map { PlannableEvent(id: "e\($0)", title: "일정 \($0)", date: day(2026, 6, 1 + $0 % 28)) }
        let plan = NotificationPlanner.plan(events: events, now: at(5, 1, 0))
        #expect(plan.count == 64)
        #expect(plan.map(\.fireDate) == plan.map(\.fireDate).sorted())

        let limited = NotificationPlanner.plan(events: events, config: NotificationConfig(maxPending: 5), now: at(5, 1, 0))
        #expect(limited.count == 5)
        #expect(limited.map(\.fireDate) == Array(plan.map(\.fireDate).prefix(5)))
    }

    @Test func duplicateLeadDaysProduceOneNotification() {
        let config = NotificationConfig(leadDays: [1, 1, 0])
        #expect(NotificationPlanner.plan(events: [event], config: config, now: at(5, 1, 0)).count == 2)
    }

    @Test func customTextOverridesDefault() {
        let plan = NotificationPlanner.plan(events: [event], now: at(5, 1, 0)) { event, lead in
            ("\(event.title) \(lead)일 전", "병원 예약을 확인하세요")
        }
        #expect(plan.first?.title == "정밀 초음파 7일 전")
        #expect(plan.first?.body == "병원 예약을 확인하세요")
    }

    @Test func eventsInThePastProduceNothing() {
        #expect(NotificationPlanner.plan(events: [event], now: at(5, 21, 0)).isEmpty)
    }
}
