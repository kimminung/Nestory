import Foundation

// 저장소에는 rawValue(String)로 저장된다. 기존 case 의 rawValue 는 바꾸지 않는다(동기화·마이그레이션 호환).

public enum GuardianRole: String, Codable, CaseIterable, Sendable {
    case mother, father, other
}

public enum ChildSex: String, Codable, CaseIterable, Sendable {
    case unknown, female, male
}

/// 출산예정일을 계산한 기준
public enum DueDateMethod: String, Codable, CaseIterable, Sendable {
    case lastMenstrualPeriod, ultrasound, ivfTransfer
    /// 병원에서 들은 예정일을 그대로 입력
    case direct
}

public enum CareLogType: String, Codable, CaseIterable, Sendable {
    case breastFeeding, formula, solidFood, sleep, diaper, temperature, medication
}

public enum CareUnit: String, Codable, CaseIterable, Sendable {
    case minutes, milliliters, ounces, grams, celsius, fahrenheit, count
}

public enum EmploymentType: String, Codable, CaseIterable, Sendable {
    case regular, contract, publicServant, dispatch, selfEmployed, freelancer
}

public enum LeaveKind: String, Codable, CaseIterable, Sendable {
    case maternity, paternity, parental, parentalSixPlusSix, reducedHours, familyCare, annual
}

public enum SideJobStatus: String, Codable, CaseIterable, Sendable {
    case interested, applied, interview, confirmed, ended
}

public enum PayUnit: String, Codable, CaseIterable, Sendable {
    case hourly, daily, monthly, perTask
}

public enum TaskCategory: String, Codable, CaseIterable, Sendable {
    case prenatalCheckup, voucher, preparation, administration
    case vaccination, healthCheckup, leave, sideWork, custom
}

public enum DocumentKind: String, Codable, CaseIterable, Sendable {
    case leaveApplication, certificate, medical, other
}
