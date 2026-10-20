#if DEBUG
import Foundation
import NestoryData
import NestoryKit
import SwiftData
import SwiftUI

/// 프리뷰용 가짜 데이터. 기준 시각을 고정해 매번 같은 화면이 나오게 한다. (DEBUG 전용)
@MainActor
enum PreviewSeed {
    /// 프리뷰의 "오늘": 임신 19주 6일
    static let now = Calendar.korea.date(from: DateComponents(year: 2026, month: 5, day: 20))!
    static let dueDate = Calendar.korea.date(from: DateComponents(year: 2026, month: 10, day: 8))!

    static func emptyContainer() -> ModelContainer {
        // 프리뷰 전용: 실패하면 프리뷰가 실패로 보이는 편이 낫다
        // swiftlint:disable:next force_try
        try! NestoryModelContainer.make(inMemory: true)
    }

    /// 예정일 10월 8일, 일정 동기화 완료, 첫 번째 기형아 검사는 완료한 상태
    static func pregnantContainer() -> ModelContainer {
        let container = emptyContainer()
        let context = container.mainContext
        do {
            let child = try FamilySetup.create(
                NewFamilyDraft(
                    guardianName: "민지", guardianRole: .mother, childNickname: "콩이",
                    state: .pregnant(.lastMenstrualPeriod(Calendar.korea.date(from: DateComponents(year: 2026, month: 1, day: 1))!))
                ),
                context: context
            )
            let catalog = try RuleCatalog.load()
            try PrenatalPlanSync.sync(child: child, schedule: catalog.prenatal, checklist: catalog.checklist, context: context)
            child.pregnancy?.checkups?.first { $0.ruleID == "prenatal.firstScreening" }?.doneDate = now
            child.family?.tasks?.first { $0.ruleID == "checklist.babyItems.1" }?.doneAt = now
            try context.save()
        } catch {
            assertionFailure("프리뷰 데이터 생성 실패: \(error)")
        }
        return container
    }
}

extension View {
    /// 임신 중 가족이 들어 있는 저장소 + 규칙 + 고정된 "오늘"
    @MainActor
    func previewEnvironment() -> some View {
        modelContainer(PreviewSeed.pregnantContainer())
            .environment(\.ruleCatalog, try? RuleCatalog.load())
            .referenceDate(PreviewSeed.now)
    }
}
#endif
