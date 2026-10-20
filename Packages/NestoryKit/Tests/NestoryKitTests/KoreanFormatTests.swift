import Foundation
import Testing
@testable import NestoryKit

struct KoreanFormatTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }

    @Test func formatsWonWithoutFraction() {
        #expect(KoreanFormat.won(1_000_000) == "₩1,000,000")
        #expect(KoreanFormat.won(0) == "₩0")
    }

    @Test func formatsLongDateInKorean() throws {
        let date = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 10, day: 20, hour: 12))
        )
        #expect(KoreanFormat.longDate(date, calendar: calendar) == "2026년 10월 20일")
    }

    @Test func enumRawValuesAreStable() {
        // 저장된 rawValue 는 바꾸면 안 된다 — 변경 시 이 테스트가 깨져 알려 준다.
        #expect(CareLogType.breastFeeding.rawValue == "breastFeeding")
        #expect(LeaveKind.parentalSixPlusSix.rawValue == "parentalSixPlusSix")
        #expect(SideJobStatus.interview.rawValue == "interview")
    }
}
