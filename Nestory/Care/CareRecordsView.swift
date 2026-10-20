import Charts
import NestoryData
import NestoryKit
import NestoryUI
import OSLog
import SwiftData
import SwiftUI

/// 기록 탭(출생 후): 일간 타임라인과 주간 차트
struct CareRecordsView: View {
    let child: Child

    @Environment(\.referenceDate) private var referenceDate
    @Environment(\.modelContext) private var modelContext
    @State private var scope: Scope = .day
    @State private var selectedDay: Date?
    @State private var quickLog: QuickLogKind?

    private enum Scope: Hashable { case day, week }
    private static let logger = Logger(subsystem: "com.kimminung.nestory", category: "care")

    private func today(_ now: Date) -> Date { Calendar.korea.startOfDay(for: now) }

    var body: some View {
        let now = referenceDate ?? Date()
        let day = selectedDay ?? today(now)
        let entries = (child.careLogs ?? []).map(\.entry)

        ScrollView {
            VStack(alignment: .leading, spacing: NestorySpacing.l) {
                Picker("보기", selection: $scope) {
                    Text("하루").tag(Scope.day)
                    Text("일주일").tag(Scope.week)
                }
                .pickerStyle(.segmented)

                if scope == .day {
                    dayView(day: day, entries: entries, now: now)
                } else {
                    weekView(entries: entries, now: now)
                }
            }
            .padding(NestorySpacing.l)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(NestoryColor.cream)
        .navigationTitle("기록")
        .toolbar {
            ToolbarItem {
                Menu {
                    ForEach(QuickLogKind.allCases) { kind in
                        Button(action: { quickLog = kind }) { Label(kind.title, systemImage: kind.style.systemImage) }
                    }
                } label: {
                    Label("기록 추가", systemImage: "plus")
                }
            }
        }
        .sheet(item: $quickLog) { kind in
            QuickLogSheet(kind: kind, child: child, now: now)
        }
    }

    // MARK: - 하루

    @ViewBuilder
    private func dayView(day: Date, entries: [CareEntry], now: Date) -> some View {
        let summary = CareAnalyzer.summary(entries, on: day, now: now)
        let logs = logsTouching(day: day)

        HStack {
            Button("이전 날", systemImage: "chevron.left") { selectedDay = Calendar.korea.adding(days: -1, to: day) }
                .labelStyle(.iconOnly)
            Spacer()
            Text(day.formatted(Date.FormatStyle(date: .complete, time: .omitted, locale: KoreanFormat.locale, calendar: .korea, timeZone: Calendar.korea.timeZone)))
                .font(.nestory(.headline))
            Spacer()
            Button("다음 날", systemImage: "chevron.right") { selectedDay = Calendar.korea.adding(days: 1, to: day) }
                .labelStyle(.iconOnly)
                .disabled(day >= today(now))
        }
        .foregroundStyle(NestoryColor.cocoa)

        NestoryCard {
            HStack(alignment: .top) {
                Metric(title: "수유", value: "\(summary.feedingCount)회")
                Metric(title: "분유", value: "\(Int(summary.formulaMilliliters.rounded()))ml")
                Metric(title: "수면", value: DurationFormatter.spanLabel(minutes: summary.sleepMinutes))
                Metric(title: "기저귀", value: "\(summary.diaperCount)회")
            }
        }

        if logs.isEmpty {
            EmptyState(title: "기록이 없어요", message: "오른쪽 위 + 로 오늘의 첫 기록을 남겨 보세요.", systemImage: "drop.fill")
                .frame(maxWidth: .infinity)
        } else {
            NestoryCard {
                ForEach(logs) { log in
                    LogRow(log: log, now: now) { delete(log) }
                    if log.id != logs.last?.id { Divider() }
                }
            }
        }
    }

    /// 그날 하루와 겹치는 기록(자정을 넘는 수면 포함), 최근 것이 위
    private func logsTouching(day: Date) -> [CareLog] {
        let start = day
        let end = Calendar.korea.adding(days: 1, to: day)
        return (child.careLogs ?? [])
            .filter { log in
                let logEnd = log.end ?? Date.distantFuture
                return log.start < end && (log.start >= start || (log.type == .sleep && logEnd > start))
            }
            .sorted { $0.start > $1.start }
    }

    private func delete(_ log: CareLog) {
        do {
            try CareLogService.delete(log, context: modelContext)
        } catch {
            Self.logger.error("기록 삭제 실패: \(error.localizedDescription)")
        }
    }

    // MARK: - 일주일

    @ViewBuilder
    private func weekView(entries: [CareEntry], now: Date) -> some View {
        let series = CareAnalyzer.series(entries, endingOn: now, days: 7, now: now)
        let averageFeedings = Double(series.map(\.feedingCount).reduce(0, +)) / 7
        let averageSleep = series.map(\.sleepMinutes).reduce(0, +) / 7

        WeekChart(title: "수유 횟수", unit: "회", average: String(format: "하루 평균 %.1f회", averageFeedings), tint: .mint, series: series) {
            Double($0.feedingCount)
        }
        WeekChart(title: "수면 시간", unit: "시간", average: "하루 평균 \(DurationFormatter.spanLabel(minutes: averageSleep))", tint: .lavender, series: series) {
            $0.sleepMinutes / 60
        }
        WeekChart(title: "기저귀", unit: "회", average: String(format: "하루 평균 %.1f회", Double(series.map(\.diaperCount).reduce(0, +)) / 7), tint: .sky, series: series) {
            Double($0.diaperCount)
        }
    }
}

private struct Metric: View {
    let title: LocalizedStringKey
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.nestory(.caption)).foregroundStyle(NestoryColor.cocoaSoft)
            Text(value).font(.nestory(.headline, weight: .bold)).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct LogRow: View {
    let log: CareLog
    let now: Date
    let onDelete: () -> Void

    private var style: CategoryStyle { .style(for: log.type) }

    private var timeText: String {
        let format = Date.FormatStyle(date: .omitted, time: .shortened, locale: KoreanFormat.locale, calendar: .korea, timeZone: Calendar.korea.timeZone)
        guard let end = log.end, log.type == .sleep || log.type == .breastFeeding else {
            return log.start.formatted(format)
        }
        let minutes = end.timeIntervalSince(log.start) / 60
        return "\(log.start.formatted(format)) ~ \(end.formatted(format)) (\(DurationFormatter.spanLabel(minutes: minutes)))"
    }

    var body: some View {
        HStack(spacing: NestorySpacing.m) {
            Image(systemName: style.systemImage)
                .foregroundStyle(NestoryColor.onPastel)
                .frame(width: 36, height: 36)
                .background(style.color, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(log.displayTitle).font(.nestory(.body, weight: .semibold))
                Text(log.end == nil && CareLogService.timerTypes.contains(log.type) ? "\(log.start.formatted(.dateTime.hour().minute().locale(KoreanFormat.locale))) 부터 진행 중" : timeText)
                    .font(.nestory(.footnote))
                    .foregroundStyle(NestoryColor.cocoaSoft)
                if !log.note.isEmpty && log.type != .medication {
                    Text(log.note).font(.nestory(.footnote)).foregroundStyle(NestoryColor.cocoaSoft)
                }
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(NestoryColor.cocoa)
        .contextMenu { Button("삭제", role: .destructive, action: onDelete) }
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: "삭제", onDelete)
    }
}

private struct WeekChart: View {
    let title: LocalizedStringKey
    let unit: String
    let average: String
    let tint: NestoryColor
    let series: [DailyCareSummary]
    let value: (DailyCareSummary) -> Double

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.nestoryNightMode) private var night

    var body: some View {
        VStack(alignment: .leading, spacing: NestorySpacing.s) {
            HStack(alignment: .firstTextBaseline) {
                SectionTitle(title)
                Text(average).font(.nestory(.footnote)).foregroundStyle(NestoryColor.cocoaSoft)
            }
            NestoryCard {
                Chart(series, id: \.day) { day in
                    BarMark(
                        x: .value("날짜", day.day, unit: .day),
                        y: .value(unit, value(day))
                    )
                    .foregroundStyle(tint.color(in: colorScheme, night: night))
                    .cornerRadius(6)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.narrow).locale(KoreanFormat.locale), centered: true)
                    }
                }
                .frame(height: 140)
                .accessibilityLabel(Text(title))
                .accessibilityValue(average)
            }
        }
    }
}

#Preview("기록 · 하루") {
    NavigationStack {
        WithActiveChild { CareRecordsView(child: $0) }
    }
    .bornPreviewEnvironment()
}
