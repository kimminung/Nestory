import Foundation
import Testing
@testable import NestoryKit

struct CareAnalyzerTests {
    private func at(_ month: Int, _ d: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        kst.date(from: DateComponents(year: 2026, month: month, day: d, hour: hour, minute: minute))!
    }

    private var now: Date { at(10, 20, 23, 0) }

    @Test func countsFeedingsAndTotals() {
        let entries = [
            CareEntry(type: .formula, start: at(10, 20, 7), amount: 120, unit: .milliliters),
            CareEntry(type: .formula, start: at(10, 20, 11), amount: 4, unit: .ounces),            // 4oz ≈ 118.3ml
            CareEntry(type: .breastFeeding, start: at(10, 20, 9), end: at(10, 20, 9, 20)),         // 20분 (시각 차)
            CareEntry(type: .breastFeeding, start: at(10, 20, 15), amount: 15, unit: .minutes),    // 15분 (기록된 값)
            CareEntry(type: .solidFood, start: at(10, 20, 12)),
            CareEntry(type: .formula, start: at(10, 19, 23), amount: 999, unit: .milliliters),     // 전날
        ]
        let summary = CareAnalyzer.summary(entries, on: at(10, 20, 0), now: now)
        #expect(summary.feedingCount == 5)
        #expect(abs(summary.formulaMilliliters - (120 + 4 * 29.5735)) < 1e-9)
        #expect(summary.breastMinutes == 35)
    }

    @Test func diaperKindsAreCounted() {
        let entries = [
            CareEntry(type: .diaper, start: at(10, 20, 6), detail: DiaperKind.wet.rawValue),
            CareEntry(type: .diaper, start: at(10, 20, 8), detail: DiaperKind.dirty.rawValue),
            CareEntry(type: .diaper, start: at(10, 20, 10), detail: DiaperKind.both.rawValue),
            CareEntry(type: .diaper, start: at(10, 20, 12)),    // 종류 미기록 = 소변으로 본다
        ]
        let summary = CareAnalyzer.summary(entries, on: at(10, 20, 0), now: now)
        #expect(summary.wetDiapers == 3)
        #expect(summary.dirtyDiapers == 2)
        #expect(summary.diaperCount == 5)
    }

    @Test func sleepIsSplitAtMidnight() {
        // 10/19 22:00 ~ 10/20 06:00 (8시간)
        let night = CareEntry(type: .sleep, start: at(10, 19, 22), end: at(10, 20, 6))
        let nap = CareEntry(type: .sleep, start: at(10, 20, 13), end: at(10, 20, 14, 30))
        let entries = [night, nap]

        let day20 = CareAnalyzer.summary(entries, on: at(10, 20, 0), now: now)
        #expect(day20.sleepMinutes == 6 * 60 + 90)       // 0~6시 + 낮잠 1.5시간
        #expect(day20.sleepSessions == 1)                // 시작한 날에만 한 세션으로 센다(밤잠은 19일)

        let day19 = CareAnalyzer.summary(entries, on: at(10, 19, 0), now: now)
        #expect(day19.sleepMinutes == 2 * 60)            // 22~24시
        #expect(day19.sleepSessions == 1)
    }

    @Test func ongoingSleepRunsUntilNow() {
        let entries = [CareEntry(type: .sleep, start: at(10, 20, 21))]    // 아직 자는 중
        let summary = CareAnalyzer.summary(entries, on: at(10, 20, 0), now: at(10, 20, 22, 30))
        #expect(summary.sleepMinutes == 90)
        #expect(entries[0].isOngoing)
    }

    @Test func temperatureAndMedication() {
        let entries = [
            CareEntry(type: .temperature, start: at(10, 20, 8), amount: 37.2, unit: .celsius),
            CareEntry(type: .temperature, start: at(10, 20, 14), amount: 100.4, unit: .fahrenheit),   // 38.0℃
            CareEntry(type: .medication, start: at(10, 20, 14, 5)),
        ]
        let summary = CareAnalyzer.summary(entries, on: at(10, 20, 0), now: now)
        #expect(abs((summary.maxTemperatureCelsius ?? 0) - 38.0) < 0.01)
        #expect(summary.medicationCount == 1)
        #expect(CareAnalyzer.summary([], on: at(10, 20, 0), now: now).maxTemperatureCelsius == nil)
    }

    @Test func seriesIsOldestFirstAndCoversRequestedDays() {
        let entries = [
            CareEntry(type: .formula, start: at(10, 18, 9), amount: 100, unit: .milliliters),
            CareEntry(type: .formula, start: at(10, 20, 9), amount: 150, unit: .milliliters),
        ]
        let series = CareAnalyzer.series(entries, endingOn: at(10, 20, 12), days: 3, now: now)
        #expect(series.map(\.day) == [at(10, 18, 0), at(10, 19, 0), at(10, 20, 0)])
        #expect(series.map(\.formulaMilliliters) == [100, 0, 150])
        #expect(CareAnalyzer.series(entries, endingOn: at(10, 20, 0), days: 0, now: now).isEmpty)
    }

    @Test func lastEntryIgnoresFutureAndPicksLatestStart() {
        let entries = [
            CareEntry(type: .formula, start: at(10, 20, 7)),
            CareEntry(type: .breastFeeding, start: at(10, 20, 10)),
            CareEntry(type: .formula, start: at(10, 21, 7)),        // 미래
            CareEntry(type: .sleep, start: at(10, 20, 11)),
        ]
        let last = CareAnalyzer.lastEntry(of: [.formula, .breastFeeding], in: entries, now: now)
        #expect(last?.start == at(10, 20, 10))
        #expect(CareAnalyzer.lastEntry(of: [.diaper], in: entries, now: now) == nil)
    }

    @Test func formulaDefaultRemembersLastAmount() {
        #expect(QuickLogDefaults.formulaMilliliters(from: []) == 120)
        let entries = [
            CareEntry(type: .formula, start: at(10, 19, 7), amount: 90, unit: .milliliters),
            CareEntry(type: .formula, start: at(10, 20, 7), amount: 4, unit: .ounces),
            CareEntry(type: .breastFeeding, start: at(10, 20, 9), amount: 999, unit: .minutes),
        ]
        #expect(abs(QuickLogDefaults.formulaMilliliters(from: entries) - 4 * 29.5735) < 1e-9)
    }
}

struct DurationFormatterTests {
    @Test(arguments: [
        (0.0, "방금"), (59, "방금"), (60, "1분 전"), (3599, "59분 전"),
        (3600, "1시간 전"), (3660, "1시간 1분 전"), (86399, "23시간 59분 전"),
        (86400, "1일 전"), (172_800, "2일 전"), (-30, "방금"),
    ])
    func agoLabels(seconds: Double, expected: String) {
        #expect(DurationFormatter.agoLabel(seconds) == expected)
    }

    @Test(arguments: [(35.0, "35분"), (60, "1시간"), (80, "1시간 20분"), (0, "0분")])
    func spanLabels(minutes: Double, expected: String) {
        #expect(DurationFormatter.spanLabel(minutes: minutes) == expected)
    }
}
