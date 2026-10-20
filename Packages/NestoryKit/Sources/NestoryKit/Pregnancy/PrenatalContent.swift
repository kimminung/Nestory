import Foundation

/// 주차별 아기 크기 비유 한 칸 (의학 정보가 아닌 흔히 쓰는 비유)
public struct WeekGuideEntry: Codable, Identifiable, Hashable, Sendable {
    public let week: Int
    public let comparison: String
    /// 스티커 에셋 이름 (D3 에셋 반입 후 사용)
    public let assetName: String

    public var id: Int { week }
}

public struct WeekGuideSet: Codable, Sendable {
    public let meta: RuleMeta
    public let entries: [WeekGuideEntry]

    public static func bundled() throws -> WeekGuideSet {
        try RuleLoader.loadBundled("pregnancy-weeks")
    }

    /// `week`주 이하 중 가장 가까운 항목. 첫 항목보다 이르면 nil.
    public func entry(forWeek week: Int) -> WeekGuideEntry? {
        entries.sorted { $0.week < $1.week }.last { $0.week <= week }
    }
}

public struct ChecklistItemTemplate: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
}

public struct ChecklistGroup: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let category: TaskCategory
    /// 이 주차까지 끝내면 좋다는 권장 주차
    public let dueWeek: Int?
    public let items: [ChecklistItemTemplate]
}

/// 출산 준비물·입원 가방 같은 일반 체크리스트 템플릿
public struct ChecklistTemplate: Codable, Sendable {
    public let meta: RuleMeta
    public let groups: [ChecklistGroup]

    public static func bundledPrenatal() throws -> ChecklistTemplate {
        try RuleLoader.loadBundled("checklist-prenatal")
    }

    public var allItemIDs: Set<String> {
        Set(groups.flatMap { $0.items.map(\.id) })
    }
}
