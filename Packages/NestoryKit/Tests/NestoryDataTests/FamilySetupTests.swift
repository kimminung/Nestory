import Foundation
import NestoryKit
import SwiftData
import Testing
@testable import NestoryData

@MainActor
struct FamilySetupTests {
    private let calendar = Calendar.korea

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d))!
    }

    @Test func pregnantFamilyIsCreatedWithPregnancyDetails() throws {
        let container = try NestoryModelContainer.make(inMemory: true)
        let draft = NewFamilyDraft(
            guardianName: "민지", guardianRole: .mother, childNickname: "콩이", isMultiple: true,
            state: .pregnant(.lastMenstrualPeriod(date(2026, 1, 1)))
        )
        let child = try FamilySetup.create(draft, context: container.mainContext)

        #expect(child.nickname == "콩이")
        #expect(child.isMultiple)
        #expect(child.dueDate == date(2026, 10, 8))
        #expect(child.pregnancy?.dueDate == date(2026, 10, 8))
        #expect(child.pregnancy?.lmpDate == date(2026, 1, 1))
        #expect(child.pregnancy?.method == .lastMenstrualPeriod)
        #expect(child.family?.name == "우리 가족")
        #expect(child.family?.guardians?.first?.displayName == "민지")
        #expect(child.family?.guardians?.first?.role == .mother)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<Family>()) == 1)
    }

    @Test func lmpIsDerivedFromDueDateWhenNotEntered() throws {
        let container = try NestoryModelContainer.make(inMemory: true)
        let draft = NewFamilyDraft(state: .pregnant(.direct(date(2026, 10, 8))))
        let child = try FamilySetup.create(draft, context: container.mainContext)
        #expect(child.pregnancy?.lmpDate == date(2026, 1, 1))
        #expect(child.pregnancy?.method == .direct)
    }

    @Test func blankNamesFallBackToFriendlyDefaults() throws {
        let container = try NestoryModelContainer.make(inMemory: true)
        let mother = try FamilySetup.create(
            NewFamilyDraft(guardianName: "  ", guardianRole: .mother, childNickname: "", state: .pregnant(.direct(date(2026, 10, 8)))),
            context: container.mainContext
        )
        #expect(mother.nickname == "우리 아기")
        #expect(mother.family?.guardians?.first?.displayName == "엄마")
        #expect(FamilySetup.defaultGuardianName(for: .father) == "아빠")
        #expect(FamilySetup.defaultGuardianName(for: .other) == "보호자")
    }

    @Test func bornChildHasBirthDateAndNoPregnancy() throws {
        let container = try NestoryModelContainer.make(inMemory: true)
        let draft = NewFamilyDraft(childNickname: "하늘", state: .born(birthDate: date(2026, 9, 1), dueDate: date(2026, 9, 10)))
        let child = try FamilySetup.create(draft, context: container.mainContext)
        #expect(child.birthDate == date(2026, 9, 1))
        #expect(child.dueDate == date(2026, 9, 10))
        #expect(child.pregnancy == nil)
    }

    @Test func updatingDueDateChangesChildAndPregnancy() throws {
        let container = try NestoryModelContainer.make(inMemory: true)
        let child = try FamilySetup.create(
            NewFamilyDraft(state: .pregnant(.lastMenstrualPeriod(date(2026, 1, 1)))), context: container.mainContext
        )
        try FamilySetup.updateDueDate(
            .ultrasound(scanDate: date(2026, 3, 1), measuredAge: GestationalAge(weeks: 12, days: 3)),
            for: child, context: container.mainContext
        )
        #expect(child.dueDate == date(2026, 9, 10))
        #expect(child.pregnancy?.dueDate == date(2026, 9, 10))
        #expect(child.pregnancy?.method == .ultrasound)
        #expect(child.pregnancy?.lmpDate == date(2025, 12, 4))      // 예정일 − 280일
    }

    @Test func updatingDueDateCreatesPregnancyIfMissing() throws {
        let container = try NestoryModelContainer.make(inMemory: true)
        let child = try FamilySetup.create(
            NewFamilyDraft(state: .born(birthDate: date(2026, 9, 1))), context: container.mainContext
        )
        try FamilySetup.updateDueDate(.direct(date(2026, 10, 8)), for: child, context: container.mainContext)
        #expect(child.pregnancy?.dueDate == date(2026, 10, 8))
    }
}
