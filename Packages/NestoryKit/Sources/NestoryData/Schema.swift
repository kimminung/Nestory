import Foundation
import SwiftData

/// 스키마 v1. 모델을 추가/변경할 때는 새 VersionedSchema 와 마이그레이션 단계를 만든다.
public enum NestorySchemaV1: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    public static var models: [any PersistentModel.Type] {
        [
            Family.self, Guardian.self, Child.self,
            Pregnancy.self, Checkup.self, KickSession.self,
            CareLog.self, GrowthRecord.self, Vaccination.self, Milestone.self,
            Employment.self, LeavePlan.self, LeavePeriod.self,
            SideJob.self, WorkShift.self,
            TaskItem.self, StoredDocument.self,
        ]
    }
}

public enum NestoryModelContainer {
    /// - Parameter inMemory: 테스트·프리뷰용
    /// CloudKit 동기화는 M7(가족 공유)에서 켠다. 지금은 로컬 전용.
    public static func make(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(versionedSchema: NestorySchemaV1.self)
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
