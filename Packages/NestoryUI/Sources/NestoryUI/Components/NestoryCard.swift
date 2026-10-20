import SwiftUI

/// 파스텔 면 + 24pt 연속 곡률 + 따뜻한 그림자. 파스텔 fill 을 쓰면 contentColor 는 .onPastel 로.
public struct NestoryCard<Content: View>: View {
    private let fill: NestoryColor
    private let contentColor: NestoryColor
    private let content: Content

    public init(
        fill: NestoryColor = .card,
        contentColor: NestoryColor = .cocoa,
        @ViewBuilder content: () -> Content
    ) {
        self.fill = fill
        self.contentColor = contentColor
        self.content = content()
    }

    public var body: some View {
        // 여러 뷰를 넘겨도 하나의 카드가 되도록 스택으로 묶는다(수정자가 자식마다 따로 붙는 것 방지).
        VStack(alignment: .leading, spacing: NestorySpacing.xs) {
            content
        }
        .foregroundStyle(contentColor)
        .padding(NestorySpacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(fill, in: RoundedRectangle(cornerRadius: NestoryRadius.card, style: .continuous))
        .nestoryShadow()
    }
}
