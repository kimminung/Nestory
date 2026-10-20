import Foundation
import NestoryKit
import SwiftData

@Model
public final class Employment {
    public var id: UUID = UUID()
    public var typeRaw: String = EmploymentType.regular.rawValue
    public var hireDate: Date?
    /// 월 통상임금(원). 급여 시뮬레이션 입력값.
    public var monthlyOrdinaryWage: Int = 0
    public var insured: Bool = true
    public var companySizeNote: String?

    public var guardian: Guardian?

    public var type: EmploymentType {
        get { EmploymentType(rawValue: typeRaw) ?? .regular }
        set { typeRaw = newValue.rawValue }
    }

    public init(type: EmploymentType = .regular) {
        self.typeRaw = type.rawValue
    }
}

/// 부부 휴직 시나리오(예: 시나리오 A/B/C). 가족 단위로 두 보호자의 기간을 함께 담는다.
@Model
public final class LeavePlan {
    public var id: UUID = UUID()
    public var name: String = ""
    public var scenarioIndex: Int = 0
    public var createdAt: Date = Date()

    public var family: Family?
    @Relationship(deleteRule: .cascade, inverse: \LeavePeriod.plan)
    public var periods: [LeavePeriod]? = []

    public init(name: String = "", scenarioIndex: Int = 0) {
        self.name = name
        self.scenarioIndex = scenarioIndex
    }
}

@Model
public final class LeavePeriod {
    public var id: UUID = UUID()
    public var kindRaw: String = LeaveKind.parental.rawValue
    public var start: Date = Date()
    public var end: Date = Date()
    /// 육아기 근로시간 단축일 때 주당 근로시간
    public var partTimeHoursPerWeek: Double?

    public var plan: LeavePlan?
    public var guardian: Guardian?

    public var kind: LeaveKind {
        get { LeaveKind(rawValue: kindRaw) ?? .parental }
        set { kindRaw = newValue.rawValue }
    }

    public init(kind: LeaveKind = .parental, start: Date = Date(), end: Date = Date()) {
        self.kindRaw = kind.rawValue
        self.start = start
        self.end = end
    }
}

@Model
public final class SideJob {
    public var id: UUID = UUID()
    public var title: String = ""
    public var company: String?
    public var sourceURL: String?
    public var pay: Int = 0
    public var payUnitRaw: String = PayUnit.hourly.rawValue
    public var hoursPerWeek: Double?
    public var remote: Bool = false
    public var statusRaw: String = SideJobStatus.interested.rawValue
    public var memo: String = ""
    public var createdAt: Date = Date()

    public var guardian: Guardian?
    @Relationship(deleteRule: .cascade, inverse: \WorkShift.job)
    public var shifts: [WorkShift]? = []

    public var payUnit: PayUnit {
        get { PayUnit(rawValue: payUnitRaw) ?? .hourly }
        set { payUnitRaw = newValue.rawValue }
    }

    public var status: SideJobStatus {
        get { SideJobStatus(rawValue: statusRaw) ?? .interested }
        set { statusRaw = newValue.rawValue }
    }

    public init(title: String = "") {
        self.title = title
    }
}

@Model
public final class WorkShift {
    public var id: UUID = UUID()
    public var date: Date = Date()
    public var hours: Double = 0
    public var earned: Int = 0

    public var job: SideJob?

    public init(date: Date = Date(), hours: Double = 0, earned: Int = 0) {
        self.date = date
        self.hours = hours
        self.earned = earned
    }
}
