import NestoryData
import NestoryKit
import NestoryUI
import OSLog
import SwiftData
import SwiftUI

/// 임신 중 홈: 주차 히어로 + 이번 주 아기 크기 + 다가오는 일정 + 바로가기
struct PregnancyHomeView: View {
    let child: Child

    @Environment(\.ruleCatalog) private var catalog
    @Environment(\.referenceDate) private var referenceDate
    @Query(filter: #Predicate<TaskItem> { $0.doneAt == nil }, sort: \TaskItem.due)
    private var openTasks: [TaskItem]
    @State private var isEditingDueDate = false
    @State private var isRecordingBirth = false

    private var now: Date { referenceDate ?? Date() }
    private var dueDate: Date? { child.pregnancy?.dueDate ?? child.dueDate }
    private var summary: PregnancySummary? { dueDate.map { PregnancySummary.make(dueDate: $0, now: now) } }

    /// 최근 일주일 안에 놓친 것부터 앞으로의 일정 4개
    private var upcoming: [UpcomingItem] {
        let cutoff = Calendar.korea.adding(days: -7, to: now)
        let items = UpcomingItem.collect(tasks: openTasks, checkups: child.pregnancy?.checkups ?? [])
        return Array(items.filter { $0.date >= cutoff }.prefix(4))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: NestorySpacing.l) {
                hero
                weekCard
                upcomingSection
                shortcuts
                Text("일정은 참고용이에요. 담당 병원의 안내를 우선하세요.")
                    .font(.nestory(.caption))
                    .foregroundStyle(NestoryColor.cocoaSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(NestorySpacing.l)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(NestoryColor.cream)
        .navigationTitle(child.nickname.isEmpty ? "홈" : child.nickname)
        .toolbar {
            ToolbarItem {
                Menu {
                    Button("아이가 태어났어요", systemImage: "heart.circle.fill") { isRecordingBirth = true }
                    Button("예정일 수정", systemImage: "calendar.badge.clock") { isEditingDueDate = true }
                } label: {
                    Label("더 보기", systemImage: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $isEditingDueDate) {
            DueDateEditorSheet(child: child, now: now)
        }
        .sheet(isPresented: $isRecordingBirth) {
            BirthSheet(child: child, now: now)
        }
    }

    // MARK: - 히어로

    @ViewBuilder
    private var hero: some View {
        if let summary {
            NestoryCard(fill: .peach, contentColor: .onPastel) {
                if let trimester = summary.trimester {
                    Text("임신 \(trimester.rawValue)분기")
                        .font(.nestory(.footnote, weight: .semibold))
                }
                Text(heroTitle(summary))
                    .font(.nestory(.largeTitle, weight: .bold))
                    .monospacedDigit()
                Text(heroSubtitle(summary))
                    .font(.nestory(.title3, weight: .semibold))
                PregnancyProgressBar(value: summary.progress)
                    .padding(.vertical, NestorySpacing.xs)
                Text("출산예정일 \(KoreanFormat.longDate(summary.dueDate))")
                    .font(.nestory(.footnote))
            }
            .accessibilityElement(children: .combine)
        }
    }

    private func heroTitle(_ summary: PregnancySummary) -> String {
        guard let age = summary.age else { return "임신 전이에요" }
        return "임신 \(AgeFormatter.pregnancyLabel(age))"
    }

    private func heroSubtitle(_ summary: PregnancySummary) -> String {
        summary.isPastDue
            ? "예정일이 \(-summary.daysUntilDue)일 지났어요"
            : "출산까지 \(AgeFormatter.dDayLabel(daysUntil: summary.daysUntilDue))"
    }

    // MARK: - 이번 주 아기

    @ViewBuilder
    private var weekCard: some View {
        if let age = summary?.age, let entry = catalog?.weekGuide.entry(forWeek: age.weeks) {
            NestoryCard {
                HStack(spacing: NestorySpacing.m) {
                    // 스티커 에셋(D3) 반입 전 임시 아이콘
                    Image(systemName: "sparkles")
                        .font(.nestory(.title2, weight: .semibold))
                        .foregroundStyle(NestoryColor.onPastel)
                        .frame(width: 56, height: 56)
                        .background(NestoryColor.butter, in: Circle())
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: NestorySpacing.xs) {
                        Text("\(entry.week)주쯤 아기는")
                            .font(.nestory(.footnote))
                            .foregroundStyle(NestoryColor.cocoaSoft)
                        Text("\(entry.comparison)만 해요")
                            .font(.nestory(.title3, weight: .bold))
                        Text("크기를 빗댄 말이에요. 아이마다 달라요.")
                            .font(.nestory(.caption))
                            .foregroundStyle(NestoryColor.cocoaSoft)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    // MARK: - 다가오는 일정

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: NestorySpacing.s) {
            Text("다가오는 일정")
                .font(.nestory(.headline))
                .foregroundStyle(NestoryColor.cocoa)
            NestoryCard {
                if upcoming.isEmpty {
                    Text("다가오는 일정이 없어요")
                        .font(.nestory(.body))
                        .foregroundStyle(NestoryColor.cocoaSoft)
                } else {
                    ForEach(upcoming) { item in
                        UpcomingRow(item: item, now: now)
                        if item.id != upcoming.last?.id { Divider() }
                    }
                }
            }
        }
    }

    // MARK: - 바로가기

    private var shortcuts: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: NestorySpacing.m)], spacing: NestorySpacing.m) {
            ShortcutLink("주차 타임라인", systemImage: "timeline.selection", tint: .lavender) {
                PregnancyTimelineView(child: child)
            }
            ShortcutLink("산전 검사", systemImage: "stethoscope", tint: .rose) {
                CheckupsView(child: child)
            }
            ShortcutLink("체크리스트", systemImage: "checklist", tint: .butter) {
                ChecklistView(child: child)
            }
            ShortcutLink("태동 카운터", systemImage: "hand.tap.fill", tint: .mint) {
                KickCounterView(child: child)
            }
            ShortcutLink("진통 타이머", systemImage: "timer", tint: .sky) {
                ContractionTimerView()
            }
        }
    }
}

// MARK: - 부품

private struct UpcomingRow: View {
    let item: UpcomingItem
    let now: Date

    private var style: CategoryStyle { .style(for: item.category) }
    private var isOverdue: Bool { Calendar.korea.startOfDay(for: item.date) < Calendar.korea.startOfDay(for: now) }

    var body: some View {
        HStack(spacing: NestorySpacing.m) {
            Image(systemName: style.systemImage)
                .foregroundStyle(NestoryColor.onPastel)
                .frame(width: 36, height: 36)
                .background(style.color, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.nestory(.body, weight: .semibold))
                Text(isOverdue ? "\(item.date.shortKorean) · 지났어요" : item.date.shortKorean)
                    .font(.nestory(.footnote))
                    .foregroundStyle(isOverdue ? NestoryColor.danger : NestoryColor.cocoaSoft)
            }
            Spacer(minLength: 0)
            CheckToggleButton(isDone: false, label: "\(item.title) 완료로 표시") {
                withAnimation { item.complete(at: now) }
            }
        }
    }
}

private struct ShortcutLink<Destination: View>: View {
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
        .buttonStyle(.plain)
    }
}

private struct PregnancyProgressBar: View {
    let value: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(NestoryColor.card.opacity(0.55))
                Capsule()
                    .fill(NestoryColor.onPastel)
                    .frame(width: max(8, geometry.size.width * value))
            }
        }
        .frame(height: 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("임신 진행률")
        .accessibilityValue("\(Int(value * 100))퍼센트")
    }
}

// MARK: - 예정일 수정

struct DueDateEditorSheet: View {
    let child: Child
    let now: Date

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.ruleCatalog) private var catalog
    @State private var form: DueDateFormState
    @State private var errorMessage: String?

    private static let logger = Logger(subsystem: "com.kimminung.nestory", category: "dueDate")

    init(child: Child, now: Date) {
        self.child = child
        self.now = now
        _form = State(initialValue: DueDateFormState(editing: child.pregnancy?.dueDate ?? child.dueDate ?? now, now: now))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: NestorySpacing.m) {
                    DueDateForm(state: form, now: now)
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.nestory(.footnote))
                            .foregroundStyle(NestoryColor.danger)
                    }
                    Text("예정일을 바꾸면 완료하지 않은 일정의 날짜가 새 기준으로 다시 계산돼요.")
                        .font(.nestory(.footnote))
                        .foregroundStyle(NestoryColor.cocoaSoft)
                }
                .padding(NestorySpacing.l)
            }
            .background(NestoryColor.cream)
            .navigationTitle("예정일 수정")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장", action: save).disabled(!form.issues(now: now).isEmpty)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 560)
        #endif
    }

    private func save() {
        do {
            try FamilySetup.updateDueDate(form.input(), for: child, context: modelContext)
            if let catalog {
                try PrenatalPlanSync.sync(
                    child: child, schedule: catalog.prenatal, checklist: catalog.checklist, context: modelContext
                )
            }
            dismiss()
        } catch {
            Self.logger.error("예정일 저장 실패: \(error.localizedDescription)")
            errorMessage = "저장하지 못했어요. 다시 시도해 주세요."
        }
    }
}

#Preview("임신 홈") {
    NavigationStack {
        WithActiveChild { PregnancyHomeView(child: $0) }
    }
    .previewEnvironment()
}
