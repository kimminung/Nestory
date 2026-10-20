import NestoryUI
import SwiftUI

/// 앱의 최상위 구역. iPhone 은 탭, iPad/Mac/visionOS 는 사이드바로 같은 목록을 보여 준다.
enum AppSection: String, CaseIterable, Identifiable, Hashable {
    case home, records, schedule, leave, more

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .home: "홈"
        case .records: "기록"
        case .schedule: "일정"
        case .leave: "제도·휴직"
        case .more: "더보기"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house.fill"
        case .records: "drop.fill"
        case .schedule: "calendar"
        case .leave: "briefcase.fill"
        case .more: "ellipsis.circle.fill"
        }
    }

    /// 아직 구현 전인 구역의 안내 문구 (각 마일스톤에서 실제 화면으로 교체)
    var placeholderTitle: LocalizedStringKey {
        switch self {
        case .home: "오늘의 요약이 곧 여기에 나타나요"
        case .records: "육아 기록이 곧 열려요"
        case .schedule: "가족 일정이 곧 열려요"
        case .leave: "휴가·휴직 계획이 곧 열려요"
        case .more: "가족·설정이 곧 열려요"
        }
    }

    var placeholderMessage: LocalizedStringKey {
        switch self {
        case .home: "임신 주차와 다음 할 일을 한눈에 보여 드릴게요."
        case .records: "수유·수면·기저귀를 세 번 탭으로 남겨요."
        case .schedule: "검진·접종·휴직 일정을 한 타임라인에 모아요."
        case .leave: "부부 휴직을 함께 계획하고 예상 소득을 비교해요."
        case .more: "보호자 초대, 잠금, 내보내기를 여기서 설정해요."
        }
    }
}
