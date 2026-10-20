import Foundation

extension Calendar {
    /// 한국 표준시 기준 그레고리력. 일 단위 계산의 기본값이며, 테스트도 이 달력을 쓴다.
    public static let korea: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        calendar.locale = KoreanFormat.locale
        return calendar
    }()

    /// 두 날짜 사이의 달력상 일수(시각은 무시). `end` 가 더 늦으면 양수.
    public func daysBetween(_ start: Date, _ end: Date) -> Int {
        dateComponents([.day], from: startOfDay(for: start), to: startOfDay(for: end)).day ?? 0
    }

    public func adding(days: Int, to date: Date) -> Date {
        self.date(byAdding: .day, value: days, to: date) ?? date
    }

    /// `[start, end]` 양끝을 포함한 일수. end < start 이면 0.
    public func inclusiveDays(from start: Date, to end: Date) -> Int {
        max(0, daysBetween(start, end) + 1)
    }
}
