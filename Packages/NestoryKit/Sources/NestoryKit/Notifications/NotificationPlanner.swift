import Foundation

/// 알림 대상 일정 (하루 단위)
public struct PlannableEvent: Hashable, Sendable {
    public let id: String
    public let title: String
    public let date: Date

    public init(id: String, title: String, date: Date) {
        self.id = id
        self.title = title
        self.date = date
    }
}

public struct NotificationConfig: Hashable, Sendable {
    /// 일정 며칠 전에 알릴지 (0 = 당일)
    public var leadDays: [Int]
    public var deliveryHour: Int
    /// 조용한 시간 [quietStartHour, 24) ∪ [0, quietEndHour). 이 시간대에 걸리면 같은 날 가장 가까운 허용 시각으로 옮긴다.
    public var quietStartHour: Int
    public var quietEndHour: Int
    /// iOS 로컬 알림 대기 한도(64)
    public var maxPending: Int

    public init(
        leadDays: [Int] = [7, 1, 0],
        deliveryHour: Int = 9,
        quietStartHour: Int = 22,
        quietEndHour: Int = 7,
        maxPending: Int = 64
    ) {
        self.leadDays = leadDays
        self.deliveryHour = deliveryHour
        self.quietStartHour = quietStartHour
        self.quietEndHour = quietEndHour
        self.maxPending = maxPending
    }
}

public struct PlannedNotification: Hashable, Identifiable, Sendable {
    public let id: String
    public let eventID: String
    public let leadDays: Int
    public let fireDate: Date
    public let title: String
    public let body: String
}

public enum NotificationPlanner {
    /// 일정 목록으로 예약할 알림을 계산한다. 지난 알림은 버리고, 가까운 순으로 `maxPending` 개만 남긴다.
    public static func plan(
        events: [PlannableEvent],
        config: NotificationConfig = NotificationConfig(),
        now: Date,
        calendar: Calendar = .korea,
        text: ((PlannableEvent, Int) -> (title: String, body: String))? = nil
    ) -> [PlannedNotification] {
        var planned: [PlannedNotification] = []
        for event in events {
            for lead in Set(config.leadDays).sorted(by: >) where lead >= 0 {
                let day = calendar.adding(days: -lead, to: calendar.startOfDay(for: event.date))
                guard let fire = calendar.date(
                    bySettingHour: allowedHour(config.deliveryHour, config: config), minute: 0, second: 0, of: day
                ), fire > now else { continue }

                let content = (text ?? defaultText)(event, lead)
                planned.append(
                    PlannedNotification(
                        id: "\(event.id)#\(lead)", eventID: event.id, leadDays: lead,
                        fireDate: fire, title: content.title, body: content.body
                    )
                )
            }
        }
        planned.sort { ($0.fireDate, $0.id) < ($1.fireDate, $1.id) }
        return Array(planned.prefix(max(0, config.maxPending)))
    }

    /// 조용한 시간에 걸린 시각을 같은 날 허용 범위 안으로 당긴다.
    static func allowedHour(_ hour: Int, config: NotificationConfig) -> Int {
        let start = config.quietStartHour
        let end = config.quietEndHour
        guard start > end else { return hour }   // 조용한 시간이 자정을 가로지르지 않으면 보정하지 않는다
        if hour < end { return end }
        if hour >= start { return start - 1 }
        return hour
    }

    static func defaultText(_ event: PlannableEvent, leadDays: Int) -> (title: String, body: String) {
        switch leadDays {
        case 0: ("오늘 일정", event.title)
        case 1: ("내일 일정", event.title)
        default: ("D-\(leadDays)", event.title)
        }
    }
}
