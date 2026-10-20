import NestoryKit
import SwiftUI

/// 기록·일정 종류별 색 + 아이콘 (Design PRD §3.2). 색만으로 구분하지 않고 항상 아이콘을 함께 쓴다.
public struct CategoryStyle: Sendable {
    public let color: NestoryColor
    public let systemImage: String

    public init(color: NestoryColor, systemImage: String) {
        self.color = color
        self.systemImage = systemImage
    }
}

extension CategoryStyle {
    public static func style(for type: CareLogType) -> CategoryStyle {
        switch type {
        case .breastFeeding, .formula, .solidFood:
            CategoryStyle(color: .mint, systemImage: "drop.fill")
        case .sleep:
            CategoryStyle(color: .lavender, systemImage: "moon.zzz.fill")
        case .diaper:
            // 전용 기저귀 심볼이 없어 임시 아이콘. 스티커 에셋 반입(D7) 후 교체.
            CategoryStyle(color: .sky, systemImage: "circle.hexagongrid.fill")
        case .temperature:
            CategoryStyle(color: .rose, systemImage: "thermometer.medium")
        case .medication:
            CategoryStyle(color: .rose, systemImage: "pills.fill")
        }
    }

    public static func style(for category: TaskCategory) -> CategoryStyle {
        switch category {
        case .prenatalCheckup: CategoryStyle(color: .rose, systemImage: "stethoscope")
        case .voucher: CategoryStyle(color: .butter, systemImage: "ticket.fill")
        case .preparation: CategoryStyle(color: .butter, systemImage: "checklist")
        case .administration: CategoryStyle(color: .butter, systemImage: "doc.text.fill")
        case .vaccination: CategoryStyle(color: .rose, systemImage: "syringe.fill")
        case .healthCheckup: CategoryStyle(color: .rose, systemImage: "heart.text.square.fill")
        case .leave: CategoryStyle(color: .peach, systemImage: "briefcase.fill")
        case .sideWork: CategoryStyle(color: .sky, systemImage: "figure.and.child.holdinghands")
        case .custom: CategoryStyle(color: .butter, systemImage: "calendar")
        }
    }
}
