import Foundation
import NestoryKit
import OSLog
import UserNotifications

/// 로컬 알림 권한 요청과 예약. 계획 계산은 `NotificationPlanner`(순수)가 하고, 여기서는 시스템에 등록만 한다.
enum NotificationService {
    private static let logger = Logger(subsystem: "com.kimminung.nestory", category: "notifications")
    private static let identifierPrefix = "nestory."

    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            logger.error("알림 권한 요청 실패: \(error.localizedDescription)")
            return false
        }
    }

    static func isAuthorized() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional: return true
        default: return false
        }
    }

    /// 앱이 만든 대기 알림을 모두 지우고 `events` 기준으로 다시 예약한다. 권한이 없으면 아무것도 하지 않는다.
    static func reschedule(events: [PlannableEvent], now: Date = Date()) async {
        guard await isAuthorized() else { return }
        let center = UNUserNotificationCenter.current()

        let pending = await center.pendingNotificationRequests()
        let ours = pending.map(\.identifier).filter { $0.hasPrefix(identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ours)

        let plan = NotificationPlanner.plan(events: events, now: now)
        for notification in plan {
            let content = UNMutableNotificationContent()
            content.title = notification.title
            content.body = notification.body
            content.sound = .default

            let components = Calendar.korea.dateComponents(
                [.year, .month, .day, .hour, .minute], from: notification.fireDate
            )
            let request = UNNotificationRequest(
                identifier: identifierPrefix + notification.id,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            )
            do {
                try await center.add(request)
            } catch {
                logger.error("알림 예약 실패(\(notification.id)): \(error.localizedDescription)")
            }
        }
        logger.info("알림 \(plan.count)개 예약")
    }
}
