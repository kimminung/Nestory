import Foundation
import NestoryKit
import SwiftData
import Testing
@testable import NestoryData

@MainActor
struct CareServicesTests {
    private let calendar = Calendar.korea

    private func date(_ y: Int, _ m: Int, _ d: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: hour, minute: minute))!
    }

    private func makeBornChild(birth: Date) throws -> (ModelContainer, Child) {
        let container = try NestoryModelContainer.make(inMemory: true)
        let child = try FamilySetup.create(
            NewFamilyDraft(childNickname: "하늘", state: .born(birthDate: birth)), context: container.mainContext
        )
        return (container, child)
    }

    // MARK: 기록·타이머

    @Test func logStoresAllFieldsAndConvertsToEntry() throws {
        let (container, child) = try makeBornChild(birth: date(2026, 10, 1))
        let log = try CareLogService.log(
            .formula, for: child, start: date(2026, 10, 20, 9), amount: 120, unit: .milliliters,
            detail: nil, note: "잘 먹음", context: container.mainContext
        )
        #expect(child.careLogs?.count == 1)
        #expect(log.entry == CareEntry(type: .formula, start: date(2026, 10, 20, 9), amount: 120, unit: .milliliters))
        #expect(log.note == "잘 먹음")
    }

    @Test func diaperDetailRoundTrips() throws {
        let (container, child) = try makeBornChild(birth: date(2026, 10, 1))
        let log = try CareLogService.log(
            .diaper, for: child, start: date(2026, 10, 20, 9),
            detail: DiaperKind.both.rawValue, context: container.mainContext
        )
        #expect(log.entry.detail == "both")
        let summary = CareAnalyzer.summary(
            (child.careLogs ?? []).map(\.entry), on: date(2026, 10, 20), now: date(2026, 10, 20, 12)
        )
        #expect(summary.wetDiapers == 1 && summary.dirtyDiapers == 1)
    }

    @Test func timerLifecycleForBreastFeeding() throws {
        let (container, child) = try makeBornChild(birth: date(2026, 10, 1))
        let context = container.mainContext
        let started = try CareLogService.startTimer(
            .breastFeeding, for: child, at: date(2026, 10, 20, 9), detail: BreastSide.left.rawValue, context: context
        )
        #expect(CareLogService.activeTimers(for: child).count == 1)

        // 이미 진행 중이면 새로 만들지 않는다
        let again = try CareLogService.startTimer(.breastFeeding, for: child, at: date(2026, 10, 20, 9, 5), context: context)
        #expect(again === started)
        #expect(child.careLogs?.count == 1)

        try CareLogService.stopTimer(started, at: date(2026, 10, 20, 9, 18), context: context)
        #expect(started.end == date(2026, 10, 20, 9, 18))
        #expect(started.amount == 18)
        #expect(started.unit == .minutes)
        #expect(CareLogService.activeTimers(for: child).isEmpty)

        // 이미 끝난 타이머를 다시 멈춰도 바뀌지 않는다
        try CareLogService.stopTimer(started, at: date(2026, 10, 20, 11), context: context)
        #expect(started.end == date(2026, 10, 20, 9, 18))
    }

    @Test func sleepAndFeedingTimersRunIndependently() throws {
        let (container, child) = try makeBornChild(birth: date(2026, 10, 1))
        let context = container.mainContext
        try CareLogService.startTimer(.sleep, for: child, at: date(2026, 10, 20, 21), context: context)
        try CareLogService.startTimer(.breastFeeding, for: child, at: date(2026, 10, 20, 22), context: context)
        #expect(CareLogService.activeTimers(for: child).map(\.type) == [.sleep, .breastFeeding])
    }

    @Test func stopBeforeStartIsClampedToStart() throws {
        let (container, child) = try makeBornChild(birth: date(2026, 10, 1))
        let log = try CareLogService.startTimer(.sleep, for: child, at: date(2026, 10, 20, 21), context: container.mainContext)
        try CareLogService.stopTimer(log, at: date(2026, 10, 20, 20), context: container.mainContext)
        #expect(log.end == date(2026, 10, 20, 21))
    }

    @Test func deleteRemovesLog() throws {
        let (container, child) = try makeBornChild(birth: date(2026, 10, 1))
        let log = try CareLogService.log(.diaper, for: child, start: date(2026, 10, 20, 9), context: container.mainContext)
        try CareLogService.delete(log, context: container.mainContext)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<CareLog>()) == 0)
    }

    // MARK: 예방접종

    @Test func vaccinationCompleteUndoAndFeedScheduler() throws {
        let birth = date(2026, 1, 1)
        let (container, child) = try makeBornChild(birth: birth)
        let context = container.mainContext

        try VaccinationService.complete(code: "HepB", doseNo: 1, on: date(2026, 1, 1, 15), for: child, context: context)
        try VaccinationService.complete(code: "HepB", doseNo: 1, on: date(2026, 1, 2), place: "소아과", for: child, context: context)
        #expect(child.vaccinations?.count == 1)                    // 같은 차수는 갱신
        #expect(child.vaccinations?.first?.doneDate == date(2026, 1, 2))
        #expect(child.vaccinations?.first?.place == "소아과")

        let records = VaccinationService.records(for: child)
        #expect(records == [VaccineDoseRecord(code: "HepB", doseNo: 1, date: date(2026, 1, 2))])

        let doses = VaccineScheduler.schedule(
            birth: birth, rules: try VaccineRuleSet.bundled(), records: records, now: date(2026, 1, 3)
        )
        #expect(doses.first { $0.id == "HepB#1" }?.status == .done)

        try VaccinationService.undo(code: "HepB", doseNo: 1, for: child, context: context)
        #expect(VaccinationService.records(for: child).isEmpty)
    }

    // MARK: 출생 전환 · 출생 후 일정

    @Test func recordBirthMovesPregnantChildToBornMode() throws {
        let container = try NestoryModelContainer.make(inMemory: true)
        let context = container.mainContext
        let child = try FamilySetup.create(
            NewFamilyDraft(state: .pregnant(.direct(date(2026, 10, 8)))), context: context
        )
        let prenatal = try ScheduleRuleSet.bundledPrenatal()
        try PrenatalPlanSync.sync(
            child: child, schedule: prenatal, checklist: try ChecklistTemplate.bundledPrenatal(), context: context
        )
        let doneTask = try #require(child.family?.tasks?.first { $0.ruleID == "checklist.babyItems.1" })
        doneTask.doneAt = date(2026, 8, 1)
        let doneCheckup = try #require(child.pregnancy?.checkups?.first { $0.ruleID == "prenatal.firstScreening" })
        doneCheckup.doneDate = date(2026, 3, 27)

        try FamilySetup.recordBirth(on: date(2026, 10, 5, 14), for: child, context: context)
        #expect(child.birthDate == date(2026, 10, 5))

        let result = try PostnatalPlanSync.sync(
            child: child, prenatal: prenatal, infantCheckups: try ScheduleRuleSet.bundledInfantCheckups(), context: context
        )
        #expect(result.removed > 0)

        let ruleIDs = (child.family?.tasks ?? []).compactMap(\.ruleID)
        // 미완료 임신·준비물 항목은 정리, 완료한 것은 기록으로 남는다
        #expect(ruleIDs.filter { $0.hasPrefix("prenatal.") }.isEmpty)
        #expect(ruleIDs.filter { $0.hasPrefix("checklist.") } == ["checklist.babyItems.1"])
        #expect(child.pregnancy?.checkups?.map(\.ruleID) == ["prenatal.firstScreening"])
        // 출생 후 일정이 생긴다
        #expect(ruleIDs.contains("checkup.1"))
        #expect(ruleIDs.contains("birth.registration"))
    }

    @Test func postnatalDatesFollowActualBirthAndAreIdempotent() throws {
        let (container, child) = try makeBornChild(birth: date(2026, 10, 5))
        let context = container.mainContext
        let prenatal = try ScheduleRuleSet.bundledPrenatal()
        let checkups = try ScheduleRuleSet.bundledInfantCheckups()

        let first = try PostnatalPlanSync.sync(child: child, prenatal: prenatal, infantCheckups: checkups, context: context)
        #expect(first.created == 4 + 8)                   // birth.* 4개 + 영유아 검진 8회
        let second = try PostnatalPlanSync.sync(child: child, prenatal: prenatal, infantCheckups: checkups, context: context)
        #expect(second == PrenatalSyncResult())

        let tasks = child.family?.tasks ?? []
        #expect(tasks.first { $0.ruleID == "checkup.1" }?.due == date(2026, 10, 19))        // 생후 14일
        #expect(tasks.first { $0.ruleID == "checkup.1" }?.category == .healthCheckup)
        #expect(tasks.first { $0.ruleID == "birth.registration" }?.due == date(2026, 10, 12))

        // 출생일 정정 시 미완료 항목만 이동
        tasks.first { $0.ruleID == "checkup.1" }?.doneAt = date(2026, 10, 20)
        child.birthDate = date(2026, 10, 7)
        try PostnatalPlanSync.sync(child: child, prenatal: prenatal, infantCheckups: checkups, context: context)
        #expect(tasks.first { $0.ruleID == "checkup.1" }?.due == date(2026, 10, 19))        // 완료라 그대로
        #expect(tasks.first { $0.ruleID == "checkup.2" }?.due == date(2027, 2, 7))          // 4개월 = 새 출생일 기준
    }

    @Test func postnatalSyncNeedsBirthDateAndFamily() throws {
        let container = try NestoryModelContainer.make(inMemory: true)
        let child = try FamilySetup.create(
            NewFamilyDraft(state: .pregnant(.direct(date(2026, 10, 8)))), context: container.mainContext
        )
        #expect(throws: PostnatalSyncError.missingBirthDate) {
            try PostnatalPlanSync.sync(
                child: child, prenatal: try ScheduleRuleSet.bundledPrenatal(),
                infantCheckups: try ScheduleRuleSet.bundledInfantCheckups(), context: container.mainContext
            )
        }
    }
}
