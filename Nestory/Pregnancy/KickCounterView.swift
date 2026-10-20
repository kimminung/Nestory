import NestoryData
import NestoryKit
import NestoryUI
import SwiftData
import SwiftUI

/// 태동 카운터: 시작 → 느낄 때마다 탭 → 끝내기. 기록은 임신 정보에 저장된다.
struct KickCounterView: View {
    let child: Child

    @Environment(\.modelContext) private var modelContext
    @Environment(\.referenceDate) private var referenceDate

    private var now: Date { referenceDate ?? Date() }

    private var sessions: [KickSession] {
        (child.pregnancy?.kickSessions ?? []).sorted { $0.start > $1.start }
    }

    private var active: KickSession? { sessions.first { $0.end == nil } }
    private var finished: [KickSession] { sessions.filter { $0.end != nil } }

    var body: some View {
        ScrollView {
            VStack(spacing: NestorySpacing.l) {
                if child.pregnancy == nil {
                    EmptyState(title: "임신 정보가 없어요", message: "예정일을 입력하면 쓸 수 있어요.", systemImage: "hand.tap.fill")
                } else if let active {
                    activeCard(active)
                } else {
                    startCard
                }

                if !finished.isEmpty {
                    history
                }

                Text("태동은 아이마다, 시간마다 달라요. 평소와 다르다고 느껴지면 기다리지 말고 병원에 문의하세요.")
                    .font(.nestory(.footnote))
                    .foregroundStyle(NestoryColor.cocoaSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(NestorySpacing.l)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .background(NestoryColor.cream)
        .navigationTitle("태동 카운터")
    }

    private var startCard: some View {
        NestoryCard(fill: .mint, contentColor: .onPastel) {
            Text("아기가 움직이는 걸 느낄 때마다 눌러 주세요")
                .font(.nestory(.headline))
            Button("시작하기") { start() }
                .buttonStyle(.nestoryPrimary)
                .padding(.top, NestorySpacing.xs)
        }
    }

    private func activeCard(_ session: KickSession) -> some View {
        VStack(spacing: NestorySpacing.l) {
            NestoryCard(fill: .mint, contentColor: .onPastel) {
                HStack {
                    Text("경과 시간").font(.nestory(.subheadline, weight: .semibold))
                    Spacer()
                    Text(timerInterval: session.start...Date.distantFuture, showsHours: true)
                        .font(.nestory(.title3, weight: .bold))
                        .monospacedDigit()
                }
                Text("\(session.count)번")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("태동 \(session.count)번")
            }

            Button {
                session.count += 1
            } label: {
                Label("태동 +1", systemImage: "hand.tap.fill")
                    .font(.nestory(.title2, weight: .bold))
                    .foregroundStyle(NestoryColor.onPastel)
                    .frame(maxWidth: .infinity, minHeight: 88)
                    .background(NestoryColor.peach, in: RoundedRectangle(cornerRadius: NestoryRadius.card, style: .continuous))
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.impact, trigger: session.count)

            Button("끝내기") { finish(session) }
                .buttonStyle(.bordered)
                .controlSize(.large)
        }
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: NestorySpacing.s) {
            Text("지난 기록")
                .font(.nestory(.headline))
                .foregroundStyle(NestoryColor.cocoa)
            NestoryCard {
                ForEach(finished) { session in
                    HistoryRow(session: session)
                        .contextMenu {
                            Button("삭제", role: .destructive) { modelContext.delete(session) }
                        }
                    if session.id != finished.last?.id { Divider() }
                }
            }
        }
    }

    private func start() {
        guard let pregnancy = child.pregnancy else { return }
        let session = KickSession(start: now)
        modelContext.insert(session)
        session.pregnancy = pregnancy
    }

    private func finish(_ session: KickSession) {
        session.end = now
    }
}

private struct HistoryRow: View {
    let session: KickSession

    var body: some View {
        let end = session.end ?? session.start
        let summary = KickCountSummary(count: session.count, start: session.start, end: end)
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.start.shortKorean)
                    .font(.nestory(.body, weight: .semibold))
                Text("\(Int(summary.durationSeconds / 60))분 동안")
                    .font(.nestory(.footnote))
                    .foregroundStyle(NestoryColor.cocoaSoft)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(session.count)번")
                    .font(.nestory(.title3, weight: .bold))
                    .monospacedDigit()
                if let perHour = summary.perHour {
                    Text("시간당 \(Int(perHour.rounded()))번")
                        .font(.nestory(.caption))
                        .foregroundStyle(NestoryColor.cocoaSoft)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview("태동 카운터") {
    NavigationStack {
        WithActiveChild { KickCounterView(child: $0) }
    }
    .previewEnvironment()
}
