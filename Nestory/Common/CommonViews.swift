import NestoryData
import NestoryKit
import NestoryUI
import SwiftData
import SwiftUI

extension Date {
    /// "10월 8일"
    var shortKorean: String {
        formatted(
            Date.FormatStyle(
                date: .omitted, time: .omitted,
                locale: KoreanFormat.locale, calendar: .korea, timeZone: Calendar.korea.timeZone
            )
            .month().day()
        )
    }
}

/// 현재 아이를 찾아 content 에 넘긴다. 아이가 없으면 안내만 보여 준다.
struct WithActiveChild<Content: View>: View {
    @Query(sort: \Child.nickname) private var children: [Child]
    @ViewBuilder let content: (Child) -> Content

    var body: some View {
        if let child = children.first {
            content(child)
        } else {
            EmptyState(
                title: "아이 정보가 없어요",
                message: "처음 화면에서 아이 정보를 입력해 주세요.",
                systemImage: "teddybear.fill"
            )
        }
    }
}

/// 홈·일정 목록에 보여 줄 "아직 안 한 일" 한 줄 (할 일 또는 검진)
struct UpcomingItem: Identifiable {
    enum Source {
        case task(TaskItem)
        case checkup(Checkup)
    }

    let id: String
    let title: String
    let date: Date
    let category: TaskCategory
    let source: Source

    func complete(at date: Date) {
        switch source {
        case .task(let task): task.doneAt = date
        case .checkup(let checkup): checkup.doneDate = date
        }
    }

    /// 날짜가 있고 아직 안 끝낸 항목을 날짜 순으로
    static func collect(tasks: [TaskItem], checkups: [Checkup]) -> [UpcomingItem] {
        let fromTasks = tasks.compactMap { task -> UpcomingItem? in
            guard task.doneAt == nil, let due = task.due else { return nil }
            return UpcomingItem(
                id: "task-\(task.id)", title: task.title, date: due, category: task.category, source: .task(task)
            )
        }
        let fromCheckups = checkups.compactMap { checkup -> UpcomingItem? in
            guard checkup.doneDate == nil, let date = checkup.scheduledDate else { return nil }
            return UpcomingItem(
                id: "checkup-\(checkup.id)", title: checkup.title, date: date,
                category: .prenatalCheckup, source: .checkup(checkup)
            )
        }
        return (fromTasks + fromCheckups).sorted { ($0.date, $0.id) < ($1.date, $1.id) }
    }
}

/// 일정 상태(예정·가능·지남·완료) 배지. 색과 함께 아이콘·글자로 의미를 전달한다.
struct ScheduleStatusBadge: View {
    let status: ScheduleStatus

    private var content: (title: LocalizedStringKey, icon: String, color: NestoryColor) {
        switch status {
        case .upcoming: ("예정", "clock", .sky)
        case .open: ("지금 가능", "sparkles", .mint)
        case .overdue: ("지났어요", "exclamationmark.circle", .rose)
        case .done: ("완료", "checkmark.circle.fill", .butter)
        }
    }

    var body: some View {
        Label(content.title, systemImage: content.icon)
            .font(.nestory(.caption, weight: .semibold))
            .foregroundStyle(NestoryColor.onPastel)
            .padding(.horizontal, NestorySpacing.s)
            .padding(.vertical, NestorySpacing.xs)
            .background(content.color, in: Capsule())
    }
}

/// 완료 체크 버튼 (44pt 터치 영역)
struct CheckToggleButton: View {
    let isDone: Bool
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                .font(.nestory(.title2))
                .foregroundStyle(isDone ? NestoryColor.peachDeep : NestoryColor.cocoaSoft)
                .frame(minWidth: NestoryHitTarget.minimum, minHeight: NestoryHitTarget.minimum)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(isDone ? "완료" : "미완료")
    }
}

/// 규칙 모음이 없을 때 규칙이 필요한 화면이 보여 주는 안내
struct RulesUnavailableView: View {
    var body: some View {
        EmptyState(
            title: "규칙 데이터를 읽지 못했어요",
            message: "앱을 다시 실행해 주세요.",
            systemImage: "exclamationmark.triangle.fill"
        )
    }
}
