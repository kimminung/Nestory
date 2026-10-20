import NestoryData
import NestoryKit
import NestoryUI
import OSLog
import SwiftData
import SwiftUI

/// 예방접종: 출생일로 계산한 일정과 접종 기록
struct VaccinesView: View {
    let child: Child

    @Environment(\.ruleCatalog) private var catalog
    @Environment(\.referenceDate) private var referenceDate
    @State private var editing: VaccineDose?

    private var now: Date { referenceDate ?? Date() }

    var body: some View {
        Group {
            if let catalog, let birth = child.birthDate {
                content(catalog: catalog, birth: birth)
            } else {
                RulesUnavailableView()
            }
        }
        .background(NestoryColor.cream)
        .navigationTitle("예방접종")
        .sheet(item: $editing) { dose in
            VaccineRecordSheet(dose: dose, child: child, now: now)
        }
    }

    private func content(catalog: RuleCatalog, birth: Date) -> some View {
        let doses = VaccineScheduler.schedule(
            birth: birth, rules: catalog.vaccines, records: VaccinationService.records(for: child), now: now
        )
        let actionable = doses.filter { $0.status == .overdue || $0.status == .open }
        let later = doses.filter { $0.status == .upcoming }
        let done = doses.filter { $0.status == .done }.sorted { ($0.doneDate ?? .distantPast) > ($1.doneDate ?? .distantPast) }

        return ScrollView {
            VStack(alignment: .leading, spacing: NestorySpacing.l) {
                RuleMetaBanner(meta: catalog.vaccines.meta)

                group("지금 맞을 수 있어요", doses: actionable, emptyText: "지금 맞을 접종이 없어요.")
                group("앞으로 예정", doses: Array(later.prefix(6)), emptyText: "예정된 접종이 없어요.")
                if later.count > 6 {
                    DisclosureGroup("이후 예정 \(later.count - 6)건") {
                        VStack(spacing: 0) {
                            ForEach(Array(later.dropFirst(6))) { dose in
                                VaccineRow(dose: dose, now: now) { editing = dose }
                                if dose.id != later.last?.id { Divider() }
                            }
                        }
                        .padding(.top, NestorySpacing.s)
                    }
                    .font(.nestory(.subheadline))
                    .foregroundStyle(NestoryColor.cocoa)
                }
                group("맞은 접종", doses: done, emptyText: "아직 기록한 접종이 없어요.")
            }
            .padding(NestorySpacing.l)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
    }

    private func group(_ title: LocalizedStringKey, doses: [VaccineDose], emptyText: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: NestorySpacing.s) {
            SectionTitle(title)
            NestoryCard {
                if doses.isEmpty {
                    Text(emptyText).font(.nestory(.body)).foregroundStyle(NestoryColor.cocoaSoft)
                } else {
                    ForEach(doses) { dose in
                        VaccineRow(dose: dose, now: now) { editing = dose }
                        if dose.id != doses.last?.id { Divider() }
                    }
                }
            }
        }
    }
}

private struct VaccineRow: View {
    let dose: VaccineDose
    let now: Date
    let action: () -> Void

    private var badgeStatus: ScheduleStatus {
        switch dose.status {
        case .done: .done
        case .upcoming: .upcoming
        case .open: .open
        case .overdue: .overdue
        }
    }

    private var dateText: String {
        if let done = dose.doneDate { return "\(KoreanFormat.longDate(done)) 접종" }
        return "\(dose.earliestDate.shortKorean) ~ \(dose.latestDate.shortKorean) (권장 \(dose.scheduledDate.shortKorean))"
    }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: NestorySpacing.m) {
                Image(systemName: "syringe.fill")
                    .foregroundStyle(NestoryColor.onPastel)
                    .frame(width: 36, height: 36)
                    .background(NestoryColor.rose, in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(dose.name) \(dose.doseNo)/\(dose.totalDoses)차")
                        .font(.nestory(.body, weight: .semibold))
                    Text(dateText).font(.nestory(.footnote)).foregroundStyle(NestoryColor.cocoaSoft)
                }
                Spacer(minLength: 0)
                ScheduleStatusBadge(status: badgeStatus)
            }
            .foregroundStyle(NestoryColor.cocoa)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(dose.status == .done ? "접종 기록을 고치거나 취소해요" : "접종 날짜를 기록해요")
    }
}

private struct VaccineRecordSheet: View {
    let dose: VaccineDose
    let child: Child
    let now: Date

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var date: Date
    @State private var place: String
    @State private var errorMessage: String?

    private static let logger = Logger(subsystem: "com.kimminung.nestory", category: "vaccine")

    init(dose: VaccineDose, child: Child, now: Date) {
        self.dose = dose
        self.child = child
        self.now = now
        let existing = (child.vaccinations ?? []).first { $0.vaccineCode == dose.code && $0.doseNo == dose.doseNo }
        _date = State(initialValue: dose.doneDate ?? now)
        _place = State(initialValue: existing?.place ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Text("\(dose.name) \(dose.doseNo)차").font(.nestory(.headline))
                DatePicker("접종일", selection: $date, in: ...now, displayedComponents: .date)
                TextField("병원(선택)", text: $place)
                if dose.status == .done {
                    Section {
                        Button("접종 기록 취소", role: .destructive, action: undo)
                    }
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(NestoryColor.danger)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("접종 기록")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("저장", action: save) }
            }
        }
        #if os(macOS)
        .frame(minWidth: 400, minHeight: 320)
        #endif
    }

    private func save() {
        do {
            let trimmed = place.trimmingCharacters(in: .whitespaces)
            try VaccinationService.complete(
                code: dose.code, doseNo: dose.doseNo, on: date, place: trimmed.isEmpty ? nil : trimmed,
                for: child, context: modelContext
            )
            dismiss()
        } catch {
            Self.logger.error("접종 저장 실패: \(error.localizedDescription)")
            errorMessage = "저장하지 못했어요. 다시 시도해 주세요."
        }
    }

    private func undo() {
        do {
            try VaccinationService.undo(code: dose.code, doseNo: dose.doseNo, for: child, context: modelContext)
            dismiss()
        } catch {
            Self.logger.error("접종 취소 실패: \(error.localizedDescription)")
            errorMessage = "취소하지 못했어요. 다시 시도해 주세요."
        }
    }
}

#Preview("예방접종") {
    NavigationStack {
        WithActiveChild { VaccinesView(child: $0) }
    }
    .bornPreviewEnvironment()
}
