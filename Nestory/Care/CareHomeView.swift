import NestoryData
import NestoryKit
import NestoryUI
import OSLog
import SwiftData
import SwiftUI

/// 아이가 태어난 뒤의 홈: 월령, 진행 중 타이머, 마지막 기록, 빠른 기록, 오늘 요약, 다가오는 일정, 바로가기
struct CareHomeView: View {
    let child: Child

    @Environment(\.ruleCatalog) private var catalog
    @Environment(\.referenceDate) private var referenceDate
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<TaskItem> { $0.doneAt == nil }, sort: \TaskItem.due)
    private var openTasks: [TaskItem]
    @State private var quickLog: QuickLogKind?
    @State private var isNightMode = false

    private static let logger = Logger(subsystem: "com.kimminung.nestory", category: "care")

    var body: some View {
        // 마지막 기록 경과 시간이 흐르도록 30초마다 다시 그린다(프리뷰·테스트에서는 고정된 시각 사용).
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let now = referenceDate ?? context.date
            content(now: now)
        }
        .background(NestoryColor.cream)
        .navigationTitle(child.nickname.isEmpty ? "홈" : child.nickname)
        .sheet(item: $quickLog) { kind in
            QuickLogSheet(kind: kind, child: child, now: referenceDate ?? Date())
        }
        .nightCover(isPresented: $isNightMode) {
            NightFeedingView(child: child, now: referenceDate)
        }
    }

    private func content(now: Date) -> some View {
        let entries = (child.careLogs ?? []).map(\.entry)
        return ScrollView {
            VStack(spacing: NestorySpacing.l) {
                hero(now: now)
                timersCard(now: now)
                lastRecords(entries: entries, now: now)
                quickButtons
                todaySummary(entries: entries, now: now)
                upcomingSection(now: now)
                shortcuts
                Text("기록은 참고용이에요. 아이가 아프거나 걱정되면 병원에 문의하세요.")
                    .font(.nestory(.caption))
                    .foregroundStyle(NestoryColor.cocoaSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(NestorySpacing.l)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - 히어로

    @ViewBuilder
    private func hero(now: Date) -> some View {
        if let birth = child.birthDate {
            NestoryCard(fill: .peach, contentColor: .onPastel) {
                Text(AgeFormatter.infantLabel(birth: birth, on: now))
                    .font(.nestory(.largeTitle, weight: .bold))
                if let milestone = nextMilestone(birth: birth, now: now) {
                    Text(milestone)
                        .font(.nestory(.title3, weight: .semibold))
                }
                Text("태어난 날 \(KoreanFormat.longDate(birth))")
                    .font(.nestory(.footnote))
            }
            .accessibilityElement(children: .combine)
        }
    }

    /// 가장 가까운 기념일(백일, 돌)까지 남은 일수
    private func nextMilestone(birth: Date, now: Date) -> String? {
        let today = Calendar.korea.startOfDay(for: now)
        let hundredth = AgeFormatter.hundredthDay(birth: birth)
        if today <= hundredth {
            return "백일까지 \(AgeFormatter.dDayLabel(daysUntil: Calendar.korea.daysBetween(today, hundredth)))"
        }
        let first = AgeFormatter.firstBirthday(birth: birth)
        if today <= first {
            return "돌까지 \(AgeFormatter.dDayLabel(daysUntil: Calendar.korea.daysBetween(today, first)))"
        }
        return nil
    }

    // MARK: - 진행 중 타이머

    @ViewBuilder
    private func timersCard(now: Date) -> some View {
        let timers = CareLogService.activeTimers(for: child)
        if !timers.isEmpty {
            VStack(spacing: NestorySpacing.s) {
                ForEach(timers) { log in
                    let style = CategoryStyle.style(for: log.type)
                    NestoryCard(fill: style.color, contentColor: .onPastel) {
                        HStack {
                            Label(log.type == .sleep ? "자는 중" : "모유 수유 중", systemImage: style.systemImage)
                                .font(.nestory(.headline))
                            Spacer()
                            Text(timerInterval: log.start...Date.distantFuture, pauseTime: nil, countsDown: false, showsHours: true)
                                .font(.nestory(.title3, weight: .bold))
                                .monospacedDigit()
                        }
                        Button(log.type == .sleep ? "일어났어요" : "수유 끝") { stop(log, now: now) }
                            .buttonStyle(.nestoryPrimary)
                    }
                }
            }
        }
    }

    private func stop(_ log: CareLog, now: Date) {
        do {
            try CareLogService.stopTimer(log, at: now, context: modelContext)
        } catch {
            Self.logger.error("타이머 종료 실패: \(error.localizedDescription)")
        }
    }

    // MARK: - 마지막 기록

    private func lastRecords(entries: [CareEntry], now: Date) -> some View {
        let feeding = CareAnalyzer.lastEntry(of: CareAnalyzer.feedingTypes, in: entries, now: now)
        let diaper = CareAnalyzer.lastEntry(of: [.diaper], in: entries, now: now)
        let sleep = CareAnalyzer.lastEntry(of: [.sleep], in: entries, now: now)

        func ago(_ entry: CareEntry?, useEnd: Bool = false) -> String {
            guard let entry else { return "기록 없음" }
            if useEnd {
                guard let end = entry.end else { return "자는 중" }
                return DurationFormatter.agoLabel(now.timeIntervalSince(end))
            }
            return DurationFormatter.agoLabel(now.timeIntervalSince(entry.start))
        }

        return HStack(spacing: NestorySpacing.s) {
            LastRecordTile(title: "마지막 수유", value: ago(feeding), systemImage: "drop.fill", tint: .mint)
            LastRecordTile(title: "마지막 낮·밤잠", value: ago(sleep, useEnd: true), systemImage: "moon.zzz.fill", tint: .lavender)
            LastRecordTile(title: "마지막 기저귀", value: ago(diaper), systemImage: "circle.hexagongrid.fill", tint: .sky)
        }
    }

    // MARK: - 빠른 기록

    private var quickButtons: some View {
        VStack(alignment: .leading, spacing: NestorySpacing.s) {
            SectionTitle("빠른 기록")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: NestorySpacing.s)], spacing: NestorySpacing.s) {
                ForEach(QuickLogKind.allCases) { kind in
                    QuickLogButton(kind.title, systemImage: kind.style.systemImage, tint: kind.style.color) {
                        quickLog = kind
                    }
                }
            }
        }
    }

    // MARK: - 오늘 요약

    private func todaySummary(entries: [CareEntry], now: Date) -> some View {
        let summary = CareAnalyzer.summary(entries, on: now, now: now)
        return VStack(alignment: .leading, spacing: NestorySpacing.s) {
            SectionTitle("오늘")
            NestoryCard {
                HStack(alignment: .top) {
                    SummaryMetric(title: "수유", value: "\(summary.feedingCount)회", detail: feedingDetail(summary))
                    SummaryMetric(title: "수면", value: DurationFormatter.spanLabel(minutes: summary.sleepMinutes), detail: "\(summary.sleepSessions)번")
                    SummaryMetric(title: "기저귀", value: "\(summary.diaperCount)회", detail: "소변 \(summary.wetDiapers) · 대변 \(summary.dirtyDiapers)")
                }
            }
        }
    }

    private func feedingDetail(_ summary: DailyCareSummary) -> String {
        var parts: [String] = []
        if summary.formulaMilliliters > 0 { parts.append("분유 \(Int(summary.formulaMilliliters.rounded()))ml") }
        if summary.breastMinutes > 0 { parts.append("모유 \(Int(summary.breastMinutes.rounded()))분") }
        return parts.isEmpty ? "-" : parts.joined(separator: " · ")
    }

    // MARK: - 다가오는 일정

    private func upcomingSection(now: Date) -> some View {
        let items = upcomingItems(now: now)
        return VStack(alignment: .leading, spacing: NestorySpacing.s) {
            SectionTitle("다가오는 일정")
            NestoryCard {
                if items.isEmpty {
                    Text("다가오는 일정이 없어요")
                        .font(.nestory(.body))
                        .foregroundStyle(NestoryColor.cocoaSoft)
                } else {
                    ForEach(items) { item in
                        HomeUpcomingRow(item: item, now: now)
                        if item.id != items.last?.id { Divider() }
                    }
                }
            }
        }
    }

    fileprivate struct HomeUpcoming: Identifiable {
        let id: String
        let title: String
        let date: Date
        let category: TaskCategory
        let status: ScheduleStatus
        let completion: (() -> Void)?
    }

    private func upcomingItems(now: Date) -> [HomeUpcoming] {
        var items: [HomeUpcoming] = []

        if let catalog, let birth = child.birthDate {
            let doses = VaccineScheduler.schedule(
                birth: birth, rules: catalog.vaccines, records: VaccinationService.records(for: child), now: now
            )
            let horizon = Calendar.korea.adding(days: 30, to: now)
            for dose in doses where dose.status == .overdue || dose.status == .open || (dose.status == .upcoming && dose.scheduledDate <= horizon) {
                items.append(
                    HomeUpcoming(
                        id: "vaccine-\(dose.id)", title: "\(dose.name) \(dose.doseNo)차 접종",
                        date: dose.scheduledDate, category: .vaccination,
                        status: dose.status == .overdue ? .overdue : (dose.status == .open ? .open : .upcoming),
                        completion: nil
                    )
                )
            }
        }

        let cutoff = Calendar.korea.adding(days: -7, to: now)
        for task in openTasks {
            guard let due = task.due, due >= cutoff, task.ruleID?.hasPrefix("checkup.") == true || task.ruleID?.hasPrefix("birth.") == true else { continue }
            items.append(
                HomeUpcoming(
                    id: "task-\(task.id)", title: task.title, date: due, category: task.category,
                    status: due < Calendar.korea.startOfDay(for: now) ? .overdue : .upcoming,
                    completion: { task.doneAt = now }
                )
            )
        }
        return Array(items.sorted { ($0.date, $0.id) < ($1.date, $1.id) }.prefix(5))
    }

    // MARK: - 바로가기

    private var shortcuts: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: NestorySpacing.m)], spacing: NestorySpacing.m) {
            CareShortcut("성장 기록", systemImage: "chart.line.uptrend.xyaxis", tint: .butter) { GrowthView(child: child) }
            CareShortcut("예방접종", systemImage: "syringe.fill", tint: .rose) { VaccinesView(child: child) }
            CareShortcut("영유아 검진", systemImage: "heart.text.square.fill", tint: .mint) { InfantCheckupsView(child: child) }
            Button {
                isNightMode = true
            } label: {
                CareShortcutLabel(title: "밤 수유 모드", systemImage: "moon.stars.fill", tint: .lavender)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - 부품

private struct LastRecordTile: View {
    let title: LocalizedStringKey
    let value: String
    let systemImage: String
    let tint: NestoryColor

    var body: some View {
        VStack(alignment: .leading, spacing: NestorySpacing.xs) {
            Image(systemName: systemImage)
                .foregroundStyle(NestoryColor.onPastel)
                .frame(width: 32, height: 32)
                .background(tint, in: Circle())
                .accessibilityHidden(true)
            Text(title).font(.nestory(.caption)).foregroundStyle(NestoryColor.cocoaSoft)
            Text(value).font(.nestory(.subheadline, weight: .bold)).foregroundStyle(NestoryColor.cocoa)
                .minimumScaleFactor(0.8)
        }
        .padding(NestorySpacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NestoryColor.card, in: RoundedRectangle(cornerRadius: NestoryRadius.card, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private struct SummaryMetric: View {
    let title: LocalizedStringKey
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.nestory(.caption)).foregroundStyle(NestoryColor.cocoaSoft)
            Text(value).font(.nestory(.title3, weight: .bold)).monospacedDigit()
            Text(detail).font(.nestory(.caption)).foregroundStyle(NestoryColor.cocoaSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct HomeUpcomingRow: View {
    let item: CareHomeView.HomeUpcoming
    let now: Date

    private var style: CategoryStyle { .style(for: item.category) }

    var body: some View {
        HStack(spacing: NestorySpacing.m) {
            Image(systemName: style.systemImage)
                .foregroundStyle(NestoryColor.onPastel)
                .frame(width: 36, height: 36)
                .background(style.color, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).font(.nestory(.body, weight: .semibold))
                Text(item.date.shortKorean).font(.nestory(.footnote)).foregroundStyle(NestoryColor.cocoaSoft)
            }
            Spacer(minLength: 0)
            ScheduleStatusBadge(status: item.status)
            if let completion = item.completion {
                CheckToggleButton(isDone: false, label: "\(item.title) 완료로 표시") {
                    withAnimation(.default, completion)
                }
            }
        }
        .foregroundStyle(NestoryColor.cocoa)
    }
}

struct CareShortcutLabel: View {
    let title: LocalizedStringKey
    let systemImage: String
    let tint: NestoryColor

    var body: some View {
        HStack(spacing: NestorySpacing.s) {
            Image(systemName: systemImage)
                .font(.nestory(.title3, weight: .semibold))
                .accessibilityHidden(true)
            Text(title)
                .font(.nestory(.subheadline, weight: .semibold))
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .foregroundStyle(NestoryColor.onPastel)
        .padding(NestorySpacing.m)
        .frame(maxWidth: .infinity, minHeight: NestoryHitTarget.quickLog, alignment: .leading)
        .background(tint, in: RoundedRectangle(cornerRadius: NestoryRadius.card, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: NestoryRadius.card, style: .continuous))
    }
}

struct CareShortcut<Destination: View>: View {
    let title: LocalizedStringKey
    let systemImage: String
    let tint: NestoryColor
    @ViewBuilder let destination: () -> Destination

    init(
        _ title: LocalizedStringKey, systemImage: String, tint: NestoryColor,
        @ViewBuilder destination: @escaping () -> Destination
    ) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self.destination = destination
    }

    var body: some View {
        NavigationLink {
            destination()
        } label: {
            CareShortcutLabel(title: title, systemImage: systemImage, tint: tint)
        }
        .buttonStyle(.plain)
    }
}

extension View {
    /// 밤 수유 모드를 전체 화면으로(macOS 는 전체 화면 커버가 없어 시트로)
    func nightCover<Content: View>(isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) -> some View {
        #if os(macOS)
        sheet(isPresented: isPresented, content: content)
        #else
        fullScreenCover(isPresented: isPresented, content: content)
        #endif
    }
}

#Preview("육아 홈") {
    NavigationStack {
        WithActiveChild { CareHomeView(child: $0) }
    }
    .bornPreviewEnvironment()
}
