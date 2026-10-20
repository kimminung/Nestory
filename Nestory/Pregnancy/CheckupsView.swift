import NestoryData
import NestoryKit
import NestoryUI
import SwiftData
import SwiftUI

/// 산전 검사 목록: 권장 시기와 상태, 완료 체크, 메모, 직접 추가.
/// (macOS 의 `List` 가 행 안에 버튼 두 개가 있을 때 내부 크래시를 일으켜 카드 스크롤로 만들었다.)
struct CheckupsView: View {
    let child: Child

    @Environment(\.ruleCatalog) private var catalog
    @Environment(\.referenceDate) private var referenceDate
    @Environment(\.modelContext) private var modelContext
    @State private var editing: Checkup?
    @State private var isAdding = false

    private var now: Date { referenceDate ?? Date() }

    private var checkups: [Checkup] {
        (child.pregnancy?.checkups ?? []).sorted {
            ($0.scheduledDate ?? .distantFuture, $0.title) < ($1.scheduledDate ?? .distantFuture, $1.title)
        }
    }

    /// 규칙의 권장 구간(ruleID 로 찾는다)
    private var windows: [String: ScheduledItem] {
        guard let catalog, let due = child.pregnancy?.dueDate ?? child.dueDate else { return [:] }
        let items = ScheduleGenerator.generate(
            catalog.prenatal.rules.filter { $0.category == .prenatalCheckup },
            anchors: ScheduleAnchors(lmp: child.pregnancy?.lmpDate, due: due)
        )
        return Dictionary(items.map { ($0.ruleID, $0) }, uniquingKeysWith: { first, _ in first })
    }

    var body: some View {
        let windows = windows
        ScrollView {
            VStack(alignment: .leading, spacing: NestorySpacing.m) {
                if checkups.isEmpty {
                    EmptyState(title: "검사 일정이 없어요", message: "예정일을 입력하면 검사 시기를 알려 드려요.", systemImage: "stethoscope")
                        .frame(maxWidth: .infinity)
                } else {
                    NestoryCard {
                        ForEach(checkups) { checkup in
                            CheckupRow(
                                checkup: checkup,
                                window: checkup.ruleID.flatMap { windows[$0] },
                                now: now,
                                onEdit: { editing = checkup },
                                onDelete: checkup.ruleID == nil ? { modelContext.delete(checkup) } : nil
                            )
                            if checkup.id != checkups.last?.id { Divider() }
                        }
                    }
                    Text("권장 시기는 참고용이에요. 실제 일정은 담당 병원의 안내를 따라 주세요.")
                        .font(.nestory(.footnote))
                        .foregroundStyle(NestoryColor.cocoaSoft)
                }
            }
            .padding(NestorySpacing.l)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(NestoryColor.cream)
        .navigationTitle("산전 검사")
        .toolbar {
            ToolbarItem {
                Button("검사 추가", systemImage: "plus") { isAdding = true }
            }
        }
        .sheet(item: $editing) { checkup in
            CheckupEditSheet(checkup: checkup)
        }
        .sheet(isPresented: $isAdding) {
            CheckupAddSheet(child: child, now: now)
        }
    }
}

private struct CheckupRow: View {
    let checkup: Checkup
    let window: ScheduledItem?
    let now: Date
    let onEdit: () -> Void
    let onDelete: (() -> Void)?

    private var isDone: Bool { checkup.doneDate != nil }

    private var status: ScheduleStatus? {
        if isDone { return .done }
        return window?.status(now: now, isDone: false)
    }

    private var dateText: String {
        if let window {
            return "\(window.windowStart.shortKorean) ~ \(window.windowEnd.shortKorean) (권장 \(window.recommended.shortKorean))"
        }
        return checkup.scheduledDate?.shortKorean ?? "날짜 미정"
    }

    var body: some View {
        HStack(alignment: .top, spacing: NestorySpacing.s) {
            CheckToggleButton(isDone: isDone, label: "\(checkup.title) 완료") {
                withAnimation { checkup.doneDate = isDone ? nil : now }
            }
            Button(action: onEdit) {
                VStack(alignment: .leading, spacing: NestorySpacing.xs) {
                    HStack {
                        Text(checkup.title)
                            .font(.nestory(.body, weight: .semibold))
                            .strikethrough(isDone)
                        Spacer(minLength: 0)
                        if let status { ScheduleStatusBadge(status: status) }
                    }
                    Text(dateText)
                        .font(.nestory(.footnote))
                        .foregroundStyle(NestoryColor.cocoaSoft)
                    if !checkup.memo.isEmpty {
                        Label(checkup.memo, systemImage: "note.text")
                            .font(.nestory(.footnote))
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("메모와 상세를 열어요")
        }
        .foregroundStyle(NestoryColor.cocoa)
        .contextMenu {
            if let onDelete {
                Button("삭제", role: .destructive, action: onDelete)
            }
        }
    }
}

private struct CheckupEditSheet: View {
    @Bindable var checkup: Checkup
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            Form {
                if checkup.ruleID == nil {
                    TextField("검사 이름", text: $checkup.title)
                    DatePicker(
                        "날짜",
                        selection: Binding(
                            get: { checkup.scheduledDate ?? Date() },
                            set: { checkup.scheduledDate = $0 }
                        ),
                        displayedComponents: .date
                    )
                } else {
                    Text(checkup.title).font(.nestory(.headline))
                }
                Section("메모") {
                    TextEditor(text: $checkup.memo)
                        .frame(minHeight: 120)
                }
                if checkup.ruleID == nil {
                    Section {
                        Button("이 검사 삭제", role: .destructive) {
                            modelContext.delete(checkup)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("검사 메모")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("완료") { dismiss() } }
            }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 360)
        #endif
    }
}

private struct CheckupAddSheet: View {
    let child: Child
    let now: Date

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var title = ""
    @State private var date: Date

    init(child: Child, now: Date) {
        self.child = child
        self.now = now
        _date = State(initialValue: now)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("검사 이름", text: $title)
                DatePicker("날짜", selection: $date, displayedComponents: .date)
            }
            .navigationTitle("검사 추가")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("추가", action: add).disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 260)
        #endif
    }

    private func add() {
        let checkup = Checkup(title: title.trimmingCharacters(in: .whitespaces), scheduledDate: date)
        modelContext.insert(checkup)
        checkup.pregnancy = child.pregnancy
        dismiss()
    }
}

#Preview("산전 검사") {
    NavigationStack {
        WithActiveChild { CheckupsView(child: $0) }
    }
    .previewEnvironment()
}
