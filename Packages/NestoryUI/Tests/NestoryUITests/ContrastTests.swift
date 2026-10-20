import Testing
@testable import NestoryUI

/// 팔레트 조합이 WCAG 2.1 AA(본문 4.5:1)를 지키는지 검증한다.
/// 새 색을 쓰는 조합이 생기면 여기에 한 줄 추가한다.
struct ContrastTests {
    enum Mode: String, CaseIterable, Sendable {
        case light, dark, night
        var isDark: Bool { self != .light }
        var isNight: Bool { self == .night }
    }

    struct Pair: Sendable, CustomTestStringConvertible {
        let foreground: ColorToken
        let background: ColorToken
        let modes: [Mode]
        var testDescription: String { "\(foreground.name) on \(background.name) \(modes.map(\.rawValue))" }
    }

    static let pastels = [
        NestoryPalette.peach, NestoryPalette.mint, NestoryPalette.butter,
        NestoryPalette.lavender, NestoryPalette.sky, NestoryPalette.rose,
        NestoryPalette.warning,
    ]

    static let pairs: [Pair] = {
        var result: [Pair] = []
        // 본문/보조/강조/위험 텍스트는 배경(cream)과 카드 위에서 모든 모드 AA
        for foreground in [NestoryPalette.cocoa, NestoryPalette.cocoaSoft, NestoryPalette.peachDeep, NestoryPalette.danger] {
            for background in [NestoryPalette.cream, NestoryPalette.card] {
                result.append(Pair(foreground: foreground, background: background, modes: Mode.allCases))
            }
        }
        // 파스텔 면 위 글자는 onPastel
        for pastel in pastels {
            result.append(Pair(foreground: NestoryPalette.onPastel, background: pastel, modes: Mode.allCases))
        }
        return result
    }()

    @Test(arguments: pairs)
    func meetsAA(pair: Pair) {
        for mode in pair.modes {
            let foreground = pair.foreground.value(isDark: mode.isDark, isNight: mode.isNight)
            let background = pair.background.value(isDark: mode.isDark, isNight: mode.isNight)
            let ratio = foreground.contrastRatio(with: background)
            #expect(ratio >= 4.5, "\(pair.testDescription) [\(mode.rawValue)] = \(ratio)")
        }
    }

    @Test func contrastMathMatchesKnownValues() {
        let black = HexColor(0x000000)
        let white = HexColor(0xFFFFFF)
        #expect(abs(black.contrastRatio(with: white) - 21) < 0.001)
        #expect(abs(white.contrastRatio(with: white) - 1) < 0.001)
    }

    @Test func tokenNamesAreUnique() {
        let names = NestoryPalette.all.map(\.name)
        #expect(Set(names).count == names.count)
    }
}
