import SwiftUI

/// 간격 스케일 (Design PRD §5)
public enum NestorySpacing {
    public static let xs: CGFloat = 4
    public static let s: CGFloat = 8
    public static let m: CGFloat = 12
    public static let l: CGFloat = 16
    public static let xl: CGFloat = 24
    public static let xxl: CGFloat = 32
}

public enum NestoryRadius {
    public static let card: CGFloat = 24
    public static let chip: CGFloat = 12
}

/// 터치 영역 최소 크기
public enum NestoryHitTarget {
    public static let minimum: CGFloat = 44
    public static let quickLog: CGFloat = 56
}

extension Font {
    /// 둥근 시스템 폰트. 텍스트 스타일 기반이라 Dynamic Type 에 따라 커진다.
    public static func nestory(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .rounded, weight: weight)
    }
}

extension View {
    /// 부드러운 따뜻한 그림자 (차가운 회색 그림자 금지)
    public func nestoryShadow() -> some View {
        shadow(color: NestoryPalette.peach.light.shadowColor, radius: 16, x: 0, y: 4)
    }
}

extension HexColor {
    /// 8% 불투명도 그림자 색
    fileprivate var shadowColor: Color {
        Color(self).opacity(0.08)
    }
}
