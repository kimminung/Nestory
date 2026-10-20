import Foundation
import NestoryKit
import SwiftData
import Testing
@testable import NestoryData

@MainActor
struct PrenatalPlanSyncTests {
    private let calendar = Calendar.korea

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d))!
    }

    @MainActor private struct Fixture {
        let container: ModelContainer
        let family: Family
        let child: Child
        let schedule: ScheduleRuleSet
        let checklist: ChecklistTemplate
        var context: ModelContext { container.mainContext }
    }

    private func makeFixture(due: Date) throws -> Fixture {
        let container = try NestoryModelContainer.make(inMemory: true)
        let family = Family(name: "우리집")
        let child = Child(nickname: "콩이")
        child.pregnancy = Pregnancy(dueDate: due, method: .direct)
        family.children = [child]
        container.mainContext.insert(family)
        try container.mainContext.save()
        return Fixture(
            container: container, family: family, child: child,
            schedule: try ScheduleRuleSet.bundledPrenatal(), checklist: try ChecklistTemplate.bundledPrenatal()
        )
    }

    private func sync(_ f: Fixture) throws -> PrenatalSyncResult {
        try PrenatalPlanSync.sync(child: f.child, schedule: f.schedule, checklist: f.checklist, context: f.context)
    }

    @Test func firstSyncCreatesCheckupsTasksAndChecklist() throws {
        let f = try makeFixture(due: date(2026, 10, 8))
        let result = try sync(f)

        let checkupRules = f.schedule.rules.filter { $0.category == .prenatalCheckup }.count
        let otherRules = f.schedule.rules.count - checkupRules
        let checklistItems = f.checklist.groups.reduce(0) { $0 + $1.items.count }

        #expect(f.child.pregnancy?.checkups?.count == checkupRules)
        #expect(f.family.tasks?.count == otherRules + checklistItems)
        #expect(result.created == checkupRules + otherRules + checklistItems)
        #expect(result.updated == 0 && result.removed == 0)
    }

    @Test func syncIsIdempotent() throws {
        let f = try makeFixture(due: date(2026, 10, 8))
        _ = try sync(f)
        let counts = (f.family.tasks?.count, f.child.pregnancy?.checkups?.count)

        let second = try sync(f)
        #expect(second == PrenatalSyncResult())
        #expect(f.family.tasks?.count == counts.0)
        #expect(f.child.pregnancy?.checkups?.count == counts.1)
    }

    @Test func checkupDatesFollowRecommendedWeeks() throws {
        let f = try makeFixture(due: date(2026, 10, 8))
        _ = try sync(f)
        let first = try #require(f.child.pregnancy?.checkups?.first { $0.ruleID == "prenatal.firstScreening" })
        #expect(first.scheduledDate == date(2026, 3, 26))      // LMP(1/1) + 12주
        let bag = try #require(f.family.tasks?.first { $0.ruleID == "checklist.hospitalBag.1" })
        #expect(bag.due == date(2026, 9, 3))                    // 35주 = 예정일 − 5주
        #expect(bag.category == .preparation)
    }

    @Test func changingDueDateMovesOnlyUnfinishedItems() throws {
        let f = try makeFixture(due: date(2026, 10, 8))
        _ = try sync(f)

        let doneCheckup = try #require(f.child.pregnancy?.checkups?.first { $0.ruleID == "prenatal.firstScreening" })
        doneCheckup.doneDate = date(2026, 3, 27)
        let doneTask = try #require(f.family.tasks?.first { $0.ruleID == "checklist.hospitalBag.1" })
        doneTask.doneAt = date(2026, 8, 1)
        let doneTaskDue = doneTask.due

        f.child.pregnancy?.dueDate = date(2026, 10, 22)          // 2주 늦어짐
        let result = try sync(f)
        #expect(result.updated > 0)

        #expect(doneCheckup.scheduledDate == date(2026, 3, 26))  // 완료한 검진은 그대로
        #expect(doneTask.due == doneTaskDue)
        let moved = try #require(f.child.pregnancy?.checkups?.first { $0.ruleID == "prenatal.secondScreening" })
        #expect(moved.scheduledDate == date(2026, 5, 7))         // 새 LMP(1/15) + 16주
    }

    @Test func userItemsAndOtherFeaturesAreLeftAlone() throws {
        let f = try makeFixture(due: date(2026, 10, 8))
        let custom = TaskItem(title: "친정에 연락", category: .custom, due: date(2026, 6, 1))
        let vaccine = TaskItem(title: "BCG", category: .vaccination, due: date(2026, 10, 9))
        vaccine.ruleID = "vaccine.BCG.1"
        let stale = TaskItem(title: "없어진 항목", category: .preparation)
        stale.ruleID = "checklist.old.1"
        let staleDone = TaskItem(title: "없어졌지만 완료한 항목", category: .preparation)
        staleDone.ruleID = "checklist.old.2"
        staleDone.doneAt = date(2026, 5, 1)
        for task in [custom, vaccine, stale, staleDone] {
            f.context.insert(task)
            task.family = f.family
        }
        try f.context.save()

        let result = try sync(f)
        let titles = Set((f.family.tasks ?? []).map(\.title))
        #expect(titles.contains("친정에 연락"))
        #expect(titles.contains("BCG"))                          // 관리 대상이 아닌 접두사
        #expect(!titles.contains("없어진 항목"))                  // 규칙에서 사라진 미완료 자동 항목은 정리
        #expect(titles.contains("없어졌지만 완료한 항목"))          // 완료한 것은 기록 보존
        #expect(result.removed == 1)
    }

    @Test func birthDateMovesPostBirthItemsToActualBirth() throws {
        let f = try makeFixture(due: date(2026, 10, 8))
        _ = try sync(f)
        let before = try #require(f.family.tasks?.first { $0.ruleID == "birth.registration" })
        #expect(before.due == date(2026, 10, 15))                // 예정일 + 7일(추정)

        f.child.birthDate = date(2026, 10, 1)
        _ = try sync(f)
        #expect(before.due == date(2026, 10, 8))                 // 실제 출생일 + 7일
    }

    @Test func missingFamilyOrDueDateThrows() throws {
        let container = try NestoryModelContainer.make(inMemory: true)
        let orphan = Child(nickname: "고아")
        container.mainContext.insert(orphan)
        let schedule = try ScheduleRuleSet.bundledPrenatal()
        let checklist = try ChecklistTemplate.bundledPrenatal()
        #expect(throws: PrenatalSyncError.missingFamily) {
            try PrenatalPlanSync.sync(child: orphan, schedule: schedule, checklist: checklist, context: container.mainContext)
        }

        let family = Family(name: "예정일 없음")
        let child = Child(nickname: "콩이")
        family.children = [child]
        container.mainContext.insert(family)
        #expect(throws: PrenatalSyncError.missingDueDate) {
            try PrenatalPlanSync.sync(child: child, schedule: schedule, checklist: checklist, context: container.mainContext)
        }
    }

    @Test func syncCreatesPregnancyFromChildDueDate() throws {
        let container = try NestoryModelContainer.make(inMemory: true)
        let family = Family(name: "우리집")
        let child = Child(nickname: "콩이")
        child.dueDate = date(2026, 10, 8)
        family.children = [child]
        container.mainContext.insert(family)

        try PrenatalPlanSync.sync(
            child: child, schedule: try ScheduleRuleSet.bundledPrenatal(),
            checklist: try ChecklistTemplate.bundledPrenatal(), context: container.mainContext
        )
        #expect(child.pregnancy?.dueDate == date(2026, 10, 8))
        #expect((child.pregnancy?.checkups?.count ?? 0) > 0)
    }
}
