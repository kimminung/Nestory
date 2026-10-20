import Foundation
import Testing
@testable import NestoryKit

struct DueDateInputTests {
    private let now = day(2026, 5, 1)

    @Test func eachMethodComputesDueDate() {
        #expect(DueDateInput.lastMenstrualPeriod(day(2026, 1, 1)).dueDate() == day(2026, 10, 8))
        #expect(DueDateInput.ultrasound(scanDate: day(2026, 3, 1), measuredAge: GestationalAge(weeks: 12, days: 3)).dueDate() == day(2026, 9, 10))
        #expect(DueDateInput.ivfTransfer(date: day(2026, 2, 1), embryoAgeDays: 5).dueDate() == day(2026, 10, 20))
        #expect(DueDateInput.direct(day(2026, 10, 8)).dueDate() == day(2026, 10, 8))
    }

    @Test func methodMapsToStoredEnum() {
        #expect(DueDateInput.lastMenstrualPeriod(now).method == .lastMenstrualPeriod)
        #expect(DueDateInput.direct(now).method == .direct)
        #expect(DueDateInput.lastMenstrualPeriod(day(2026, 1, 1)).lastMenstrualPeriod == day(2026, 1, 1))
        #expect(DueDateInput.direct(now).lastMenstrualPeriod == nil)
    }

    @Test func futureStartDatesAreRejected() {
        #expect(DueDateInput.lastMenstrualPeriod(day(2026, 5, 2)).issues(now: now).contains(.dateInFuture))
        #expect(!DueDateInput.lastMenstrualPeriod(day(2026, 5, 1)).issues(now: now).contains(.dateInFuture))
        #expect(DueDateInput.ivfTransfer(date: day(2026, 6, 1), embryoAgeDays: 5).issues(now: now).contains(.dateInFuture))
    }

    @Test func dueDateRangeBoundaries() {
        // 예정일이 2주(14일) 넘게 지나면 오류, 정확히 14일은 허용
        #expect(DueDateInput.direct(day(2026, 4, 17)).issues(now: now).isEmpty)
        #expect(DueDateInput.direct(day(2026, 4, 16)).issues(now: now) == [.dueDateTooFarInPast])
        // 오늘부터 280일 뒤(2027-02-05)까지 허용
        #expect(DueDateInput.direct(day(2027, 2, 5)).issues(now: now).isEmpty)
        #expect(DueDateInput.direct(day(2027, 2, 6)).issues(now: now) == [.dueDateTooFarAhead])
    }

    @Test func measuredAgeAndEmbryoAgeLimits() {
        let scan = day(2026, 4, 1)
        #expect(DueDateInput.ultrasound(scanDate: scan, measuredAge: GestationalAge(weeks: 43)).issues(now: now).contains(.measuredAgeOutOfRange))
        #expect(!DueDateInput.ultrasound(scanDate: scan, measuredAge: GestationalAge(weeks: 12)).issues(now: now).contains(.measuredAgeOutOfRange))
        for age in [0, 8] {
            #expect(DueDateInput.ivfTransfer(date: scan, embryoAgeDays: age).issues(now: now).contains(.embryoAgeOutOfRange))
        }
        #expect(!DueDateInput.ivfTransfer(date: scan, embryoAgeDays: 5).issues(now: now).contains(.embryoAgeOutOfRange))
    }
}

struct PregnancySummaryTests {
    private let due = day(2026, 10, 8)

    @Test func summaryMidPregnancy() throws {
        let summary = PregnancySummary.make(dueDate: due, now: day(2026, 5, 20))   // LMP + 139일 = 19주 6일
        #expect(summary.age == GestationalAge(weeks: 19, days: 6))
        #expect(summary.daysUntilDue == 141)
        #expect(summary.trimester == .second)
        #expect(abs(summary.progress - 139.0 / 280) < 1e-9)
        #expect(!summary.isPastDue)
    }

    @Test func summaryAtAndAfterDueDate() {
        let atDue = PregnancySummary.make(dueDate: due, now: due)
        #expect(atDue.daysUntilDue == 0)
        #expect(atDue.progress == 1)
        #expect(!atDue.isPastDue)

        let late = PregnancySummary.make(dueDate: due, now: day(2026, 10, 12))
        #expect(late.daysUntilDue == -4)
        #expect(late.isPastDue)
        #expect(late.progress == 1)               // 진행률은 100% 에서 멈춘다
        #expect(late.age == GestationalAge(weeks: 40, days: 4))
    }

    @Test func summaryBeforeLMPHasNoAge() {
        let early = PregnancySummary.make(dueDate: due, now: day(2025, 12, 1))
        #expect(early.age == nil)
        #expect(early.trimester == nil)
        #expect(early.progress == 0)
    }
}

struct PrenatalContentTests {
    @Test func weekGuideFindsNearestLowerEntry() throws {
        let guide = try WeekGuideSet.bundled()
        #expect(guide.entry(forWeek: 3) == nil)
        #expect(guide.entry(forWeek: 4)?.week == 4)
        #expect(guide.entry(forWeek: 15)?.week == 14)   // 15주는 14주 항목
        #expect(guide.entry(forWeek: 16)?.comparison == "아보카도")
        #expect(guide.entry(forWeek: 42)?.week == 40)
    }

    @Test func weekGuideMatchesAssetBriefAndIsSorted() throws {
        let guide = try WeekGuideSet.bundled()
        #expect(guide.entries.count == 14)                       // BLENDER_ASSET_BRIEF 의 14종
        #expect(guide.entries.map(\.week) == guide.entries.map(\.week).sorted())
        #expect(Set(guide.entries.map(\.assetName)).count == guide.entries.count)
        for entry in guide.entries {
            #expect(entry.assetName.hasPrefix(String(format: "week_%02d_", entry.week)), "\(entry.assetName)")
        }
    }

    @Test func checklistTemplateIsWellFormed() throws {
        let checklist = try ChecklistTemplate.bundledPrenatal()
        #expect(!checklist.groups.isEmpty)
        let ids = checklist.groups.flatMap { $0.items.map(\.id) }
        #expect(Set(ids).count == ids.count, "항목 id 중복")
        #expect(checklist.allItemIDs.count == ids.count)
        for group in checklist.groups {
            #expect(!group.items.isEmpty, "\(group.id)")
            #expect(group.items.allSatisfy { $0.id.hasPrefix("checklist.\(group.id).") }, "\(group.id)")
            #expect((group.dueWeek ?? 0) <= 40, "\(group.id)")
        }
    }

    @Test func officialLinksAreHTTPSWhenPresent() throws {
        for rule in try ScheduleRuleSet.bundledPrenatal().rules {
            if let link = rule.link {
                #expect(URL(string: link)?.scheme == "https", "\(rule.id)")
            }
        }
    }

    @Test func scheduleItemsCarryRuleLinks() throws {
        let items = ScheduleGenerator.generate(
            try ScheduleRuleSet.bundledPrenatal().rules, anchors: ScheduleAnchors(lmp: day(2026, 1, 1))
        )
        #expect(items.first { $0.ruleID == "prenatal.voucher" }?.link != nil)
        #expect(items.first { $0.ruleID == "prenatal.firstScreening" }?.link == nil)
    }
}

struct BirthTrackingTests {
    private let t0 = kst.date(from: DateComponents(year: 2026, month: 10, day: 1, hour: 12))!

    private func record(minutesFrom start: Double, lasting seconds: Double) -> ContractionRecord {
        let s = t0.addingTimeInterval(start * 60)
        return ContractionRecord(start: s, end: s.addingTimeInterval(seconds))
    }

    @Test func summaryComputesStartToStartIntervals() {
        let records = [record(minutesFrom: 0, lasting: 50), record(minutesFrom: 6, lasting: 70), record(minutesFrom: 10, lasting: 60)]
        let summary = ContractionAnalyzer.summarize(records, now: t0.addingTimeInterval(11 * 60))
        #expect(summary.count == 3)
        #expect(summary.averageIntervalSeconds == 300)        // (360 + 240) / 2
        #expect(summary.averageDurationSeconds == 60)
    }

    @Test func summaryIgnoresRecordsOutsideWindow() {
        let records = [record(minutesFrom: -120, lasting: 60), record(minutesFrom: 0, lasting: 60)]
        let summary = ContractionAnalyzer.summarize(records, within: 3600, now: t0.addingTimeInterval(60))
        #expect(summary.count == 1)
        #expect(summary.averageIntervalSeconds == nil)         // 간격은 2회 이상이어야 계산
        #expect(ContractionAnalyzer.summarize([], now: t0).averageDurationSeconds == nil)
    }

    @Test func guidelineNeedsSustainedShortIntervalsAndLongContractions() {
        // 5분 간격, 1분 지속이 1시간 이상 이어진 경우
        let sustained = (0...12).map { record(minutesFrom: Double($0) * 5, lasting: 60) }
        let now = t0.addingTimeInterval(61 * 60)
        #expect(ContractionAnalyzer.meetsGuideline(sustained, now: now))

        // 40분만 이어졌다면 아직 아님
        let short = (0...8).map { record(minutesFrom: Double($0) * 5, lasting: 60) }
        #expect(!ContractionAnalyzer.meetsGuideline(short, now: t0.addingTimeInterval(41 * 60)))

        // 간격이 한 번이라도 5분(300초)을 넘으면 아님
        var gap = sustained
        gap[6] = record(minutesFrom: 31, lasting: 60)          // 25→31분 = 6분 간격
        #expect(!ContractionAnalyzer.meetsGuideline(gap, now: now))

        // 지속시간이 짧으면 아님
        let weak = (0...12).map { record(minutesFrom: Double($0) * 5, lasting: 30) }
        #expect(!ContractionAnalyzer.meetsGuideline(weak, now: now))
    }

    @Test func guidelineIsCustomizable() {
        let records = (0...6).map { record(minutesFrom: Double($0) * 10, lasting: 45) }
        let relaxed = ContractionGuideline(maxIntervalSeconds: 600, minAverageDurationSeconds: 40, sustainedSeconds: 3600)
        #expect(ContractionAnalyzer.meetsGuideline(records, guideline: relaxed, now: t0.addingTimeInterval(61 * 60)))
        #expect(!ContractionAnalyzer.meetsGuideline(records, now: t0.addingTimeInterval(61 * 60)))
        #expect(!ContractionAnalyzer.meetsGuideline([], now: t0))
    }

    @Test func kickSummaryRate() {
        let summary = KickCountSummary(count: 10, start: t0, end: t0.addingTimeInterval(1800))
        #expect(summary.perHour == 20)
        #expect(KickCountSummary(count: 3, start: t0, end: t0.addingTimeInterval(30)).perHour == nil)
        #expect(KickCountSummary(count: 1, start: t0, end: t0.addingTimeInterval(-5)).durationSeconds == 0)
    }
}
