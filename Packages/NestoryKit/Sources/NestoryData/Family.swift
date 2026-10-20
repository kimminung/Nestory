import Foundation
import NestoryKit
import SwiftData

// CloudKit 호환 규칙: 모든 속성은 기본값 또는 옵셔널, 관계는 옵셔널 + inverse, unique 제약 없음.

@Model
public final class Family {
    public var id: UUID = UUID()
    public var name: String = ""
    public var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \Guardian.family)
    public var guardians: [Guardian]? = []
    @Relationship(deleteRule: .cascade, inverse: \Child.family)
    public var children: [Child]? = []
    @Relationship(deleteRule: .cascade, inverse: \LeavePlan.family)
    public var leavePlans: [LeavePlan]? = []
    @Relationship(deleteRule: .cascade, inverse: \TaskItem.family)
    public var tasks: [TaskItem]? = []
    @Relationship(deleteRule: .cascade, inverse: \StoredDocument.family)
    public var documents: [StoredDocument]? = []

    public init(name: String = "") {
        self.name = name
    }
}

@Model
public final class Guardian {
    public var id: UUID = UUID()
    public var displayName: String = ""
    public var roleRaw: String = GuardianRole.other.rawValue
    /// 간트·일정에서 보호자를 구분하는 색 토큰 이름 (예: "peach", "sky")
    public var colorToken: String = "peach"

    public var family: Family?
    @Relationship(deleteRule: .cascade, inverse: \Employment.guardian)
    public var employment: Employment?
    @Relationship(deleteRule: .nullify, inverse: \LeavePeriod.guardian)
    public var leavePeriods: [LeavePeriod]? = []
    @Relationship(deleteRule: .cascade, inverse: \SideJob.guardian)
    public var sideJobs: [SideJob]? = []

    public var role: GuardianRole {
        get { GuardianRole(rawValue: roleRaw) ?? .other }
        set { roleRaw = newValue.rawValue }
    }

    public init(displayName: String = "", role: GuardianRole = .other) {
        self.displayName = displayName
        self.roleRaw = role.rawValue
    }
}

@Model
public final class Child {
    public var id: UUID = UUID()
    /// 태명 또는 애칭
    public var nickname: String = ""
    public var name: String?
    public var birthDate: Date?
    public var dueDate: Date?
    public var sexRaw: String = ChildSex.unknown.rawValue
    public var isMultiple: Bool = false
    public var avatarStickerID: String = ""

    public var family: Family?
    @Relationship(deleteRule: .cascade, inverse: \Pregnancy.child)
    public var pregnancy: Pregnancy?
    @Relationship(deleteRule: .cascade, inverse: \CareLog.child)
    public var careLogs: [CareLog]? = []
    @Relationship(deleteRule: .cascade, inverse: \GrowthRecord.child)
    public var growthRecords: [GrowthRecord]? = []
    @Relationship(deleteRule: .cascade, inverse: \Vaccination.child)
    public var vaccinations: [Vaccination]? = []
    @Relationship(deleteRule: .cascade, inverse: \Milestone.child)
    public var milestones: [Milestone]? = []

    public var sex: ChildSex {
        get { ChildSex(rawValue: sexRaw) ?? .unknown }
        set { sexRaw = newValue.rawValue }
    }

    public init(nickname: String = "") {
        self.nickname = nickname
    }
}

@Model
public final class Pregnancy {
    public var id: UUID = UUID()
    public var dueDate: Date?
    public var lmpDate: Date?
    public var methodRaw: String = DueDateMethod.lastMenstrualPeriod.rawValue
    public var notes: String = ""

    public var child: Child?
    @Relationship(deleteRule: .cascade, inverse: \Checkup.pregnancy)
    public var checkups: [Checkup]? = []
    @Relationship(deleteRule: .cascade, inverse: \KickSession.pregnancy)
    public var kickSessions: [KickSession]? = []

    public var method: DueDateMethod {
        get { DueDateMethod(rawValue: methodRaw) ?? .lastMenstrualPeriod }
        set { methodRaw = newValue.rawValue }
    }

    public init(dueDate: Date? = nil, method: DueDateMethod = .lastMenstrualPeriod) {
        self.dueDate = dueDate
        self.methodRaw = method.rawValue
    }
}

@Model
public final class Checkup {
    public var id: UUID = UUID()
    public var title: String = ""
    public var scheduledDate: Date?
    public var doneDate: Date?
    public var memo: String = ""
    /// 규칙 데이터에서 자동 생성된 경우 규칙 ID (사용자 항목은 nil)
    public var ruleID: String?

    public var pregnancy: Pregnancy?

    public init(title: String = "", scheduledDate: Date? = nil) {
        self.title = title
        self.scheduledDate = scheduledDate
    }
}

@Model
public final class KickSession {
    public var id: UUID = UUID()
    public var start: Date = Date()
    public var end: Date?
    public var count: Int = 0

    public var pregnancy: Pregnancy?

    public init(start: Date = Date()) {
        self.start = start
    }
}
