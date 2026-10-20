import NestoryData
import NestoryKit
import NestoryUI
import SwiftData
import SwiftUI

/// 영유아 건강검진 8회: 권장 시기와 완료 체크
struct InfantCheckupsView: View {
    let child: Child

    @Environment(\.ruleCatalog) private var catalog
    @Environment(\.referenceDate) private var referenceDate
    @Query private var tasks: [TaskItem]

    private var now: Date { referenceDate ?? Date() }

    var body: some View {
        Group {
            if let catalog, let birth = child.birthDate {
                content(catalog: catalog, birth: birth)
            } else {
                RulesUnavailableView()
            }
        }
        .background(NestoryColor.cream)
        .navigationTitle("영유아 건강검진")
    }

    private func content(catalog: RuleCatalog, birth: Date) -> some View {
        let items = ScheduleGenerator.generate(catalog.infantCheckups.rules, anchors: ScheduleAnchors(birth: birth))
        let byRule = Dictionary(
            tasks.compactMap { task in task.ruleID.map { ($0, task) } }, uniquingKeysWith: { first, _ in first }
        )
        return ScrollView {
            VStack(alignment: .leading, spacing: NestorySpacing.m) {
                RuleMetaBanner(meta: catalog.infantCheckups.meta)
                NestoryCard {
                    ForEach(items) { item in
                        let task = byRule[item.ruleID]
                        let isDone = task?.doneAt != nil
                        HStack(alignment: .top, spacing: NestorySpacing.s) {
                            if let task {
                                CheckToggleButton(isDone: isDone, label: "\(item.title) 완료") {
                                    withAnimation { task.doneAt = isDone ? nil : now }
                                }
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(item.title)
                                        .font(.nestory(.body, weight: .semibold))
                                        .strikethrough(isDone)
                                    Spacer(minLength: 0)
                                    ScheduleStatusBadge(status: item.status(now: now, isDone: isDone))
                                }
                                Text("\(item.windowStart.shortKorean) ~ \(item.windowEnd.shortKorean)")
                                    .font(.nestory(.footnote))
                                    .foregroundStyle(NestoryColor.cocoaSoft)
                            }
                        }
                        .foregroundStyle(NestoryColor.cocoa)
                        if item.id != items.last?.id { Divider() }
                    }
                }
                Text("검진 시기와 대상은 변경될 수 있어요. 검진표와 병원 안내를 확인하세요.")
                    .font(.nestory(.footnote))
                    .foregroundStyle(NestoryColor.cocoaSoft)
            }
            .padding(NestorySpacing.l)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
    }
}

#Preview("영유아 검진") {
    NavigationStack {
        WithActiveChild { InfantCheckupsView(child: $0) }
    }
    .bornPreviewEnvironment()
}
