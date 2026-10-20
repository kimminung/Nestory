import Foundation
import NestoryData
import NestoryKit
import Observation

@Observable
final class OnboardingModel {
    enum Step: Int, CaseIterable {
        case welcome, status, details, names, notifications
    }

    enum Status {
        case pregnant, born
    }

    var step: Step = .welcome
    var status: Status = .pregnant
    var dueDateForm: DueDateFormState
    var birthDate: Date
    var nickname = ""
    var guardianName = ""
    var guardianRole: GuardianRole = .mother
    var isMultiple = false
    var wantsNotifications = true

    let now: Date

    init(now: Date = Date()) {
        self.now = now
        dueDateForm = DueDateFormState(now: now)
        birthDate = Calendar.korea.startOfDay(for: now)
    }

    var issues: [DueDateInputIssue] {
        status == .pregnant ? dueDateForm.issues(now: now) : []
    }

    var canAdvance: Bool {
        step == .details ? issues.isEmpty : true
    }

    var isFirstStep: Bool { step == .welcome }
    var isLastStep: Bool { step == .notifications }

    func next() {
        guard canAdvance, let following = Step(rawValue: step.rawValue + 1) else { return }
        step = following
    }

    func back() {
        guard let previous = Step(rawValue: step.rawValue - 1) else { return }
        step = previous
    }

    func draft() -> NewFamilyDraft {
        let state: ChildStartState = switch status {
        case .pregnant: .pregnant(dueDateForm.input())
        case .born: .born(birthDate: birthDate)
        }
        return NewFamilyDraft(
            guardianName: guardianName,
            guardianRole: guardianRole,
            childNickname: nickname,
            isMultiple: isMultiple,
            state: state
        )
    }
}
