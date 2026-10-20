import Foundation

public enum DueDateInputIssue: Hashable, Sendable {
    /// LMP·초음파일·이식일이 오늘보다 미래
    case dateInFuture
    /// 계산된 예정일이 이미 2주 넘게 지남
    case dueDateTooFarInPast
    /// 계산된 예정일이 임신 가능 기간(280일)보다 먼 미래
    case dueDateTooFarAhead
    /// 초음파로 잰 주수가 0~42주를 벗어남
    case measuredAgeOutOfRange
    /// 이식한 배아 일령이 1~7일을 벗어남
    case embryoAgeOutOfRange
}

/// 온보딩에서 사용자가 고르는 예정일 입력 방식 4가지
public enum DueDateInput: Hashable, Sendable {
    case lastMenstrualPeriod(Date)
    case ultrasound(scanDate: Date, measuredAge: GestationalAge)
    case ivfTransfer(date: Date, embryoAgeDays: Int)
    /// 병원에서 들은 예정일
    case direct(Date)

    public var method: DueDateMethod {
        switch self {
        case .lastMenstrualPeriod: .lastMenstrualPeriod
        case .ultrasound: .ultrasound
        case .ivfTransfer: .ivfTransfer
        case .direct: .direct
        }
    }

    public func dueDate(calendar: Calendar = .korea) -> Date {
        switch self {
        case .lastMenstrualPeriod(let lmp):
            PregnancyCalculator.dueDate(lastMenstrualPeriod: lmp, calendar: calendar)
        case .ultrasound(let scan, let age):
            PregnancyCalculator.dueDate(ultrasoundDate: scan, measuredAge: age, calendar: calendar)
        case .ivfTransfer(let date, let embryoAge):
            PregnancyCalculator.dueDate(ivfTransferDate: date, embryoAgeDays: embryoAge, calendar: calendar)
        case .direct(let due):
            calendar.startOfDay(for: due)
        }
    }

    /// LMP 를 직접 입력한 경우에만 값이 있다(그 외에는 예정일에서 유도한다).
    public var lastMenstrualPeriod: Date? {
        if case .lastMenstrualPeriod(let lmp) = self { return lmp }
        return nil
    }

    public func issues(now: Date, calendar: Calendar = .korea) -> [DueDateInputIssue] {
        let today = calendar.startOfDay(for: now)
        var issues: [DueDateInputIssue] = []

        switch self {
        case .lastMenstrualPeriod(let date):
            if calendar.startOfDay(for: date) > today { issues.append(.dateInFuture) }
        case .ultrasound(let scan, let age):
            if calendar.startOfDay(for: scan) > today { issues.append(.dateInFuture) }
            if age.weeks > 42 { issues.append(.measuredAgeOutOfRange) }
        case .ivfTransfer(let date, let embryoAge):
            if calendar.startOfDay(for: date) > today { issues.append(.dateInFuture) }
            if !(1...7).contains(embryoAge) { issues.append(.embryoAgeOutOfRange) }
        case .direct:
            break
        }

        let untilDue = calendar.daysBetween(today, dueDate(calendar: calendar))
        if untilDue < -14 { issues.append(.dueDateTooFarInPast) }
        if untilDue > PregnancyCalculator.fullTermDays { issues.append(.dueDateTooFarAhead) }
        return issues
    }
}

/// 홈 화면 히어로에 필요한 임신 현황 요약
public struct PregnancySummary: Hashable, Sendable {
    public let dueDate: Date
    /// LMP 이전이면 nil
    public let age: GestationalAge?
    /// 지났으면 음수
    public let daysUntilDue: Int
    public let trimester: Trimester?
    /// 0…1 (만삭 280일 기준)
    public let progress: Double

    public var isPastDue: Bool { daysUntilDue < 0 }

    public static func make(dueDate: Date, now: Date, calendar: Calendar = .korea) -> PregnancySummary {
        let age = PregnancyCalculator.gestationalAge(on: now, dueDate: dueDate, calendar: calendar)
        let progress = age.map { min(1, Double($0.totalDays) / Double(PregnancyCalculator.fullTermDays)) } ?? 0
        return PregnancySummary(
            dueDate: calendar.startOfDay(for: dueDate),
            age: age,
            daysUntilDue: PregnancyCalculator.daysUntilDue(from: now, dueDate: dueDate, calendar: calendar),
            trimester: age.map(PregnancyCalculator.trimester(for:)),
            progress: progress
        )
    }
}
