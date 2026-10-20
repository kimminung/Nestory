import SwiftUI

/// 필터·태그 칩 (재택, 단시간 등). 선택 상태는 색뿐 아니라 체크 아이콘으로도 표시한다.
public struct NestoryChip: View {
    private let title: LocalizedStringKey
    private let isSelected: Bool
    private let action: () -> Void

    public init(_ title: LocalizedStringKey, isSelected: Bool = false, action: @escaping () -> Void = {}) {
        self.title = title
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: NestorySpacing.xs) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.nestory(.caption, weight: .bold))
                        .accessibilityHidden(true)
                }
                Text(title)
                    .font(.nestory(.subheadline, weight: .medium))
            }
            .foregroundStyle(isSelected ? NestoryColor.onPastel : NestoryColor.cocoa)
            .padding(.horizontal, NestorySpacing.m)
            .frame(minHeight: NestoryHitTarget.minimum)
            .background(
                isSelected ? NestoryColor.peach : NestoryColor.card,
                in: RoundedRectangle(cornerRadius: NestoryRadius.chip, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: NestoryRadius.chip, style: .continuous)
                    .strokeBorder(NestoryColor.peach, lineWidth: isSelected ? 0 : 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: NestoryRadius.chip, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
