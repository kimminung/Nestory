import NestoryData
import NestoryKit
import NestoryUI
import SwiftData
import SwiftUI

/// 더보기: 아이 정보, 예정일 수정, 알림, (개발용) 갤러리·데이터 초기화
struct MoreView: View {
    @Environment(\.referenceDate) private var referenceDate
    @State private var isEditingDueDate = false
    @State private var notificationMessage: String?
    #if DEBUG
    @Environment(\.modelContext) private var modelContext
    @State private var confirmingReset = false
    #endif

    private var now: Date { referenceDate ?? Date() }

    var body: some View {
        WithActiveChild { child in
            List {
                Section("우리 아이") {
                    LabeledContent("이름", value: child.nickname)
                    if let due = child.pregnancy?.dueDate ?? child.dueDate {
                        LabeledContent("출산예정일", value: KoreanFormat.longDate(due))
                    }
                    if let birth = child.birthDate {
                        LabeledContent("출생일", value: KoreanFormat.longDate(birth))
                    }
                    if child.birthDate == nil {
                        Button("예정일 수정", systemImage: "calendar.badge.clock") { isEditingDueDate = true }
                    }
                }

                Section("알림") {
                    Button("알림 다시 설정", systemImage: "bell.badge") {
                        Task { await requestNotifications() }
                    }
                    if let notificationMessage {
                        Text(notificationMessage)
                            .font(.nestory(.footnote))
                            .foregroundStyle(NestoryColor.cocoaSoft)
                    }
                }

                #if DEBUG
                Section("개발용") {
                    NavigationLink("디자인 갤러리") {
                        NestoryComponentGallery().navigationTitle("디자인 갤러리")
                    }
                    Button("모든 데이터 지우기", systemImage: "trash", role: .destructive) { confirmingReset = true }
                }
                #endif
            }
            .scrollContentBackground(.hidden)
            .background(NestoryColor.cream)
            .sheet(isPresented: $isEditingDueDate) {
                DueDateEditorSheet(child: child, now: now)
            }
        }
        .navigationTitle("더보기")
        #if DEBUG
        .confirmationDialog("모든 데이터를 지우고 처음부터 시작할까요?", isPresented: $confirmingReset, titleVisibility: .visible) {
            Button("모두 지우기", role: .destructive) {
                try? modelContext.delete(model: Family.self)
                try? modelContext.save()
            }
        }
        #endif
    }

    private func requestNotifications() async {
        let granted = await NotificationService.requestAuthorization()
        notificationMessage = granted
            ? "알림을 켰어요. 일정을 바탕으로 자동으로 예약돼요."
            : "알림이 꺼져 있어요. 시스템 설정에서 Nestory 알림을 허용해 주세요."
    }
}

#Preview("더보기") {
    NavigationStack { MoreView() }
        .previewEnvironment()
}
