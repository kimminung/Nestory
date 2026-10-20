import Foundation
import NestoryKit
import SwiftData

public enum PrenatalSyncError: Error, Equatable {
    case missingFamily
    case missingDueDate
}

public struct PrenatalSyncResult: Equatable, Sendable {
    public var created = 0
    public var updated = 0
    public var removed = 0
}

/// 규칙(일정 규칙 + 체크리스트 템플릿)을 SwiftData 의 `Checkup`/`TaskItem` 으로 맞춰 준다.
///
/// - 멱등: 여러 번 호출해도 같은 결과(ruleID 로 찾아 갱신).
/// - 예정일이 바뀌면 *완료하지 않은* 항목의 날짜만 새 기준으로 옮긴다. 완료한 항목·사용자가 직접 만든 항목(ruleID 없음)은 건드리지 않는다.
/// - 이 동기화가 관리하는 ruleID 접두사(`prenatal.` `birth.` `checklist.`)만 정리한다 — 다른 기능의 항목은 보존.
public enum PrenatalPlanSync {
    public static let managedPrefixes = ["prenatal.", "birth.", "checklist."]

    @discardableResult
    public static func sync(
        child: Child,
        schedule: ScheduleRuleSet,
        checklist: ChecklistTemplate,
        context: ModelContext,
        calendar: Calendar = .korea
    ) throws -> PrenatalSyncResult {
        guard let family = child.family else { throw PrenatalSyncError.missingFamily }
        guard let due = child.pregnancy?.dueDate ?? child.dueDate else { throw PrenatalSyncError.missingDueDate }

        let pregnancy: Pregnancy
        if let existing = child.pregnancy {
            pregnancy = existing
        } else {
            pregnancy = Pregnancy(dueDate: due)
            context.insert(pregnancy)
            pregnancy.child = child
        }
        if pregnancy.dueDate == nil { pregnancy.dueDate = due }

        var result = PrenatalSyncResult()
        var activeRuleIDs = Set<String>()

        var checkups = Dictionary(
            (pregnancy.checkups ?? []).compactMap { checkup in checkup.ruleID.map { ($0, checkup) } },
            uniquingKeysWith: { first, _ in first }
        )
        var tasks = Dictionary(
            (family.tasks ?? []).compactMap { task in task.ruleID.map { ($0, task) } },
            uniquingKeysWith: { first, _ in first }
        )

        func upsertTask(ruleID: String, title: String, note: String, category: TaskCategory, due: Date?) {
            activeRuleIDs.insert(ruleID)
            if let task = tasks[ruleID] {
                var changed = false
                if task.title != title { task.title = title; changed = true }
                if task.note != note { task.note = note; changed = true }
                if task.doneAt == nil, task.due != due { task.due = due; changed = true }
                if changed { result.updated += 1 }
            } else {
                let task = TaskItem(title: title, category: category, due: due)
                task.note = note
                task.ruleID = ruleID
                context.insert(task)
                task.family = family
                tasks[ruleID] = task
                result.created += 1
            }
        }

        // 1) 일정 규칙: 검진은 Checkup, 나머지는 TaskItem
        let anchors = ScheduleAnchors(lmp: pregnancy.lmpDate, due: due, birth: child.birthDate, calendar: calendar)
        for item in ScheduleGenerator.generate(schedule.rules, anchors: anchors, calendar: calendar) {
            if item.category == .prenatalCheckup {
                activeRuleIDs.insert(item.ruleID)
                if let checkup = checkups[item.ruleID] {
                    var changed = false
                    if checkup.title != item.title { checkup.title = item.title; changed = true }
                    if checkup.doneDate == nil, checkup.scheduledDate != item.recommended {
                        checkup.scheduledDate = item.recommended
                        changed = true
                    }
                    if changed { result.updated += 1 }
                } else {
                    let checkup = Checkup(title: item.title, scheduledDate: item.recommended)
                    checkup.ruleID = item.ruleID
                    context.insert(checkup)
                    checkup.pregnancy = pregnancy
                    checkups[item.ruleID] = checkup
                    result.created += 1
                }
            } else {
                upsertTask(
                    ruleID: item.ruleID, title: item.title, note: item.note ?? "",
                    category: item.category, due: item.recommended
                )
            }
        }

        // 2) 체크리스트 템플릿
        for group in checklist.groups {
            let groupDue = group.dueWeek.map {
                PregnancyCalculator.date(atWeeks: $0, dueDate: due, calendar: calendar)
            }
            for item in group.items {
                upsertTask(ruleID: item.id, title: item.title, note: "", category: group.category, due: groupDue)
            }
        }

        // 3) 규칙에서 사라진 자동 항목 정리 (완료하지 않은 것만, 관리 대상 접두사만)
        func isManaged(_ ruleID: String) -> Bool { managedPrefixes.contains { ruleID.hasPrefix($0) } }
        for (ruleID, task) in tasks where isManaged(ruleID) && !activeRuleIDs.contains(ruleID) && task.doneAt == nil {
            context.delete(task)
            result.removed += 1
        }
        for (ruleID, checkup) in checkups where isManaged(ruleID) && !activeRuleIDs.contains(ruleID) && checkup.doneDate == nil {
            context.delete(checkup)
            result.removed += 1
        }

        try context.save()
        return result
    }
}
