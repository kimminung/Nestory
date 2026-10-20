import NestoryData
import NestoryKit
import NestoryUI
import SwiftData
import SwiftUI

/// 출산 준비물·입원 가방 등 체크리스트. 템플릿 항목은 완료만, 내가 추가한 항목은 길게 눌러(우클릭) 삭제할 수 있다.
/// (macOS 의 `List` 크래시를 피하려고 카드 스크롤로 만들었다. CheckupsView 참고)
struct ChecklistView: View {
    let child: Child

    @Environment(\.ruleCatalog) private var catalog
    @Environment(\.referenceDate) private var referenceDate
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskItem.title) private var tasks: [TaskItem]
    @State private var newTitle = ""

    private var now: Date { referenceDate ?? Date() }

    private var tasksByRuleID: [String: TaskItem] {
        Dictionary(tasks.compactMap { task in task.ruleID.map { ($0, task) } }, uniquingKeysWith: { first, _ in first })
    }

    /// 내가 직접 추가한 준비물: 안 한 것 먼저
    private var customTasks: [TaskItem] {
        tasks.filter { $0.ruleID == nil && $0.category == .preparation }
            .sorted { ($0.doneAt != nil ? 1 : 0, $0.title) < ($1.doneAt != nil ? 1 : 0, $1.title) }
    }

    var body: some View {
        Group {
            if let catalog {
                content(catalog: catalog)
            } else {
                RulesUnavailableView()
            }
        }
        .background(NestoryColor.cream)
        .navigationTitle("체크리스트")
    }

    private func content(catalog: RuleCatalog) -> some View {
        let byRule = tasksByRuleID
        return ScrollView {
            VStack(alignment: .leading, spacing: NestorySpacing.l) {
                ForEach(catalog.checklist.groups) { group in
                    let rows = group.items.compactMap { byRule[$0.id] }
                    if !rows.isEmpty {
                        ChecklistSection(
                            title: group.title,
                            done: rows.filter { $0.doneAt != nil }.count,
                            total: rows.count,
                            dueText: dueText(week: group.dueWeek)
                        ) {
                            ForEach(rows) { task in
                                TaskRow(task: task, now: now, onDelete: nil)
                                if task.id != rows.last?.id { Divider() }
                            }
                        }
                    }
                }

                ChecklistSection(
                    title: "내가 추가한 항목",
                    done: customTasks.filter { $0.doneAt != nil }.count,
                    total: customTasks.count,
                    dueText: nil
                ) {
                    ForEach(customTasks) { task in
                        TaskRow(task: task, now: now) { modelContext.delete(task) }
                        Divider()
                    }
                    HStack {
                        TextField("항목 추가", text: $newTitle)
                            .textFieldStyle(.plain)
                            .font(.nestory(.body))
                            .onSubmit(addItem)
                        Button("추가", systemImage: "plus.circle.fill", action: addItem)
                            .labelStyle(.iconOnly)
                            .font(.nestory(.title2))
                            .foregroundStyle(NestoryColor.peachDeep)
                            .buttonStyle(.plain)
                            .frame(minWidth: NestoryHitTarget.minimum, minHeight: NestoryHitTarget.minimum)
                            .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    if !customTasks.isEmpty {
                        Text("항목을 길게 누르거나 우클릭하면 삭제할 수 있어요.")
                            .font(.nestory(.caption))
                            .foregroundStyle(NestoryColor.cocoaSoft)
                    }
                }
            }
            .padding(NestorySpacing.l)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
    }

    private func dueText(week: Int?) -> String? {
        guard let week, let due = child.pregnancy?.dueDate ?? child.dueDate else { return nil }
        return "\(week)주까지 · \(PregnancyCalculator.date(atWeeks: week, dueDate: due).shortKorean)"
    }

    private func addItem() {
        let title = newTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        let task = TaskItem(title: title, category: .preparation)
        modelContext.insert(task)
        task.family = child.family
        newTitle = ""
    }
}

private struct ChecklistSection<Content: View>: View {
    let title: String
    let done: Int
    let total: Int
    let dueText: String?
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: NestorySpacing.s) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.nestory(.headline))
                    if let dueText {
                        Text(dueText).font(.nestory(.caption)).foregroundStyle(NestoryColor.cocoaSoft)
                    }
                }
                Spacer()
                Text("\(done)/\(total)")
                    .font(.nestory(.subheadline, weight: .semibold))
                    .monospacedDigit()
            }
            .foregroundStyle(NestoryColor.cocoa)
            .accessibilityElement(children: .combine)

            NestoryCard {
                content()
            }
        }
    }
}

private struct TaskRow: View {
    let task: TaskItem
    let now: Date
    let onDelete: (() -> Void)?

    private var isDone: Bool { task.doneAt != nil }

    var body: some View {
        HStack {
            CheckToggleButton(isDone: isDone, label: "\(task.title) 완료") {
                withAnimation { task.doneAt = isDone ? nil : now }
            }
            Text(task.title)
                .font(.nestory(.body))
                .strikethrough(isDone)
                .foregroundStyle(isDone ? NestoryColor.cocoaSoft : NestoryColor.cocoa)
            Spacer(minLength: 0)
        }
        .contextMenu {
            if let onDelete {
                Button("삭제", role: .destructive, action: onDelete)
            }
        }
        .accessibilityAction(named: "삭제") { onDelete?() }
    }
}

#Preview("체크리스트") {
    NavigationStack {
        WithActiveChild { ChecklistView(child: $0) }
    }
    .previewEnvironment()
}
