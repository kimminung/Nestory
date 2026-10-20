import NestoryKit
import NestoryUI
import SwiftUI

/// 진통 타이머: 진통이 시작될 때와 끝날 때 한 번씩 누른다. 간격·지속시간을 계산해 보여 준다.
/// 기록은 이 기기의 앱 설정(@AppStorage)에 JSON 으로 보관한다(스키마 변경 없이 가볍게).
struct ContractionTimerView: View {
    @AppStorage("contractionRecords.v1") private var storedRecords = ""
    @State private var startedAt: Date?
    @State private var confirmingReset = false

    private var records: [ContractionRecord] {
        (try? JSONDecoder().decode([ContractionRecord].self, from: Data(storedRecords.utf8))) ?? []
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 20)) { context in
            let now = context.date
            let recent = ContractionAnalyzer.summarize(records, now: now)
            ScrollView {
                VStack(spacing: NestorySpacing.l) {
                    mainButton
                    if recent.count > 0 { summaryCard(recent) }
                    if ContractionAnalyzer.meetsGuideline(records, now: now) { guidelineCard }
                    if !records.isEmpty { list }
                    Text("이 화면은 일반적인 \"5분 간격·1분 지속·1시간\" 안내를 참고용으로 계산해 줘요. 병원에 연락할 시점은 다니는 병원의 안내를 따르고, 걱정되면 기다리지 말고 연락하세요.")
                        .font(.nestory(.footnote))
                        .foregroundStyle(NestoryColor.cocoaSoft)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(NestorySpacing.l)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
        }
        .background(NestoryColor.cream)
        .navigationTitle("진통 타이머")
        .toolbar {
            ToolbarItem {
                Button("기록 지우기", systemImage: "trash") { confirmingReset = true }
                    .disabled(records.isEmpty && startedAt == nil)
            }
        }
        .confirmationDialog("진통 기록을 모두 지울까요?", isPresented: $confirmingReset, titleVisibility: .visible) {
            Button("모두 지우기", role: .destructive) {
                storedRecords = ""
                startedAt = nil
            }
        }
    }

    // MARK: - 큰 버튼

    private var mainButton: some View {
        Button(action: toggle) {
            VStack(spacing: NestorySpacing.xs) {
                Image(systemName: startedAt == nil ? "play.fill" : "stop.fill")
                    .font(.nestory(.largeTitle, weight: .bold))
                    .accessibilityHidden(true)
                Text(startedAt == nil ? "진통 시작" : "진통 끝")
                    .font(.nestory(.title2, weight: .bold))
                if let startedAt {
                    Text(timerInterval: startedAt...Date.distantFuture, pauseTime: nil, countsDown: false, showsHours: false)
                        .font(.nestory(.title3))
                        .monospacedDigit()
                }
            }
            .foregroundStyle(NestoryColor.onPastel)
            .frame(maxWidth: .infinity, minHeight: 160)
            .background(
                startedAt == nil ? NestoryColor.sky : NestoryColor.peach,
                in: RoundedRectangle(cornerRadius: NestoryRadius.card, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact, trigger: startedAt)
    }

    // MARK: - 요약

    private func summaryCard(_ summary: ContractionSummary) -> some View {
        NestoryCard {
            Text("최근 1시간")
                .font(.nestory(.footnote, weight: .semibold))
                .foregroundStyle(NestoryColor.cocoaSoft)
            HStack(alignment: .top) {
                Metric(title: "횟수", value: "\(summary.count)번")
                Metric(title: "평균 간격", value: summary.averageIntervalSeconds.map(Self.minutesText) ?? "-")
                Metric(title: "평균 지속", value: summary.averageDurationSeconds.map(Self.secondsText) ?? "-")
            }
        }
    }

    private var guidelineCard: some View {
        NestoryCard(fill: .rose, contentColor: .onPastel) {
            Label("기준을 채웠어요", systemImage: "phone.fill")
                .font(.nestory(.headline))
            Text("간격이 짧고 오래 이어지고 있어요. 병원의 안내에 따라 연락해 보세요.")
                .font(.nestory(.subheadline))
        }
    }

    private var list: some View {
        let ordered = records.sorted { $0.start > $1.start }
        return NestoryCard {
            ForEach(Array(ordered.enumerated()), id: \.element) { index, record in
                HStack {
                    Text(record.start.formatted(
                        Date.FormatStyle(date: .omitted, time: .shortened, locale: KoreanFormat.locale, calendar: .korea, timeZone: Calendar.korea.timeZone)
                    ))
                    .font(.nestory(.body, weight: .semibold))
                    .monospacedDigit()
                    Spacer()
                    Text(Self.secondsText(record.duration))
                        .monospacedDigit()
                    if index + 1 < ordered.count {
                        let interval = record.start.timeIntervalSince(ordered[index + 1].start)
                        Text("간격 \(Self.minutesText(interval))")
                            .font(.nestory(.footnote))
                            .foregroundStyle(NestoryColor.cocoaSoft)
                            .frame(minWidth: 90, alignment: .trailing)
                    }
                }
                if index + 1 < ordered.count { Divider() }
            }
        }
    }

    // MARK: - 동작

    private func toggle() {
        if let started = startedAt {
            var all = records
            all.append(ContractionRecord(start: started, end: Date()))
            if let data = try? JSONEncoder().encode(all) { storedRecords = String(decoding: data, as: UTF8.self) }
            startedAt = nil
        } else {
            startedAt = Date()
        }
    }

    // MARK: - 표기

    static func secondsText(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        return total >= 60 ? "\(total / 60)분 \(total % 60)초" : "\(total)초"
    }

    static func minutesText(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        return "\(total / 60)분 \(total % 60)초"
    }

    private struct Metric: View {
        let title: LocalizedStringKey
        let value: String

        var body: some View {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.nestory(.caption)).foregroundStyle(NestoryColor.cocoaSoft)
                Text(value).font(.nestory(.title3, weight: .bold)).monospacedDigit()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        }
    }
}

#Preview("진통 타이머") {
    NavigationStack { ContractionTimerView() }
}
