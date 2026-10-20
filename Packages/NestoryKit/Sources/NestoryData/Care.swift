import Foundation
import NestoryKit
import SwiftData

@Model
public final class CareLog {
    public var id: UUID = UUID()
    public var typeRaw: String = CareLogType.breastFeeding.rawValue
    public var start: Date = Date()
    public var end: Date?
    public var amount: Double?
    public var unitRaw: String?
    public var note: String = ""
    /// 기저귀 종류(DiaperKind)·모유 방향(BreastSide) 등 세부 값의 rawValue. 스키마 1.1 에서 추가.
    public var detailRaw: String?
    /// 기록한 보호자 (Guardian.id). 보호자가 삭제돼도 기록은 남긴다.
    public var loggedByGuardianID: UUID?

    public var child: Child?

    public var type: CareLogType {
        get { CareLogType(rawValue: typeRaw) ?? .breastFeeding }
        set { typeRaw = newValue.rawValue }
    }

    public var unit: CareUnit? {
        get { unitRaw.flatMap(CareUnit.init(rawValue:)) }
        set { unitRaw = newValue?.rawValue }
    }

    /// 계산용 순수 값으로 변환
    public var entry: CareEntry {
        CareEntry(type: type, start: start, end: end, amount: amount, unit: unit, detail: detailRaw)
    }

    public init(type: CareLogType = .breastFeeding, start: Date = Date()) {
        self.typeRaw = type.rawValue
        self.start = start
    }
}

@Model
public final class GrowthRecord {
    public var id: UUID = UUID()
    public var date: Date = Date()
    public var heightCm: Double?
    public var weightKg: Double?
    public var headCm: Double?

    public var child: Child?

    public init(date: Date = Date()) {
        self.date = date
    }
}

@Model
public final class Vaccination {
    public var id: UUID = UUID()
    /// 규칙 데이터의 백신 코드 (예: "BCG", "HepB")
    public var vaccineCode: String = ""
    public var doseNo: Int = 1
    public var dueDate: Date?
    public var doneDate: Date?
    public var place: String?

    public var child: Child?

    public init(vaccineCode: String = "", doseNo: Int = 1, dueDate: Date? = nil) {
        self.vaccineCode = vaccineCode
        self.doseNo = doseNo
        self.dueDate = dueDate
    }
}

@Model
public final class Milestone {
    public var id: UUID = UUID()
    public var title: String = ""
    public var date: Date = Date()
    public var note: String = ""
    /// 사진 보관 식별자(파일/PhotoKit). M3 에서 결정.
    public var photoAssetID: String?

    public var child: Child?

    public init(title: String = "", date: Date = Date()) {
        self.title = title
        self.date = date
    }
}
