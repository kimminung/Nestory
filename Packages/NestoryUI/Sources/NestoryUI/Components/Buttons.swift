import SwiftUI

/// 눌렀을 때 살짝 줄어드는 스프링. 모션 감소 설정이면 크기 변화 없이 투명도만 바뀐다.
private struct PressEffect: ViewModifier {
    let isPressed: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed && !reduceMotion ? 0.96 : 1)
            .opacity(isPressed && reduceMotion ? 0.85 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.75), value: isPressed)
    }
}

/// 주 버튼: 피치 캡슐
public struct NestoryPrimaryButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.nestory(.headline))
            .foregroundStyle(NestoryColor.onPastel)
            .padding(.horizontal, NestorySpacing.xl)
            .frame(minHeight: NestoryHitTarget.minimum)
            .background(NestoryColor.peach, in: Capsule())
            .modifier(PressEffect(isPressed: configuration.isPressed))
    }
}

extension ButtonStyle where Self == NestoryPrimaryButtonStyle {
    public static var nestoryPrimary: NestoryPrimaryButtonStyle { NestoryPrimaryButtonStyle() }
}

/// 큰 빠른 기록 버튼 (한 손·새벽 수유용, 높이 56pt 이상)
public struct QuickLogButton: View {
    private let title: LocalizedStringKey
    private let systemImage: String
    private let tint: NestoryColor
    private let action: () -> Void

    public init(
        _ title: LocalizedStringKey,
        systemImage: String,
        tint: NestoryColor,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            VStack(spacing: NestorySpacing.xs) {
                Image(systemName: systemImage)
                    .font(.nestory(.title2, weight: .semibold))
                    .accessibilityHidden(true)
                Text(title)
                    .font(.nestory(.subheadline, weight: .semibold))
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(NestoryColor.onPastel)
            .padding(.horizontal, NestorySpacing.l)
            .padding(.vertical, NestorySpacing.s)
            .frame(minWidth: 72, minHeight: NestoryHitTarget.quickLog)
            .background(tint, in: RoundedRectangle(cornerRadius: NestoryRadius.card, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: NestoryRadius.card, style: .continuous))
        }
        .buttonStyle(QuickLogPressStyle())
    }
}

private struct QuickLogPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.modifier(PressEffect(isPressed: configuration.isPressed))
    }
}
