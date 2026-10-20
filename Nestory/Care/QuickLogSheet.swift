import NestoryData
import NestoryKit
import NestoryUI
import OSLog
import SwiftData
import SwiftUI

/// 빠른 기록에서 고를 수 있는 종류
enum QuickLogKind: String, Identifiable, CaseIterable {
    case formula, breast, sleep, diaper, temperature, medication

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .formula: "분유"
        case .breast: "모유"
        case .sleep: "수면"
        case .diaper: "기저귀"
        case .temperature: "체온"
        case .medication: "투약"
        }
    }

    var type: CareLogType {
        switch self {
        case .formula: .formula
        case .breast: .breastFeeding
        case .sleep: .sleep
        case .diaper: .diaper
        case .temperature: .temperature
        case .medication: .medication
        }
    }

    var style: CategoryStyle { .style(for: type) }

    /// 시작/끝 타이머로 기록하는 종류
    var usesTimer: Bool { CareLogService.timerTypes.contains(type) }
}

/// 기록 입력 시트. 분유·기저귀·체온·투약은 값 입력, 모유·수면은 "지금 시작" 또는 "끝난 기록 입력".
struct QuickLogSheet: View {
    let kind: QuickLogKind
    let child: Child
    let now: Date

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private enum Mode: Hashable { case startNow, enterPast }

    @State private var mode: Mode = .startNow
    @State private var startAt: Date
    @State private var endAt: Date
    @State private var milliliters: Double
    @State private var side: BreastSide = .left
    @State private var diaper: DiaperKind = .wet
    @State private var temperature = 36.8
    @State private var medicationName = ""
    @State private var note = ""
    @State private var errorMessage: String?

    private static let logger = Logger(subsystem: "com.kimminung.nestory", category: "care")

    init(kind: QuickLogKind, child: Child, now: Date) {
        self.kind = kind
        self.child = child
        self.now = now
        _startAt = State(initialValue: now)
        _endAt = State(initialValue: now)
        let entries = (child.careLogs ?? []).map(\.entry)
        _milliliters = State(initialValue: QuickLogDefaults.formulaMilliliters(from: entries))
    }

    private var isTimerStart: Bool { kind.usesTimer && mode == .startNow }
    private var hasValidRange: Bool { !kind.usesTimer || mode == .startNow || endAt >= startAt }

    var body: some View {
        NavigationStack {
            Form {
                if kind.usesTimer {
                    Picker("방법", selection: $mode) {
                        Text("지금 시작").tag(Mode.startNow)
                        Text("끝난 기록 입력").tag(Mode.enterPast)
                    }
                    .pickerStyle(.segmented)
                }

                inputs

                if kind == .medication {
                    TextField("약 이름", text: $medicationName)
                }
                TextField("메모(선택)", text: $note)

                if let errorMessage {
                    Text(errorMessage).foregroundStyle(NestoryColor.danger)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(Text(kind.title))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isTimerStart ? "시작" : "저장", action: save).disabled(!hasValidRange)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 420)
        #endif
        .presentationDetents([.medium, .large])
    }

    // MARK: - 종류별 입력

    @ViewBuilder
    private var inputs: some View {
        switch kind {
        case .formula:
            Stepper("\(Int(milliliters))ml", value: $milliliters, in: 10...400, step: 10)
            DatePicker("시각", selection: $startAt, in: ...now)

        case .breast:
            Picker("방향", selection: $side) {
                Text("왼쪽").tag(BreastSide.left)
                Text("오른쪽").tag(BreastSide.right)
                Text("양쪽").tag(BreastSide.both)
            }
            .pickerStyle(.segmented)
            timeInputs

        case .sleep:
            timeInputs

        case .diaper:
            Picker("종류", selection: $diaper) {
                Text("소변").tag(DiaperKind.wet)
                Text("대변").tag(DiaperKind.dirty)
                Text("둘 다").tag(DiaperKind.both)
            }
            .pickerStyle(.segmented)
            DatePicker("시각", selection: $startAt, in: ...now)

        case .temperature:
            Stepper("\(temperature.formatted(.number.precision(.fractionLength(1))))℃", value: $temperature, in: 34...42, step: 0.1)
            DatePicker("시각", selection: $startAt, in: ...now)

        case .medication:
            DatePicker("시각", selection: $startAt, in: ...now)
        }
    }

    @ViewBuilder
    private var timeInputs: some View {
        if mode == .enterPast {
            DatePicker("시작", selection: $startAt, in: ...now)
            DatePicker("끝", selection: $endAt, in: startAt...max(startAt, now))
        } else {
            Text("지금 시각부터 재요. 끝나면 홈에서 눌러 주세요.")
                .font(.nestory(.footnote))
                .foregroundStyle(NestoryColor.cocoaSoft)
        }
    }

    // MARK: - 저장

    private func save() {
        do {
            switch kind {
            case .formula:
                try CareLogService.log(.formula, for: child, start: startAt, amount: milliliters, unit: .milliliters, note: note, context: modelContext)
            case .breast, .sleep:
                let detail = kind == .breast ? side.rawValue : nil
                if mode == .startNow {
                    let log = try CareLogService.startTimer(kind.type, for: child, at: now, detail: detail, context: modelContext)
                    log.note = note
                } else {
                    let minutes = (endAt.timeIntervalSince(startAt) / 60 * 10).rounded() / 10
                    try CareLogService.log(
                        kind.type, for: child, start: startAt, end: endAt,
                        amount: kind == .breast ? minutes : nil, unit: kind == .breast ? .minutes : nil,
                        detail: detail, note: note, context: modelContext
                    )
                }
            case .diaper:
                try CareLogService.log(.diaper, for: child, start: startAt, detail: diaper.rawValue, note: note, context: modelContext)
            case .temperature:
                try CareLogService.log(.temperature, for: child, start: startAt, amount: temperature, unit: .celsius, note: note, context: modelContext)
            case .medication:
                let name = medicationName.trimmingCharacters(in: .whitespaces)
                try CareLogService.log(.medication, for: child, start: startAt, note: [name, note].filter { !$0.isEmpty }.joined(separator: " · "), context: modelContext)
            }
            dismiss()
        } catch {
            Self.logger.error("기록 저장 실패: \(error.localizedDescription)")
            errorMessage = "저장하지 못했어요. 다시 시도해 주세요."
        }
    }
}

// MARK: - 기록 표기

extension CareLog {
    /// 기록 목록·요약에 쓰는 한 줄 제목. 예: "분유 120ml", "모유 15분 (왼쪽)", "기저귀 · 소변"
    var displayTitle: String {
        switch type {
        case .formula:
            return amount.map { "분유 \(Int($0))\(unit == .ounces ? "oz" : "ml")" } ?? "분유"
        case .breastFeeding:
            let side = detailRaw.flatMap(BreastSide.init(rawValue:)).map { sideLabel($0) }
            let minutes = end == nil ? nil : amount.map { "\(Int($0.rounded()))분" }
            let parts = ["모유", minutes].compactMap { $0 }.joined(separator: " ")
            return side.map { "\(parts) (\($0))" } ?? parts
        case .sleep:
            return "수면"
        case .diaper:
            switch detailRaw.flatMap(DiaperKind.init(rawValue:)) {
            case .dirty: return "기저귀 · 대변"
            case .both: return "기저귀 · 소변+대변"
            case .wet, nil: return "기저귀 · 소변"
            }
        case .temperature:
            return amount.map { "체온 \($0.formatted(.number.precision(.fractionLength(1))))℃" } ?? "체온"
        case .medication:
            return note.isEmpty ? "투약" : "투약 · \(note)"
        case .solidFood:
            return "이유식"
        }
    }

    private func sideLabel(_ side: BreastSide) -> String {
        switch side {
        case .left: "왼쪽"
        case .right: "오른쪽"
        case .both: "양쪽"
        }
    }
}

#Preview("분유 기록 시트") {
    WithActiveChild { QuickLogSheet(kind: .formula, child: $0, now: PreviewSeed.bornNow) }
        .bornPreviewEnvironment()
}

#Preview("수면 기록 시트") {
    WithActiveChild { QuickLogSheet(kind: .sleep, child: $0, now: PreviewSeed.bornNow) }
        .bornPreviewEnvironment()
}
