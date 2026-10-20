import Foundation
import NestoryKit
import SwiftData

/// 온보딩에서 고른 아이의 상태
public enum ChildStartState: Sendable {
    /// 임신 중 — 예정일 입력 방식
    case pregnant(DueDateInput)
    /// 이미 태어남 — 출생일(출산예정일을 알면 함께)
    case born(birthDate: Date, dueDate: Date? = nil)
}

public struct NewFamilyDraft: Sendable {
    public var familyName: String
    public var guardianName: String
    public var guardianRole: GuardianRole
    public var childNickname: String
    public var isMultiple: Bool
    public var state: ChildStartState

    public init(
        familyName: String = "우리 가족",
        guardianName: String = "",
        guardianRole: GuardianRole = .mother,
        childNickname: String = "",
        isMultiple: Bool = false,
        state: ChildStartState
    ) {
        self.familyName = familyName
        self.guardianName = guardianName
        self.guardianRole = guardianRole
        self.childNickname = childNickname
        self.isMultiple = isMultiple
        self.state = state
    }
}

/// 온보딩 결과로 가족·보호자·아이(·임신)를 만들고, 예정일을 고친다.
public enum FamilySetup {
    /// 이름을 비워 뒀을 때 쓰는 기본 호칭
    public static func defaultGuardianName(for role: GuardianRole) -> String {
        switch role {
        case .mother: "엄마"
        case .father: "아빠"
        case .other: "보호자"
        }
    }

    public static let defaultChildNickname = "우리 아기"

    @discardableResult
    public static func create(
        _ draft: NewFamilyDraft,
        context: ModelContext,
        calendar: Calendar = .korea
    ) throws -> Child {
        let family = Family(name: trimmed(draft.familyName, fallback: "우리 가족"))
        let guardian = Guardian(
            displayName: trimmed(draft.guardianName, fallback: defaultGuardianName(for: draft.guardianRole)),
            role: draft.guardianRole
        )
        let child = Child(nickname: trimmed(draft.childNickname, fallback: defaultChildNickname))
        child.isMultiple = draft.isMultiple

        context.insert(family)
        context.insert(guardian)
        context.insert(child)
        guardian.family = family
        child.family = family

        switch draft.state {
        case .pregnant(let input):
            applyDueDate(input, to: child, context: context, calendar: calendar)
        case .born(let birthDate, let dueDate):
            child.birthDate = calendar.startOfDay(for: birthDate)
            child.dueDate = dueDate.map { calendar.startOfDay(for: $0) }
        }

        try context.save()
        return child
    }

    /// 예정일 입력 방식·값을 아이와 임신 정보에 반영한다. (이후 `PrenatalPlanSync` 로 일정을 맞춘다)
    public static func updateDueDate(
        _ input: DueDateInput,
        for child: Child,
        context: ModelContext,
        calendar: Calendar = .korea
    ) throws {
        applyDueDate(input, to: child, context: context, calendar: calendar)
        try context.save()
    }

    /// "아이가 태어났어요": 출생일을 기록한다. 이후 `PostnatalPlanSync` 로 출생 후 일정을 만든다.
    public static func recordBirth(
        on date: Date,
        for child: Child,
        context: ModelContext,
        calendar: Calendar = .korea
    ) throws {
        child.birthDate = calendar.startOfDay(for: date)
        try context.save()
    }

    private static func applyDueDate(
        _ input: DueDateInput,
        to child: Child,
        context: ModelContext,
        calendar: Calendar
    ) {
        let due = input.dueDate(calendar: calendar)
        let pregnancy: Pregnancy
        if let existing = child.pregnancy {
            pregnancy = existing
        } else {
            pregnancy = Pregnancy()
            context.insert(pregnancy)
            pregnancy.child = child
        }
        pregnancy.dueDate = due
        pregnancy.method = input.method
        pregnancy.lmpDate = calendar.startOfDay(
            for: input.lastMenstrualPeriod ?? PregnancyCalculator.lastMenstrualPeriod(fromDueDate: due, calendar: calendar)
        )
        child.dueDate = due
    }

    private static func trimmed(_ text: String, fallback: String) -> String {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? fallback : value
    }
}
