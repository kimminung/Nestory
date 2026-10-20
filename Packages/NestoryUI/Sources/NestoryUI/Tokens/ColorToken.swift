import SwiftUI

/// 라이트/다크/밤 모드 값을 가진 색 토큰.
public struct ColorToken: Equatable, Sendable {
    public let name: String
    public let light: HexColor
    public let dark: HexColor
    /// 밤 수유 모드 전용 값. nil 이면 dark 를 쓴다.
    public let night: HexColor?

    public init(_ name: String, light: UInt32, dark: UInt32, night: UInt32? = nil) {
        self.name = name
        self.light = HexColor(light)
        self.dark = HexColor(dark)
        self.night = night.map(HexColor.init)
    }

    public func value(isDark: Bool, isNight: Bool = false) -> HexColor {
        if isNight { return night ?? dark }
        return isDark ? dark : light
    }
}

/// 환경(라이트/다크/밤 모드)에 따라 스스로 색을 고르는 ShapeStyle.
/// 사용 예: `.foregroundStyle(NestoryColor.cocoa)`, `.background(NestoryColor.card)`
public struct NestoryColor: ShapeStyle, Equatable, Sendable {
    public let token: ColorToken

    public init(_ token: ColorToken) {
        self.token = token
    }

    public func resolve(in environment: EnvironmentValues) -> Color {
        let isDark = environment.colorScheme == .dark
        return Color(token.value(isDark: isDark, isNight: environment.nestoryNightMode))
    }

    /// ShapeStyle 이 아닌 곳(차트, tint 등)에서 쓸 때
    public func color(in scheme: ColorScheme, night: Bool = false) -> Color {
        Color(token.value(isDark: scheme == .dark, isNight: night))
    }
}

extension Color {
    init(_ hex: HexColor) {
        self.init(
            .sRGB,
            red: Double(hex.red) / 255,
            green: Double(hex.green) / 255,
            blue: Double(hex.blue) / 255,
            opacity: 1
        )
    }
}

extension EnvironmentValues {
    /// 밤 수유 모드: 어두운 배경 + 호박색 단일 악센트 (Design PRD §3.3)
    @Entry public var nestoryNightMode: Bool = false
}
