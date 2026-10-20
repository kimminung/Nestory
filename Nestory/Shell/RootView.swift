import NestoryData
import NestoryKit
import NestoryUI
import OSLog
import SwiftData
import SwiftUI

/// 아이 정보가 없으면 온보딩, 있으면 메인 셸
struct RootView: View {
    @Query private var children: [Child]

    var body: some View {
        if children.isEmpty {
            OnboardingView()
        } else {
            MainShellView()
        }
    }
}

/// 폼팩터에 따라 내비게이션을 바꾸는 앱 셸.
/// - compact(iPhone 세로 등): 하단 탭
/// - regular(iPad, Mac, visionOS 등): 사이드바 + 상세
struct MainShellView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.modelContext) private var modelContext
    @Environment(\.ruleCatalog) private var catalog
    @Query private var children: [Child]
    @Query(filter: #Predicate<TaskItem> { $0.doneAt == nil }) private var openTasks: [TaskItem]
    @Query(filter: #Predicate<Checkup> { $0.doneDate == nil }) private var openCheckups: [Checkup]
    @State private var selection: AppSection = .home

    private static let logger = Logger(subsystem: "com.kimminung.nestory", category: "shell")

    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                compactLayout
            } else {
                regularLayout
            }
        }
        .tint(NestoryColor.peachDeep)
        .task(id: planSignature) { syncPlan() }
        .task(id: notificationSignature) {
            await NotificationService.reschedule(events: notificationEvents)
        }
    }

    // MARK: - 일정 동기화·알림

    /// 앱을 열 때마다 규칙 변경(예정일·규칙 업데이트)을 일정에 반영한다. 멱등이라 여러 번 불러도 안전하다.
    private func syncPlan() {
        guard let child = children.first, let catalog else { return }
        do {
            if child.birthDate != nil {
                try PostnatalPlanSync.sync(
                    child: child, prenatal: catalog.prenatal, infantCheckups: catalog.infantCheckups, context: modelContext
                )
            } else if child.pregnancy != nil {
                try PrenatalPlanSync.sync(
                    child: child, schedule: catalog.prenatal, checklist: catalog.checklist, context: modelContext
                )
            }
        } catch {
            Self.logger.error("일정 동기화 실패: \(error.localizedDescription)")
        }
    }

    /// 예정일·출생일이 바뀌면 일정을 다시 맞추기 위한 지문
    private var planSignature: String {
        let child = children.first
        let due = child?.pregnancy?.dueDate ?? child?.dueDate
        let birth = child?.birthDate
        return "\(due?.timeIntervalSince1970 ?? 0)|\(birth?.timeIntervalSince1970 ?? 0)"
    }

    private var notificationEvents: [PlannableEvent] {
        let fromTasks = openTasks.compactMap { task -> PlannableEvent? in
            task.due.map { PlannableEvent(id: "task-\(task.id)", title: task.title, date: $0) }
        }
        let fromCheckups = openCheckups.compactMap { checkup -> PlannableEvent? in
            checkup.scheduledDate.map { PlannableEvent(id: "checkup-\(checkup.id)", title: checkup.title, date: $0) }
        }
        return fromTasks + fromCheckups + vaccineEvents
    }

    /// 아직 안 맞은 접종 중 앞으로 예정인 것
    private var vaccineEvents: [PlannableEvent] {
        guard let child = children.first, let birth = child.birthDate, let catalog else { return [] }
        let now = Date()
        return VaccineScheduler.schedule(
            birth: birth, rules: catalog.vaccines, records: VaccinationService.records(for: child), now: now
        )
        .filter { $0.status != .done && $0.scheduledDate >= Calendar.korea.startOfDay(for: now) }
        .map { PlannableEvent(id: "vaccine-\($0.id)", title: "\($0.name) \($0.doseNo)차 접종", date: $0.scheduledDate) }
    }

    /// 일정이 바뀔 때만 알림을 다시 예약하기 위한 지문
    private var notificationSignature: String {
        notificationEvents
            .sorted { $0.id < $1.id }
            .map { "\($0.id)@\(Int($0.date.timeIntervalSince1970))" }
            .joined(separator: ",")
    }

    // MARK: - 레이아웃

    private var compactLayout: some View {
        TabView(selection: $selection) {
            ForEach(AppSection.allCases) { section in
                Tab(section.title, systemImage: section.systemImage, value: section) {
                    NavigationStack {
                        SectionView(section: section)
                    }
                }
            }
        }
    }

    private var regularLayout: some View {
        NavigationSplitView {
            List(selection: sidebarSelection) {
                ForEach(AppSection.allCases) { section in
                    Label(section.title, systemImage: section.systemImage)
                        .tag(section)
                }
            }
            .navigationTitle("Nestory")
            #if os(macOS)
            .navigationSplitViewColumnWidth(min: 200, ideal: 220)
            #endif
        } detail: {
            NavigationStack {
                SectionView(section: selection)
            }
            .id(selection)
        }
    }

    /// List 의 선택은 옵셔널이지만 앱의 선택값은 항상 존재하므로 nil 은 무시한다.
    private var sidebarSelection: Binding<AppSection?> {
        Binding(
            get: { selection },
            set: { newValue in
                if let newValue { selection = newValue }
            }
        )
    }
}

#Preview("루트 — 임신 중") {
    RootView()
        .previewEnvironment()
}

#Preview("루트 — 처음 실행") {
    RootView()
        .modelContainer(PreviewSeed.emptyContainer())
        .environment(\.ruleCatalog, try? RuleCatalog.load())
}
