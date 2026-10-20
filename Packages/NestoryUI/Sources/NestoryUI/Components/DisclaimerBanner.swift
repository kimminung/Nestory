import NestoryKit
import SwiftUI

/// 제도·금액 화면 상단의 상시 고지: "참고용 · 기준일 · 출처".
public struct DisclaimerBanner: View {
    private let effectiveDate: Date?
    private let sourceName: String?
    private let sourceURL: URL?

    public init(effectiveDate: Date? = nil, sourceName: String? = nil, sourceURL: URL? = nil) {
        self.effectiveDate = effectiveDate
        self.sourceName = sourceName
        self.sourceURL = sourceURL
    }

    private var headline: String {
        let base = String(localized: "disclaimer.base", bundle: .module)
        guard let effectiveDate else { return base }
        let date = KoreanFormat.longDate(effectiveDate)
        let effective = String(localized: "disclaimer.effective \(date)", bundle: .module)
        return "\(base) · \(effective)"
    }

    public var body: some View {
        HStack(alignment: .top, spacing: NestorySpacing.s) {
            Image(systemName: "info.circle.fill")
                .font(.nestory(.body))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: NestorySpacing.xs) {
                Text(headline)
                    .font(.nestory(.footnote, weight: .bold))
                Text("disclaimer.verify", bundle: .module)
                    .font(.nestory(.footnote))
                if let sourceName, let sourceURL {
                    Link(destination: sourceURL) {
                        Text("disclaimer.source \(sourceName)", bundle: .module)
                            .font(.nestory(.footnote, weight: .semibold))
                            .underline()
                    }
                }
            }
        }
        .foregroundStyle(NestoryColor.onPastel)
        .padding(NestorySpacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NestoryColor.butter, in: RoundedRectangle(cornerRadius: NestoryRadius.chip, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
