import Foundation

/// 아기 월령 단계. 태어난 날을 "생후 1일"로 센다(백일 = 생후 100일째 = 출생일 + 99일).
public enum InfantAgeStage: Hashable, Sendable {
    case beforeBirth
    case days(Int)
    case months(Int)
    case yearsMonths(years: Int, months: Int)
}

/// 한국어 나이·D-day 표기
public enum AgeFormatter {
    /// "20주 3일", 0일이면 "20주"
    public static func pregnancyLabel(_ age: GestationalAge) -> String {
        age.days == 0 ? "\(age.weeks)주" : "\(age.weeks)주 \(age.days)일"
    }

    /// 남은 일수 > 0: "D-137", 0: "D-Day", 지남: "D+3"
    public static func dDayLabel(daysUntil: Int) -> String {
        switch daysUntil {
        case 1...: "D-\(daysUntil)"
        case 0: "D-Day"
        default: "D+\(-daysUntil)"
        }
    }

    /// 24개월 전까지는 개월 수, 이후에는 만 나이. 첫 한 달은 일 수.
    public static func infantStage(birth: Date, on date: Date, calendar: Calendar = .korea) -> InfantAgeStage {
        let birthDay = calendar.startOfDay(for: birth)
        let day = calendar.startOfDay(for: date)
        guard day >= birthDay else { return .beforeBirth }

        let parts = calendar.dateComponents([.year, .month], from: birthDay, to: day)
        let totalMonths = (parts.year ?? 0) * 12 + (parts.month ?? 0)
        switch totalMonths {
        case 0: return .days(calendar.daysBetween(birthDay, day) + 1)
        case 1..<24: return .months(totalMonths)
        default: return .yearsMonths(years: totalMonths / 12, months: totalMonths % 12)
        }
    }

    /// "생후 12일", "만 4개월", "만 2세 3개월", 출생 전이면 "출생 전"
    public static func infantLabel(birth: Date, on date: Date, calendar: Calendar = .korea) -> String {
        switch infantStage(birth: birth, on: date, calendar: calendar) {
        case .beforeBirth: "출생 전"
        case .days(let days): "생후 \(days)일"
        case .months(let months): "만 \(months)개월"
        case .yearsMonths(let years, let months):
            months == 0 ? "만 \(years)세" : "만 \(years)세 \(months)개월"
        }
    }

    /// 백일(생후 100일째)
    public static func hundredthDay(birth: Date, calendar: Calendar = .korea) -> Date {
        calendar.adding(days: 99, to: calendar.startOfDay(for: birth))
    }

    /// 돌(첫 생일)
    public static func firstBirthday(birth: Date, calendar: Calendar = .korea) -> Date {
        calendar.date(byAdding: .year, value: 1, to: calendar.startOfDay(for: birth)) ?? birth
    }
}
