import NestoryData
import NestoryKit
import NestoryUI
import OSLog
import SwiftData
import SwiftUI

/// 첫 실행 온보딩: 환영 → 상태 → 예정일/출생일 → 이름 → 알림
struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.ruleCatalog) private var catalog
    @State private var model = OnboardingModel()
    @State private var isFinishing = false
    @State private var errorMessage: String?

    private static let logger = Logger(subsystem: "com.kimminung.nestory", category: "onboarding")

    var body: some View {
        VStack(spacing: 0) {
            StepDots(current: model.step.rawValue, total: OnboardingModel.Step.allCases.count)
                .padding(.top, NestorySpacing.l)

            ScrollView {
                stepContent
                    .frame(maxWidth: 560)
                    .padding(NestorySpacing.xl)
                    .frame(maxWidth: .infinity)
            }

            footer
                .frame(maxWidth: 560)
                .padding(.horizontal, NestorySpacing.xl)
                .padding(.bottom, NestorySpacing.l)
        }
        .background(NestoryColor.cream)
        .alert("시작하지 못했어요", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - 단계별 내용

    @ViewBuilder
    private var stepContent: some View {
        switch model.step {
        case .welcome: welcome
        case .status: statusStep
        case .details: detailsStep
        case .names: namesStep
        case .notifications: notificationsStep
        }
    }

    private var welcome: some View {
        EmptyState(
            title: "Nestory에 오신 걸 환영해요",
            message: "아이를 기다리는 날부터 함께 자라는\n우리 가족 육아 도구예요.",
            systemImage: "teddybear.fill"
        )
    }

    private var statusStep: some View {
        VStack(alignment: .leading, spacing: NestorySpacing.l) {
            StepHeader(title: "지금 어떤 상태인가요?", message: "나중에 바꿀 수 있어요.")
            OptionCard(
                title: "임신 중이에요",
                subtitle: "출산예정일로 검진·준비 일정을 만들어요",
                systemImage: "heart.fill",
                isSelected: model.status == .pregnant
            ) { model.status = .pregnant }
            OptionCard(
                title: "아이가 태어났어요",
                subtitle: "출생일로 월령과 접종 일정을 만들어요",
                systemImage: "figure.and.child.holdinghands",
                isSelected: model.status == .born
            ) { model.status = .born }
        }
    }

    private var detailsStep: some View {
        VStack(alignment: .leading, spacing: NestorySpacing.l) {
            switch model.status {
            case .pregnant:
                StepHeader(title: "출산예정일을 알려 주세요", message: "아는 방법으로 입력하면 알아서 계산해요.")
                DueDateForm(state: model.dueDateForm, now: model.now)
            case .born:
                StepHeader(title: "아이는 언제 태어났나요?", message: "출생일 기준으로 월령을 계산해요.")
                NestoryCard {
                    DatePicker("출생일", selection: $model.birthDate, in: ...model.now, displayedComponents: .date)
                }
            }
        }
    }

    private var namesStep: some View {
        VStack(alignment: .leading, spacing: NestorySpacing.l) {
            StepHeader(title: "이름을 알려 주세요", message: "비워 두면 기본 호칭을 써요.")
            NestoryCard {
                TextField("아기 태명 또는 이름", text: $model.nickname)
                    .textFieldStyle(.roundedBorder)
                TextField("내 이름", text: $model.guardianName)
                    .textFieldStyle(.roundedBorder)
                Picker("나는", selection: $model.guardianRole) {
                    Text("엄마").tag(GuardianRole.mother)
                    Text("아빠").tag(GuardianRole.father)
                    Text("보호자").tag(GuardianRole.other)
                }
                .pickerStyle(.segmented)
                Toggle("쌍둥이 이상이에요", isOn: $model.isMultiple)
            }
        }
    }

    private var notificationsStep: some View {
        VStack(alignment: .leading, spacing: NestorySpacing.l) {
            StepHeader(title: "일정을 알려 드릴까요?", message: "검진·신청 기한을 7일 전, 하루 전, 당일에 조용히 알려 드려요. 밤에는 울리지 않아요.")
            NestoryCard {
                Toggle("알림 받기", isOn: $model.wantsNotifications)
                Text("시작하기를 누르면 시스템 알림 권한을 물어봐요.")
                    .font(.nestory(.footnote))
                    .foregroundStyle(NestoryColor.cocoaSoft)
            }
        }
    }

    // MARK: - 하단 버튼

    private var footer: some View {
        HStack(spacing: NestorySpacing.m) {
            if !model.isFirstStep {
                Button("이전") { withAnimation { model.back() } }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(isFinishing)
            }
            Button {
                if model.isLastStep {
                    Task { await finish() }
                } else {
                    withAnimation { model.next() }
                }
            } label: {
                Text(model.isLastStep ? "시작하기" : "다음")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.nestoryPrimary)
            .disabled(!model.canAdvance || isFinishing)
        }
    }

    // MARK: - 완료

    private func finish() async {
        isFinishing = true
        defer { isFinishing = false }
        do {
            let child = try FamilySetup.create(model.draft(), context: modelContext)
            if let catalog, child.pregnancy != nil {
                try PrenatalPlanSync.sync(
                    child: child, schedule: catalog.prenatal, checklist: catalog.checklist, context: modelContext
                )
            }
            if model.wantsNotifications {
                _ = await NotificationService.requestAuthorization()
            }
        } catch {
            Self.logger.error("온보딩 완료 실패: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - 부품

private struct StepDots: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: NestorySpacing.s) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(index <= current ? NestoryColor.peach : NestoryColor.card)
                    .frame(width: index == current ? 24 : 8, height: 8)
                    .overlay { Capsule().strokeBorder(NestoryColor.peach, lineWidth: 1) }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("진행 단계")
        .accessibilityValue("\(current + 1) / \(total)")
    }
}

private struct StepHeader: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: NestorySpacing.xs) {
            Text(title)
                .font(.nestory(.title2, weight: .bold))
                .foregroundStyle(NestoryColor.cocoa)
            Text(message)
                .font(.nestory(.body))
                .foregroundStyle(NestoryColor.cocoaSoft)
        }
    }
}

private struct OptionCard: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: NestorySpacing.m) {
                Image(systemName: systemImage)
                    .font(.nestory(.title2, weight: .semibold))
                    .frame(width: 44)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: NestorySpacing.xs) {
                    Text(title).font(.nestory(.headline))
                    Text(subtitle).font(.nestory(.subheadline))
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.nestory(.title3))
                    .accessibilityHidden(true)
            }
            .foregroundStyle(isSelected ? NestoryColor.onPastel : NestoryColor.cocoa)
            .padding(NestorySpacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isSelected ? NestoryColor.peach : NestoryColor.card,
                in: RoundedRectangle(cornerRadius: NestoryRadius.card, style: .continuous)
            )
            .contentShape(RoundedRectangle(cornerRadius: NestoryRadius.card, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview("온보딩") {
    OnboardingView()
        .modelContainer(PreviewSeed.emptyContainer())
}
