import NestoryKit
import SwiftUI

/// 컴포넌트 갤러리: 3폼팩터 × 라이트/다크/밤 모드 시각 점검용.
public struct NestoryComponentGallery: View {
    @State private var selectedChip = "재택"

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NestorySpacing.xl) {
                section("카드") {
                    NestoryCard {
                        Text("임신 20주 3일")
                            .font(.nestory(.title2, weight: .bold))
                        Text("출산까지 D-137")
                            .font(.nestory(.body))
                            .foregroundStyle(NestoryColor.cocoaSoft)
                    }
                    NestoryCard(fill: .mint, contentColor: .onPastel) {
                        Label("마지막 수유 2시간 전", systemImage: "drop.fill")
                            .font(.nestory(.headline))
                    }
                }

                section("빠른 기록") {
                    HStack(spacing: NestorySpacing.m) {
                        ForEach(quickLogs, id: \.title) { item in
                            QuickLogButton(
                                LocalizedStringKey(item.title),
                                systemImage: item.style.systemImage,
                                tint: item.style.color,
                                action: {}
                            )
                        }
                    }
                }

                section("칩") {
                    HStack(spacing: NestorySpacing.s) {
                        ForEach(["재택", "단시간", "야간 제외"], id: \.self) { title in
                            NestoryChip(LocalizedStringKey(title), isSelected: selectedChip == title) {
                                selectedChip = title
                            }
                        }
                    }
                }

                section("고지 배너") {
                    DisclaimerBanner(
                        effectiveDate: Date(timeIntervalSince1970: 1_792_000_000),
                        sourceName: "고용24",
                        sourceURL: URL(string: "https://www.work24.go.kr")
                    )
                }

                section("빈 화면") {
                    EmptyState(
                        title: "아직 기록이 없어요",
                        message: "첫 수유를 기록해 볼까요?",
                        systemImage: "drop.fill",
                        actionTitle: "기록하기",
                        action: {}
                    )
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(NestorySpacing.l)
        }
        .background(NestoryColor.cream)
    }

    private var quickLogs: [(title: String, style: CategoryStyle)] {
        [
            ("수유", .style(for: CareLogType.formula)),
            ("수면", .style(for: CareLogType.sleep)),
            ("기저귀", .style(for: CareLogType.diaper)),
        ]
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: NestorySpacing.m) {
            Text(title)
                .font(.nestory(.footnote, weight: .bold))
                .foregroundStyle(NestoryColor.cocoaSoft)
            content()
        }
    }
}

#Preview("라이트") {
    NestoryComponentGallery()
}

#Preview("다크") {
    NestoryComponentGallery()
        .preferredColorScheme(.dark)
}

#Preview("밤 모드") {
    NestoryComponentGallery()
        .preferredColorScheme(.dark)
        .environment(\.nestoryNightMode, true)
}

#Preview("큰 글자(AX3)") {
    NestoryComponentGallery()
        .dynamicTypeSize(.accessibility3)
}
