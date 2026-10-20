import NestoryUI
import SwiftUI

/// 폼팩터에 따라 내비게이션을 바꾸는 앱 셸.
/// - compact(iPhone 세로 등): 하단 탭
/// - regular(iPad, Mac, visionOS 등): 사이드바 + 상세
struct RootView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selection: AppSection = .home

    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                compactLayout
            } else {
                regularLayout
            }
        }
        .tint(NestoryColor.peachDeep)
    }

    private var compactLayout: some View {
        TabView(selection: $selection) {
            ForEach(AppSection.allCases) { section in
                Tab(section.title, systemImage: section.systemImage, value: section) {
                    NavigationStack {
                        SectionPlaceholderView(section: section)
                    }
                }
            }
        }
    }

    private var regularLayout: some View {
        NavigationSplitView {
            List(selection: sidebarSelection) {
                ForEach(AppSection.allCases) { section in
                    Label(section.title, systemImage: section.systemImage)
                        .tag(section)
                }
            }
            .navigationTitle("Nestory")
            #if os(macOS)
            .navigationSplitViewColumnWidth(min: 200, ideal: 220)
            #endif
        } detail: {
            NavigationStack {
                SectionPlaceholderView(section: selection)
            }
        }
    }

    /// List 의 선택은 옵셔널이지만 앱의 선택값은 항상 존재하므로 nil 은 무시한다.
    private var sidebarSelection: Binding<AppSection?> {
        Binding(
            get: { selection },
            set: { newValue in
                if let newValue { selection = newValue }
            }
        )
    }
}

#Preview("루트") {
    RootView()
}
