import Foundation

/// 한국어(ko_KR) 표기 유틸. 날짜·금액은 항상 이 로케일로 만든다.
public enum KoreanFormat {
    public static let locale = Locale(identifier: "ko_KR")

    /// 예: 1000000 → "₩1,000,000"
    public static func won(_ amount: Int) -> String {
        Decimal(amount).formatted(
            .currency(code: "KRW").locale(locale).precision(.fractionLength(0))
        )
    }

    /// 예: "2026년 10월 20일"
    public static func longDate(_ date: Date, calendar: Calendar = .current) -> String {
        date.formatted(
            Date.FormatStyle(
                date: .long, time: .none,
                locale: locale, calendar: calendar, timeZone: calendar.timeZone
            )
        )
    }
}
