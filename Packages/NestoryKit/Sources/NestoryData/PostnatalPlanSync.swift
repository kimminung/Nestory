import Foundation
import NestoryKit
import SwiftData

/// 출생 후 일정(영유아 건강검진, 출생 후 행정)을 `TaskItem` 으로 맞춰 준다. `PrenatalPlanSync` 의 출생 후 짝.
///
/// - 출생일 기준으로 `birth.*` 행정 항목과 `checkup.*` 영유아 검진을 만든다(멱등, 완료한 항목은 날짜를 옮기지 않는다).
/// - 출산 전에 만들어 둔 *미완료* 임신 항목(`prenatal.*`·`checklist.*`, 임신 검진)은 더 이상 의미가 없어 정리한다. 완료한 것은 기록으로 남긴다.
public enum PostnatalPlanSync {
    public static let managedPrefixes = ["birth.", "checkup."]
    public static let obsoletePrenatalPrefixes = ["prenatal.", "checklist."]

    @discardableResult
    public static func sync(
        child: Child,
        prenatal: ScheduleRuleSet,
        infantCheckups: ScheduleRuleSet,
        context: ModelContext,
        calendar: Calendar = .korea
    ) throws -> PrenatalSyncResult {
        guard let family = child.family else { throw PrenatalSyncError.missingFamily }
        guard let birth = child.birthDate else { throw PostnatalSyncError.missingBirthDate }

        var result = PrenatalSyncResult()
        var activeRuleIDs = Set<String>()
        var tasks = Dictionary(
            (family.tasks ?? []).compactMap { task in task.ruleID.map { ($0, task) } },
            uniquingKeysWith: { first, _ in first }
        )

        let rules = prenatal.rules.filter { $0.anchor == .birth } + infantCheckups.rules
        let anchors = ScheduleAnchors(due: child.dueDate, birth: birth, calendar: calendar)
        for item in ScheduleGenerator.generate(rules, anchors: anchors, calendar: calendar) {
            activeRuleIDs.insert(item.ruleID)
            if let task = tasks[item.ruleID] {
                var changed = false
                if task.title != item.title { task.title = item.title; changed = true }
                if task.note != (item.note ?? "") { task.note = item.note ?? ""; changed = true }
                if task.doneAt == nil, task.due != item.recommended { task.due = item.recommended; changed = true }
                if changed { result.updated += 1 }
            } else {
                let task = TaskItem(title: item.title, category: item.category, due: item.recommended)
                task.note = item.note ?? ""
                task.ruleID = item.ruleID
                context.insert(task)
                task.family = family
                tasks[item.ruleID] = task
                result.created += 1
            }
        }

        // 이 동기화가 관리하는 항목 중 규칙에서 사라진 것, 출산 전용 미완료 항목 정리
        for (ruleID, task) in tasks where task.doneAt == nil {
            let stale = managedPrefixes.contains { ruleID.hasPrefix($0) } && !activeRuleIDs.contains(ruleID)
            let obsolete = obsoletePrenatalPrefixes.contains { ruleID.hasPrefix($0) }
            if stale || obsolete {
                context.delete(task)
                result.removed += 1
            }
        }
        for checkup in child.pregnancy?.checkups ?? []
        where checkup.doneDate == nil && (checkup.ruleID?.hasPrefix("prenatal.") ?? false) {
            context.delete(checkup)
            result.removed += 1
        }

        try context.save()
        return result
    }
}

public enum PostnatalSyncError: Error, Equatable {
    case missingBirthDate
}
