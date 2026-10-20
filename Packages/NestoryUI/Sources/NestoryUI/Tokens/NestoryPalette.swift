import SwiftUI

/// Design PRD §3 팔레트. 값을 바꿀 때는 ContrastTests 가 AA 기준을 지키는지 확인한다.
public enum NestoryPalette {
    // 배경·면
    public static let cream = ColorToken("cream", light: 0xFFF8EF, dark: 0x1E1A19)
    public static let card = ColorToken("card", light: 0xFFFFFF, dark: 0x2A2423)

    // 텍스트 (cocoa 계열)
    public static let cocoa = ColorToken("cocoa", light: 0x5A4340, dark: 0xF4E9E2)
    public static let cocoaSoft = ColorToken("cocoaSoft", light: 0x7A6360, dark: 0xCDBBB3)
    /// 파스텔 면 위의 글자. 파스텔은 다크 모드에서도 밝으므로 항상 어두운 색.
    public static let onPastel = ColorToken("onPastel", light: 0x5A4340, dark: 0x5A4340)

    // 악센트
    public static let peach = ColorToken("peach", light: 0xFFB59E, dark: 0xFFA58A, night: 0xFFB870)
    /// 크림 위 강조 텍스트/아이콘용 (peach 는 면 전용)
    public static let peachDeep = ColorToken("peachDeep", light: 0xB24A33, dark: 0xFFB59E, night: 0xFFB870)

    // 카테고리 파스텔 (면 전용, 위 글자는 onPastel)
    public static let mint = ColorToken("mint", light: 0xA8E0CF, dark: 0xA8E0CF)
    public static let butter = ColorToken("butter", light: 0xFFE08A, dark: 0xFFE08A)
    public static let lavender = ColorToken("lavender", light: 0xCBB8F0, dark: 0xCBB8F0)
    public static let sky = ColorToken("sky", light: 0xB8DDF5, dark: 0xB8DDF5)
    public static let rose = ColorToken("rose", light: 0xF6B6C8, dark: 0xF6B6C8)

    // 상태
    /// 면 전용 (위 글자는 onPastel)
    public static let warning = ColorToken("warning", light: 0xF2B33D, dark: 0xF2B33D)
    /// 크림 위 텍스트·흰 글자 면 모두 AA
    public static let danger = ColorToken("danger", light: 0xC23B38, dark: 0xFF8A85)

    public static let all: [ColorToken] = [
        cream, card, cocoa, cocoaSoft, onPastel, peach, peachDeep,
        mint, butter, lavender, sky, rose, warning, danger,
    ]
}

extension NestoryColor {
    public static let cream = NestoryColor(NestoryPalette.cream)
    public static let card = NestoryColor(NestoryPalette.card)
    public static let cocoa = NestoryColor(NestoryPalette.cocoa)
    public static let cocoaSoft = NestoryColor(NestoryPalette.cocoaSoft)
    public static let onPastel = NestoryColor(NestoryPalette.onPastel)
    public static let peach = NestoryColor(NestoryPalette.peach)
    public static let peachDeep = NestoryColor(NestoryPalette.peachDeep)
    public static let mint = NestoryColor(NestoryPalette.mint)
    public static let butter = NestoryColor(NestoryPalette.butter)
    public static let lavender = NestoryColor(NestoryPalette.lavender)
    public static let sky = NestoryColor(NestoryPalette.sky)
    public static let rose = NestoryColor(NestoryPalette.rose)
    public static let warning = NestoryColor(NestoryPalette.warning)
    public static let danger = NestoryColor(NestoryPalette.danger)
}
