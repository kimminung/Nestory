import NestoryData
import NestoryKit
import NestoryUI
import OSLog
import SwiftData
import SwiftUI

/// "아이가 태어났어요": 출생일을 기록하면 홈이 육아 모드로 바뀌고 출생 후 일정이 만들어진다.
struct BirthSheet: View {
    let child: Child
    let now: Date

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.ruleCatalog) private var catalog
    @State private var birthDate: Date
    @State private var errorMessage: String?

    private static let logger = Logger(subsystem: "com.kimminung.nestory", category: "birth")

    init(child: Child, now: Date) {
        self.child = child
        self.now = now
        _birthDate = State(initialValue: now)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("태어난 날", selection: $birthDate, in: ...now, displayedComponents: .date)
                } footer: {
                    Text("축하해요! 저장하면 육아 기록 화면으로 바뀌고, 출생신고와 예방접종 같은 일정이 만들어져요. 임신 중 기록(태동·검진)은 그대로 보관돼요.")
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(NestoryColor.danger)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("아이가 태어났어요")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("저장", action: save) }
            }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 300)
        #endif
    }

    private func save() {
        do {
            try FamilySetup.recordBirth(on: birthDate, for: child, context: modelContext)
            if let catalog {
                try PostnatalPlanSync.sync(
                    child: child, prenatal: catalog.prenatal, infantCheckups: catalog.infantCheckups, context: modelContext
                )
            }
            dismiss()
        } catch {
            Self.logger.error("출생 기록 실패: \(error.localizedDescription)")
            errorMessage = "저장하지 못했어요. 다시 시도해 주세요."
        }
    }
}
