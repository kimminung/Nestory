import NestoryUI
import SwiftUI

/// 구현 전 구역의 자리 표시 화면. 마일스톤마다 실제 화면으로 교체된다.
struct SectionPlaceholderView: View {
    let section: AppSection

    var body: some View {
        VStack(spacing: NestorySpacing.xl) {
            EmptyState(
                title: section.placeholderTitle,
                message: section.placeholderMessage,
                systemImage: section.systemImage
            )
            #if DEBUG
            if section == .more {
                NavigationLink("디자인 갤러리 (개발용)") {
                    NestoryComponentGallery()
                        .navigationTitle("디자인 갤러리")
                }
                .buttonStyle(.nestoryPrimary)
            }
            #endif
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(NestoryColor.cream)
        .navigationTitle(section.title)
    }
}

#Preview("자리 표시 — 홈") {
    NavigationStack {
        SectionPlaceholderView(section: .home)
    }
}

#Preview("컴포넌트 갤러리") {
    NestoryComponentGallery()
}
