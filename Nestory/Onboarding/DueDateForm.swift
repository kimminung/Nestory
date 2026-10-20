import NestoryKit
import NestoryUI
import SwiftUI

/// 출산예정일 입력 폼: 4가지 방법 중 하나를 골라 입력하면 계산 결과를 바로 보여 준다.
struct DueDateForm: View {
    @Bindable var state: DueDateFormState
    let now: Date

    private var input: DueDateInput { state.input() }
    private var issues: [DueDateInputIssue] { state.issues(now: now) }

    var body: some View {
        VStack(alignment: .leading, spacing: NestorySpacing.l) {
            Picker("계산 방법", selection: $state.method) {
                Text("생리일").tag(DueDateMethod.lastMenstrualPeriod)
                Text("초음파").tag(DueDateMethod.ultrasound)
                Text("시험관").tag(DueDateMethod.ivfTransfer)
                Text("직접").tag(DueDateMethod.direct)
            }
            .pickerStyle(.segmented)

            NestoryCard {
                inputs
            }
            .animation(nil, value: state.method)

            resultCard
        }
    }

    @ViewBuilder
    private var inputs: some View {
        switch state.method {
        case .lastMenstrualPeriod:
            DatePicker("마지막 생리 시작일", selection: $state.lastMenstrualPeriod, in: ...now, displayedComponents: .date)
        case .ultrasound:
            DatePicker("초음파 검사일", selection: $state.scanDate, in: ...now, displayedComponents: .date)
            Stepper("그날 아기는 \(state.scanWeeks)주", value: $state.scanWeeks, in: 4...42)
            Stepper("\(state.scanDays)일", value: $state.scanDays, in: 0...6)
        case .ivfTransfer:
            DatePicker("배아 이식일", selection: $state.transferDate, in: ...now, displayedComponents: .date)
            Stepper("배아 일령 \(state.embryoAgeDays)일", value: $state.embryoAgeDays, in: 1...7)
        case .direct:
            DatePicker("병원에서 들은 예정일", selection: $state.directDueDate, displayedComponents: .date)
        }
    }

    private var resultCard: some View {
        let summary = PregnancySummary.make(dueDate: input.dueDate(), now: now)
        return NestoryCard(fill: .butter, contentColor: .onPastel) {
            Text("출산예정일")
                .font(.nestory(.footnote, weight: .semibold))
            Text(KoreanFormat.longDate(summary.dueDate))
                .font(.nestory(.title3, weight: .bold))
            if let age = summary.age {
                Text("지금은 \(AgeFormatter.pregnancyLabel(age)) · \(AgeFormatter.dDayLabel(daysUntil: summary.daysUntilDue))")
                    .font(.nestory(.body))
            }
            ForEach(issues, id: \.self) { issue in
                Label(issue.message, systemImage: "exclamationmark.triangle.fill")
                    .font(.nestory(.footnote, weight: .semibold))
                    .foregroundStyle(NestoryColor.danger)
            }
        }
    }
}
