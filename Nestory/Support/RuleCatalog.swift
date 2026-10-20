import NestoryKit
import SwiftUI

/// 앱 시작 때 한 번 읽어 두는 번들 규칙 모음
struct RuleCatalog: Sendable {
    let prenatal: ScheduleRuleSet
    let checklist: ChecklistTemplate
    let weekGuide: WeekGuideSet
    let infantCheckups: ScheduleRuleSet
    let vaccines: VaccineRuleSet
    let growth: GrowthReference

    static func load() throws -> RuleCatalog {
        RuleCatalog(
            prenatal: try ScheduleRuleSet.bundledPrenatal(),
            checklist: try ChecklistTemplate.bundledPrenatal(),
            weekGuide: try WeekGuideSet.bundled(),
            infantCheckups: try ScheduleRuleSet.bundledInfantCheckups(),
            vaccines: try VaccineRuleSet.bundled(),
            growth: try GrowthReference.bundled()
        )
    }
}

extension EnvironmentValues {
    /// 규칙 모음. 앱 루트에서 주입한다(없으면 규칙이 필요한 화면은 안내만 보여 준다).
    @Entry var ruleCatalog: RuleCatalog?
    /// "지금" 을 고정하고 싶을 때(프리뷰·테스트). nil 이면 실제 현재 시각.
    @Entry var referenceDate: Date?
}

extension View {
    func referenceDate(_ date: Date?) -> some View {
        environment(\.referenceDate, date)
    }
}
