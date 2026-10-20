import Foundation
import NestoryKit
import SwiftData

/// 육아 기록 생성·타이머·삭제
public enum CareLogService {
    /// 시작/끝을 눌러 재는 종류
    public static let timerTypes: Set<CareLogType> = [.breastFeeding, .sleep]

    /// 한 번에 기록(분유, 기저귀, 체온, 투약, 이미 끝난 수유·수면 등)
    @discardableResult
    public static func log(
        _ type: CareLogType,
        for child: Child,
        start: Date,
        end: Date? = nil,
        amount: Double? = nil,
        unit: CareUnit? = nil,
        detail: String? = nil,
        note: String = "",
        loggedBy guardianID: UUID? = nil,
        context: ModelContext
    ) throws -> CareLog {
        let log = CareLog(type: type, start: start)
        log.end = end
        log.amount = amount
        log.unit = unit
        log.detailRaw = detail
        log.note = note
        log.loggedByGuardianID = guardianID
        context.insert(log)
        log.child = child
        try context.save()
        return log
    }

    /// 타이머 시작. 같은 종류가 이미 진행 중이면 새로 만들지 않고 그것을 돌려준다.
    @discardableResult
    public static func startTimer(
        _ type: CareLogType,
        for child: Child,
        at start: Date,
        detail: String? = nil,
        loggedBy guardianID: UUID? = nil,
        context: ModelContext
    ) throws -> CareLog {
        precondition(timerTypes.contains(type), "타이머를 지원하지 않는 종류: \(type)")
        if let running = activeTimers(for: child).first(where: { $0.type == type }) { return running }
        return try log(type, for: child, start: start, detail: detail, loggedBy: guardianID, context: context)
    }

    /// 타이머 종료. 끝 시각은 시작보다 앞설 수 없다. 모유 수유는 걸린 분을 `amount` 로 남긴다.
    public static func stopTimer(_ log: CareLog, at end: Date, context: ModelContext) throws {
        guard log.end == nil else { return }
        let stop = max(end, log.start)
        log.end = stop
        if log.type == .breastFeeding {
            log.amount = (stop.timeIntervalSince(log.start) / 60 * 10).rounded() / 10
            log.unit = .minutes
        }
        try context.save()
    }

    /// 진행 중인 타이머들(시작이 가장 오래된 순)
    public static func activeTimers(for child: Child) -> [CareLog] {
        (child.careLogs ?? [])
            .filter { $0.end == nil && timerTypes.contains($0.type) }
            .sorted { $0.start < $1.start }
    }

    public static func delete(_ log: CareLog, context: ModelContext) throws {
        context.delete(log)
        try context.save()
    }
}

/// 예방접종 완료 기록. 일정은 저장하지 않고 `VaccineScheduler` 가 매번 계산하며, 여기에는 *맞은 것*만 남긴다.
public enum VaccinationService {
    public static func complete(
        code: String, doseNo: Int, on date: Date, place: String? = nil,
        for child: Child, context: ModelContext, calendar: Calendar = .korea
    ) throws {
        let day = calendar.startOfDay(for: date)
        if let existing = (child.vaccinations ?? []).first(where: { $0.vaccineCode == code && $0.doseNo == doseNo }) {
            existing.doneDate = day
            existing.place = place ?? existing.place
        } else {
            let record = Vaccination(vaccineCode: code, doseNo: doseNo)
            record.doneDate = day
            record.place = place
            context.insert(record)
            record.child = child
        }
        try context.save()
    }

    public static func undo(code: String, doseNo: Int, for child: Child, context: ModelContext) throws {
        for record in (child.vaccinations ?? []) where record.vaccineCode == code && record.doseNo == doseNo {
            context.delete(record)
        }
        try context.save()
    }

    /// 완료한 접종만 스케줄러 입력으로
    public static func records(for child: Child) -> [VaccineDoseRecord] {
        (child.vaccinations ?? []).compactMap { record in
            record.doneDate.map { VaccineDoseRecord(code: record.vaccineCode, doseNo: record.doseNo, date: $0) }
        }
    }
}
