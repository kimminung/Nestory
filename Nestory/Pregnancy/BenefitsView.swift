import NestoryData
import NestoryKit
import NestoryUI
import SwiftData
import SwiftUI

/// 제도·지원금 안내: 바우처·신청·행정·휴가 계획을 신청 가능 시기와 공식 링크로 보여 준다.
struct BenefitsView: View {
    var body: some View {
        WithActiveChild { child in
            BenefitsContent(child: child)
        }
        .navigationTitle("제도·휴직")
    }
}

private struct BenefitsContent: View {
    let child: Child

    @Environment(\.ruleCatalog) private var catalog
    @Environment(\.referenceDate) private var referenceDate
    @Query private var tasks: [TaskItem]

    private var now: Date { referenceDate ?? Date() }

    private static let categories: Set<TaskCategory> = [.voucher, .administration, .leave]

    private func items(catalog: RuleCatalog) -> [ScheduledItem] {
        guard let due = child.pregnancy?.dueDate ?? child.dueDate else { return [] }
        let rules = catalog.prenatal.rules.filter { Self.categories.contains($0.category) }
        return ScheduleGenerator.generate(
            rules,
            anchors: ScheduleAnchors(lmp: child.pregnancy?.lmpDate, due: due, birth: child.birthDate)
        )
    }

    var body: some View {
        if let catalog {
            let meta = catalog.prenatal.meta
            let task = Dictionary(
                tasks.compactMap { task in task.ruleID.map { ($0, task) } },
                uniquingKeysWith: { first, _ in first }
            )
            ScrollView {
                VStack(alignment: .leading, spacing: NestorySpacing.l) {
                    VStack(alignment: .leading, spacing: NestorySpacing.s) {
                        DisclaimerBanner(
                            effectiveDate: meta.effectiveFrom?.date(),
                            sourceName: meta.sourceName,
                            sourceURL: meta.sourceURL.flatMap(URL.init(string:))
                        )
                        if meta.status != .verified {
                            Label("아직 공식 출처로 확인하지 못한 안내예요. 신청 전에 꼭 공식 사이트에서 확인하세요.", systemImage: "exclamationmark.triangle.fill")
                                .font(.nestory(.footnote, weight: .semibold))
                                .foregroundStyle(NestoryColor.danger)
                        }
                    }

                    ForEach(items(catalog: catalog)) { item in
                        BenefitCard(item: item, task: task[item.ruleID], now: now)
                    }

                    NestoryCard(fill: .lavender, contentColor: .onPastel) {
                        Label("휴가·휴직 계획과 예상 소득 비교는 곧 열려요", systemImage: "briefcase.fill")
                            .font(.nestory(.headline))
                        Text("부부가 함께 휴직 시기를 정하고 월별 소득을 비교할 수 있게 준비하고 있어요.")
                            .font(.nestory(.subheadline))
                    }
                }
                .padding(NestorySpacing.l)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .background(NestoryColor.cream)
        } else {
            RulesUnavailableView()
        }
    }
}

private struct BenefitCard: View {
    let item: ScheduledItem
    let task: TaskItem?
    let now: Date

    private var isDone: Bool { task?.doneAt != nil }
    private var status: ScheduleStatus { item.status(now: now, isDone: isDone) }
    private var style: CategoryStyle { .style(for: item.category) }

    private var windowText: String {
        let range = "\(item.windowStart.shortKorean) ~ \(item.windowEnd.shortKorean)"
        return item.isEstimated ? "\(range) (예정일 기준 추정)" : range
    }

    var body: some View {
        NestoryCard {
            HStack(alignment: .top, spacing: NestorySpacing.s) {
                Image(systemName: style.systemImage)
                    .foregroundStyle(NestoryColor.onPastel)
                    .frame(width: 36, height: 36)
                    .background(style.color, in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: NestorySpacing.xs) {
                    Text(item.title)
                        .font(.nestory(.headline))
                        .strikethrough(isDone)
                    ScheduleStatusBadge(status: status)
                }
                Spacer(minLength: 0)
                if let task {
                    CheckToggleButton(isDone: isDone, label: "\(item.title) 완료") {
                        withAnimation { task.doneAt = isDone ? nil : now }
                    }
                }
            }
            Label("신청 가능 시기  \(windowText)", systemImage: "calendar")
                .font(.nestory(.subheadline))
            if let note = item.note {
                Text(note)
                    .font(.nestory(.footnote))
                    .foregroundStyle(NestoryColor.cocoaSoft)
            }
            if let link = item.link, let url = URL(string: link) {
                Link(destination: url) {
                    Label("공식 안내 보기", systemImage: "arrow.up.right.square")
                        .font(.nestory(.subheadline, weight: .semibold))
                }
                .foregroundStyle(NestoryColor.peachDeep)
                .frame(minHeight: NestoryHitTarget.minimum, alignment: .leading)
            }
        }
    }
}

#Preview("제도·지원금") {
    NavigationStack { BenefitsView() }
        .previewEnvironment()
}
