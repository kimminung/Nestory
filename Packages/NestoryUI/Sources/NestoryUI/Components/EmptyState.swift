import SwiftUI

/// 빈 화면: 일러스트 + 한 줄 안내 + 주 버튼.
/// 일러스트는 지금은 SF Symbol 임시 아이콘이며, 마스코트 스티커(D7) 반입 후 교체한다.
public struct EmptyState: View {
    private let title: LocalizedStringKey
    private let message: LocalizedStringKey
    private let systemImage: String
    private let actionTitle: LocalizedStringKey?
    private let action: (() -> Void)?

    public init(
        title: LocalizedStringKey,
        message: LocalizedStringKey,
        systemImage: String,
        actionTitle: LocalizedStringKey? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        VStack(spacing: NestorySpacing.l) {
            Image(systemName: systemImage)
                .font(.nestory(.largeTitle, weight: .semibold))
                .foregroundStyle(NestoryColor.onPastel)
                .frame(width: 96, height: 96)
                .background(NestoryColor.butter, in: Circle())
                .accessibilityHidden(true)

            VStack(spacing: NestorySpacing.xs) {
                Text(title)
                    .font(.nestory(.title3, weight: .bold))
                    .foregroundStyle(NestoryColor.cocoa)
                Text(message)
                    .font(.nestory(.body))
                    .foregroundStyle(NestoryColor.cocoaSoft)
                    .multilineTextAlignment(.center)
            }

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.nestoryPrimary)
            }
        }
        .padding(NestorySpacing.xl)
        .frame(maxWidth: 420)
        .accessibilityElement(children: .contain)
    }
}
