import Foundation
import NestoryKit
import SwiftData
import Testing
@testable import NestoryData

@MainActor
struct SchemaTests {
    @Test func buildsInMemoryContainer() throws {
        let container = try NestoryModelContainer.make(inMemory: true)
        #expect(container.schema.entities.count == NestorySchemaV1.models.count)
    }

    @Test func cloudKitCompatibilityRules() {
        let schema = Schema(versionedSchema: NestorySchemaV1.self)
        for entity in schema.entities {
            #expect(entity.uniquenessConstraints.isEmpty, "\(entity.name): unique 제약 금지")
            for attribute in entity.attributes {
                #expect(
                    attribute.isOptional || attribute.defaultValue != nil,
                    "\(entity.name).\(attribute.name): 기본값 또는 옵셔널 필요"
                )
            }
            for relationship in entity.relationships {
                #expect(relationship.isOptional, "\(entity.name).\(relationship.name): 관계는 옵셔널")
                #expect(relationship.inverseName != nil, "\(entity.name).\(relationship.name): inverse 필요")
            }
        }
    }

    @Test func roundTripsFamilyGraph() throws {
        let container = try NestoryModelContainer.make(inMemory: true)
        let context = container.mainContext

        let family = Family(name: "우리집")
        let mom = Guardian(displayName: "엄마", role: .mother)
        let baby = Child(nickname: "콩이")
        family.guardians = [mom]
        family.children = [baby]

        let log = CareLog(type: .formula)
        log.amount = 120
        log.unit = .milliliters
        baby.careLogs = [log]
        context.insert(family)
        try context.save()

        let logs = try context.fetch(FetchDescriptor<CareLog>())
        #expect(logs.count == 1)
        #expect(logs.first?.type == .formula)
        #expect(logs.first?.unit == .milliliters)
        #expect(logs.first?.child?.nickname == "콩이")
        #expect(mom.role == .mother)
    }

    @Test func deletingFamilyCascades() throws {
        let container = try NestoryModelContainer.make(inMemory: true)
        let context = container.mainContext

        let family = Family(name: "삭제 테스트")
        let baby = Child(nickname: "콩이")
        let pregnancy = Pregnancy()
        pregnancy.checkups = [Checkup(title: "정밀 초음파")]
        baby.pregnancy = pregnancy
        baby.vaccinations = [Vaccination(vaccineCode: "BCG")]
        family.children = [baby]
        context.insert(family)
        try context.save()

        context.delete(family)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<Child>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Checkup>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Vaccination>()) == 0)
    }

    @Test func deletingGuardianKeepsLeavePeriods() throws {
        let container = try NestoryModelContainer.make(inMemory: true)
        let context = container.mainContext

        let family = Family(name: "휴직 테스트")
        let dad = Guardian(displayName: "아빠", role: .father)
        let plan = LeavePlan(name: "시나리오 A")
        let period = LeavePeriod(kind: .paternity)
        period.guardian = dad
        plan.periods = [period]
        family.guardians = [dad]
        family.leavePlans = [plan]
        context.insert(family)
        try context.save()

        context.delete(dad)
        try context.save()

        let periods = try context.fetch(FetchDescriptor<LeavePeriod>())
        #expect(periods.count == 1)
        #expect(periods.first?.guardian == nil)
    }
}
