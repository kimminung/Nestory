import NestoryData
import NestoryKit
import NestoryUI
import SwiftUI

/// 주차 타임라인: 크기 비유가 바뀌는 주차마다 한 칸, 그 구간의 검진·할 일을 함께 보여 준다.
struct PregnancyTimelineView: View {
    let child: Child

    @Environment(\.ruleCatalog) private var catalog
    @Environment(\.referenceDate) private var referenceDate

    private var now: Date { referenceDate ?? Date() }

    private struct Phase {
        enum Kind { case past, current, future }
    }

    private struct Row: Identifiable {
        let week: Int
        let comparison: String
        let start: Date
        let end: Date
        let items: [ScheduledItem]
        let kind: Phase.Kind
        var id: Int { week }
    }

    private func rows(catalog: RuleCatalog, due: Date) -> [Row] {
        let entries = catalog.weekGuide.entries.sorted { $0.week < $1.week }
        let scheduled = ScheduleGenerator.generate(
            catalog.prenatal.rules.filter { $0.anchor == .lmp },
            anchors: ScheduleAnchors(lmp: child.pregnancy?.lmpDate, due: due)
        )
        let today = Calendar.korea.startOfDay(for: now)

        return entries.enumerated().map { index, entry in
            let start = PregnancyCalculator.date(atWeeks: entry.week, dueDate: due)
            let nextWeek = index + 1 < entries.count ? entries[index + 1].week : 43
            let end = PregnancyCalculator.date(atWeeks: nextWeek, dueDate: due)
            let items = scheduled.filter { $0.recommended >= start && $0.recommended < end }
            let kind: Phase.Kind = today >= end ? .past : (today >= start ? .current : .future)
            return Row(week: entry.week, comparison: entry.comparison, start: start, end: end, items: items, kind: kind)
        }
    }

    var body: some View {
        Group {
            if let catalog, let due = child.pregnancy?.dueDate ?? child.dueDate {
                timeline(rows: rows(catalog: catalog, due: due))
            } else {
                RulesUnavailableView()
            }
        }
        .background(NestoryColor.cream)
        .navigationTitle("주차 타임라인")
    }

    private func timeline(rows: [Row]) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: NestorySpacing.m) {
                    ForEach(rows) { row in
                        TimelineRow(row: row)
                            .id(row.week)
                    }
                }
                .padding(NestorySpacing.l)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .onAppear {
                if let current = rows.first(where: { $0.kind == .current }) {
                    proxy.scrollTo(current.week, anchor: .center)
                }
            }
        }
    }

    private struct TimelineRow: View {
        let row: Row

        private var marker: (icon: String, color: NestoryColor) {
            switch row.kind {
            case .past: ("checkmark.circle.fill", .cocoaSoft)
            case .current: ("circle.inset.filled", .peachDeep)
            case .future: ("circle", .cocoaSoft)
            }
        }

        var body: some View {
            HStack(alignment: .top, spacing: NestorySpacing.m) {
                Image(systemName: marker.icon)
                    .font(.nestory(.title3))
                    .foregroundStyle(marker.color)
                    .frame(width: 28)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: NestorySpacing.xs) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(row.week)주")
                            .font(.nestory(.headline, weight: .bold))
                        Text("\(row.comparison)만 해요")
                            .font(.nestory(.subheadline))
                            .foregroundStyle(NestoryColor.cocoaSoft)
                        Spacer(minLength: 0)
                        if row.kind == .current {
                            Text("지금")
                                .font(.nestory(.caption, weight: .bold))
                                .foregroundStyle(NestoryColor.onPastel)
                                .padding(.horizontal, NestorySpacing.s)
                                .padding(.vertical, 2)
                                .background(NestoryColor.peach, in: Capsule())
                        }
                    }
                    Text("\(row.start.shortKorean)부터")
                        .font(.nestory(.footnote))
                        .foregroundStyle(NestoryColor.cocoaSoft)
                    ForEach(row.items) { item in
                        Label(item.title, systemImage: CategoryStyle.style(for: item.category).systemImage)
                            .font(.nestory(.subheadline))
                    }
                }
            }
            .foregroundStyle(NestoryColor.cocoa)
            .padding(NestorySpacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                NestoryColor.card,
                in: RoundedRectangle(cornerRadius: NestoryRadius.card, style: .continuous)
            )
            .overlay {
                if row.kind == .current {
                    RoundedRectangle(cornerRadius: NestoryRadius.card, style: .continuous)
                        .strokeBorder(NestoryColor.peach, lineWidth: 2)
                }
            }
            .opacity(row.kind == .past ? 0.75 : 1)
            .accessibilityElement(children: .combine)
        }
    }
}

#Preview("주차 타임라인") {
    NavigationStack {
        WithActiveChild { PregnancyTimelineView(child: $0) }
    }
    .previewEnvironment()
}
