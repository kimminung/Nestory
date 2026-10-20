import NestoryData
import NestoryKit
import NestoryUI
import OSLog
import SwiftData
import SwiftUI
#if os(iOS)
import UIKit
#endif

/// 밤 수유 모드: 어둡고 큰 버튼. 한 손으로 분유·모유·기저귀를 기록한다.
struct NightFeedingView: View {
    let child: Child
    /// 프리뷰·테스트에서 "지금" 을 고정할 때
    let now: Date?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private static let logger = Logger(subsystem: "com.kimminung.nestory", category: "night")

    var body: some View {
        TimelineView(.periodic(from: .now, by: 15)) { context in
            let current = now ?? context.date
            content(now: current)
        }
        .background(NestoryColor.cream)
        .environment(\.nestoryNightMode, true)
        .preferredColorScheme(.dark)
        .onAppear { keepScreenAwake(true) }
        .onDisappear { keepScreenAwake(false) }
    }

    private func content(now: Date) -> some View {
        let entries = (child.careLogs ?? []).map(\.entry)
        let last = CareAnalyzer.lastEntry(of: CareAnalyzer.feedingTypes, in: entries, now: now)
        let breastTimer = CareLogService.activeTimers(for: child).first { $0.type == .breastFeeding }
        let formulaMl = QuickLogDefaults.formulaMilliliters(from: entries)

        return VStack(spacing: NestorySpacing.xl) {
            HStack {
                Spacer()
                Button("닫기", systemImage: "xmark.circle.fill") { dismiss() }
                    .labelStyle(.iconOnly)
                    .font(.nestory(.title))
                    .buttonStyle(.plain)
                    .foregroundStyle(NestoryColor.cocoaSoft)
                    .frame(minWidth: NestoryHitTarget.minimum, minHeight: NestoryHitTarget.minimum)
            }

            VStack(spacing: NestorySpacing.xs) {
                Text("마지막 수유")
                    .font(.nestory(.title3))
                    .foregroundStyle(NestoryColor.cocoaSoft)
                Text(last.map { DurationFormatter.agoLabel(now.timeIntervalSince($0.start)) } ?? "기록 없음")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(NestoryColor.peachDeep)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            .accessibilityElement(children: .combine)

            Spacer(minLength: 0)

            if let breastTimer {
                VStack(spacing: NestorySpacing.s) {
                    Text(timerInterval: breastTimer.start...Date.distantFuture, pauseTime: nil, countsDown: false, showsHours: false)
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(NestoryColor.cocoa)
                    NightButton(title: "모유 수유 끝", systemImage: "stop.fill") { stop(breastTimer, now: now) }
                }
            } else {
                VStack(spacing: NestorySpacing.m) {
                    NightButton(title: "분유 \(Int(formulaMl))ml 먹었어요", systemImage: "drop.fill") {
                        record(.formula, amount: formulaMl, unit: .milliliters, now: now)
                    }
                    NightButton(title: "모유 수유 시작", systemImage: "play.fill") {
                        record(timer: .breastFeeding, now: now)
                    }
                    NightButton(title: "기저귀 갈았어요", systemImage: "circle.hexagongrid.fill") {
                        record(.diaper, detail: DiaperKind.wet.rawValue, now: now)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(NestorySpacing.xl)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
    }

    // MARK: - 동작

    private func record(
        _ type: CareLogType, amount: Double? = nil, unit: CareUnit? = nil, detail: String? = nil, now: Date
    ) {
        do {
            try CareLogService.log(type, for: child, start: now, amount: amount, unit: unit, detail: detail, context: modelContext)
        } catch {
            Self.logger.error("기록 실패: \(error.localizedDescription)")
        }
    }

    private func record(timer type: CareLogType, now: Date) {
        do {
            try CareLogService.startTimer(type, for: child, at: now, context: modelContext)
        } catch {
            Self.logger.error("타이머 시작 실패: \(error.localizedDescription)")
        }
    }

    private func stop(_ log: CareLog, now: Date) {
        do {
            try CareLogService.stopTimer(log, at: now, context: modelContext)
        } catch {
            Self.logger.error("타이머 종료 실패: \(error.localizedDescription)")
        }
    }

    private func keepScreenAwake(_ enabled: Bool) {
        #if os(iOS)
        UIApplication.shared.isIdleTimerDisabled = enabled
        #endif
    }
}

private struct NightButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.nestory(.title2, weight: .bold))
                .foregroundStyle(NestoryColor.onPastel)
                .frame(maxWidth: .infinity, minHeight: 88)
                .background(NestoryColor.peach, in: RoundedRectangle(cornerRadius: NestoryRadius.card, style: .continuous))
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact, trigger: title)
    }
}

#Preview("밤 수유 모드") {
    WithActiveChild { NightFeedingView(child: $0, now: PreviewSeed.bornNow) }
        .bornPreviewEnvironment()
}
