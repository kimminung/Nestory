import Foundation
import NestoryData
import NestoryKit
import Observation

/// 출산예정일 입력 폼의 상태(온보딩과 예정일 수정이 함께 쓴다).
@Observable
final class DueDateFormState {
    var method: DueDateMethod = .lastMenstrualPeriod
    var lastMenstrualPeriod: Date
    var scanDate: Date
    var scanWeeks = 12
    var scanDays = 0
    var transferDate: Date
    var embryoAgeDays = 5
    var directDueDate: Date

    init(now: Date = Date(), calendar: Calendar = .korea) {
        let today = calendar.startOfDay(for: now)
        lastMenstrualPeriod = calendar.adding(days: -84, to: today)      // 임신 12주쯤
        scanDate = today
        transferDate = calendar.adding(days: -28, to: today)
        directDueDate = calendar.adding(days: 196, to: today)
    }

    /// 이미 저장된 예정일을 고칠 때: 원래 입력 방식의 세부 값은 저장하지 않으므로 "직접 입력" 으로 시작한다.
    convenience init(editing dueDate: Date, now: Date = Date()) {
        self.init(now: now)
        method = .direct
        directDueDate = dueDate
    }

    func input() -> DueDateInput {
        switch method {
        case .lastMenstrualPeriod:
            .lastMenstrualPeriod(lastMenstrualPeriod)
        case .ultrasound:
            .ultrasound(scanDate: scanDate, measuredAge: GestationalAge(weeks: scanWeeks, days: scanDays))
        case .ivfTransfer:
            .ivfTransfer(date: transferDate, embryoAgeDays: embryoAgeDays)
        case .direct:
            .direct(directDueDate)
        }
    }

    func issues(now: Date) -> [DueDateInputIssue] {
        input().issues(now: now)
    }
}

extension DueDateInputIssue {
    var message: String {
        switch self {
        case .dateInFuture: "오늘보다 이후 날짜는 고를 수 없어요."
        case .dueDateTooFarInPast: "예정일이 2주 넘게 지났어요. 날짜를 다시 확인해 주세요."
        case .dueDateTooFarAhead: "예정일이 너무 멀어요. 날짜를 다시 확인해 주세요."
        case .measuredAgeOutOfRange: "초음파 주수를 다시 확인해 주세요."
        case .embryoAgeOutOfRange: "배아 일령은 1~7일 사이예요."
        }
    }
}
