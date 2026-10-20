import NestoryData
import NestoryKit
import NestoryUI
import SwiftUI

/// 구역(탭/사이드바 항목)에 맞는 실제 화면
struct SectionView: View {
    let section: AppSection

    var body: some View {
        switch section {
        case .home: HomeView()
        case .records: RecordsHomeView()
        case .schedule: ScheduleHomeView()
        case .leave: BenefitsView()
        case .more: MoreView()
        }
    }
}

/// 홈: 임신 중이면 임신 홈, 태어났다면(M3 전까지) 안내
struct HomeView: View {
    var body: some View {
        WithActiveChild { child in
            if child.birthDate == nil {
                PregnancyHomeView(child: child)
            } else {
                SectionPlaceholderView(section: .home)
            }
        }
    }
}

/// 기록: 임신 중에는 태동·진통, 육아 기록은 M3
struct RecordsHomeView: View {
    var body: some View {
        WithActiveChild { child in
            if child.birthDate == nil {
                List {
                    NavigationLink {
                        KickCounterView(child: child)
                    } label: {
                        RowLabel(title: "태동 카운터", subtitle: "아기가 움직일 때마다 세어요", systemImage: "hand.tap.fill", tint: .mint)
                    }
                    NavigationLink {
                        ContractionTimerView()
                    } label: {
                        RowLabel(title: "진통 타이머", subtitle: "간격과 지속 시간을 재요", systemImage: "timer", tint: .sky)
                    }
                }
                .listRowBackground(Rectangle().fill(NestoryColor.card))
                .scrollContentBackground(.hidden)
                .background(NestoryColor.cream)
                .navigationTitle("기록")
            } else {
                SectionPlaceholderView(section: .records)
            }
        }
    }
}

/// 일정: 임신 중에는 타임라인·검사·체크리스트, 통합 캘린더는 M4
struct ScheduleHomeView: View {
    var body: some View {
        WithActiveChild { child in
            if child.birthDate == nil {
                List {
                    NavigationLink {
                        PregnancyTimelineView(child: child)
                    } label: {
                        RowLabel(title: "주차 타임라인", subtitle: "주차별 아기 크기와 할 일", systemImage: "timeline.selection", tint: .lavender)
                    }
                    NavigationLink {
                        CheckupsView(child: child)
                    } label: {
                        RowLabel(title: "산전 검사", subtitle: "권장 시기와 완료 체크", systemImage: "stethoscope", tint: .rose)
                    }
                    NavigationLink {
                        ChecklistView(child: child)
                    } label: {
                        RowLabel(title: "체크리스트", subtitle: "출산 준비물·입원 가방", systemImage: "checklist", tint: .butter)
                    }
                }
                .scrollContentBackground(.hidden)
                .background(NestoryColor.cream)
                .navigationTitle("일정")
            } else {
                SectionPlaceholderView(section: .schedule)
            }
        }
    }
}

private struct RowLabel: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let systemImage: String
    let tint: NestoryColor

    var body: some View {
        HStack(spacing: NestorySpacing.m) {
            Image(systemName: systemImage)
                .foregroundStyle(NestoryColor.onPastel)
                .frame(width: 40, height: 40)
                .background(tint, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.nestory(.body, weight: .semibold))
                Text(subtitle).font(.nestory(.footnote)).foregroundStyle(NestoryColor.cocoaSoft)
            }
        }
        .foregroundStyle(NestoryColor.cocoa)
        .frame(minHeight: NestoryHitTarget.minimum)
    }
}

#Preview("기록 탭") {
    NavigationStack { RecordsHomeView() }
        .previewEnvironment()
}

#Preview("일정 탭") {
    NavigationStack { ScheduleHomeView() }
        .previewEnvironment()
}
