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

extension PreviewSeed {
    /// 프리뷰의 "오늘"(2026-10-20 18:30)에 생후 약 3개월(7/20생)인 아이. 최근 8일치 기록·성장·접종·진행 중 수면 포함.
    static let bornNow = Calendar.korea.date(from: DateComponents(year: 2026, month: 10, day: 20, hour: 18, minute: 30))!

    static func bornContainer() -> ModelContainer {
        let container = emptyContainer()
        let context = container.mainContext
        let calendar = Calendar.korea
        func at(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
            calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
        }
        do {
            let birth = calendar.date(from: DateComponents(year: 2026, month: 7, day: 20))!
            let child = try FamilySetup.create(
                NewFamilyDraft(
                    guardianName: "민지", guardianRole: .mother, childNickname: "콩이",
                    state: .born(birthDate: birth, dueDate: birth)
                ),
                context: context
            )
            child.sex = .female
            for day in 13...20 {
                for (index, hour) in [1, 5, 9, 13, 17].enumerated() where at(day, hour) < bornNow {
                    if index % 2 == 0 {
                        try CareLogService.log(.formula, for: child, start: at(day, hour), amount: Double(110 + 10 * (day % 3)), unit: .milliliters, context: context)
                    } else {
                        try CareLogService.log(.breastFeeding, for: child, start: at(day, hour), end: at(day, hour, 15 + day % 5), amount: Double(15 + day % 5), unit: .minutes, detail: BreastSide.left.rawValue, context: context)
                    }
                }
                for hour in [3, 7, 11, 15] where at(day, hour) < bornNow {
                    try CareLogService.log(.diaper, for: child, start: at(day, hour), detail: (hour == 7 ? DiaperKind.both : .wet).rawValue, context: context)
                }
                try CareLogService.log(.sleep, for: child, start: at(day - 1, 21), end: at(day, 6), context: context)
                try CareLogService.log(.sleep, for: child, start: at(day, 12), end: at(day, 14), context: context)
            }
            // 지금 낮잠 중
            try CareLogService.startTimer(.sleep, for: child, at: at(20, 17, 40), context: context)

            for (offset, weight, height) in [(0, 3.3, 50.0), (30, 4.4, 54.5), (62, 5.6, 58.8), (92, 6.4, 61.9)] {
                let record = GrowthRecord(date: calendar.adding(days: offset, to: birth))
                record.weightKg = weight
                record.heightCm = height
                context.insert(record)
                record.child = child
            }
            try VaccinationService.complete(code: "BCG", doseNo: 1, on: birth, for: child, context: context)
            try VaccinationService.complete(code: "HepB", doseNo: 1, on: birth, for: child, context: context)
            try VaccinationService.complete(code: "HepB", doseNo: 2, on: calendar.adding(days: 31, to: birth), for: child, context: context)

            let catalog = try RuleCatalog.load()
            try PostnatalPlanSync.sync(child: child, prenatal: catalog.prenatal, infantCheckups: catalog.infantCheckups, context: context)
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

    /// 생후 3개월 아이가 들어 있는 저장소 + 규칙 + 고정된 "오늘"
    @MainActor
    func bornPreviewEnvironment() -> some View {
        modelContainer(PreviewSeed.bornContainer())
            .environment(\.ruleCatalog, try? RuleCatalog.load())
            .referenceDate(PreviewSeed.bornNow)
    }
}
#endif
