import Foundation

// MARK: - 진통 타이머

public struct ContractionRecord: Hashable, Codable, Sendable {
    public let start: Date
    public let end: Date

    public init(start: Date, end: Date) {
        self.start = start
        self.end = end
    }

    public var duration: TimeInterval { max(0, end.timeIntervalSince(start)) }
}

public struct ContractionSummary: Hashable, Sendable {
    public let count: Int
    /// 진통 시작 → 다음 진통 시작 간격의 평균(초). 2회 이상일 때만
    public let averageIntervalSeconds: Double?
    public let averageDurationSeconds: Double?
}

/// 일반적으로 알려진 "5-1-1" 같은 안내를 사용자가 정한 값으로 점검한다.
/// 의료 판단이 아니며, 실제 기준은 다니는 병원의 안내를 따라야 한다.
public struct ContractionGuideline: Hashable, Sendable {
    /// 진통 시작 간격이 이 값 이하(초)
    public var maxIntervalSeconds: Double
    /// 진통 지속 시간이 평균 이 값 이상(초)
    public var minAverageDurationSeconds: Double
    /// 위 상태가 이만큼(초) 이어졌을 때
    public var sustainedSeconds: Double

    public init(maxIntervalSeconds: Double = 300, minAverageDurationSeconds: Double = 60, sustainedSeconds: Double = 3600) {
        self.maxIntervalSeconds = maxIntervalSeconds
        self.minAverageDurationSeconds = minAverageDurationSeconds
        self.sustainedSeconds = sustainedSeconds
    }
}

public enum ContractionAnalyzer {
    /// `now` 이전 `window` 초 안에 시작한 진통만 요약한다.
    public static func summarize(
        _ records: [ContractionRecord],
        within window: TimeInterval = 3600,
        now: Date
    ) -> ContractionSummary {
        let recent = records
            .filter { $0.start >= now.addingTimeInterval(-window) && $0.start <= now }
            .sorted { $0.start < $1.start }
        let intervals = zip(recent, recent.dropFirst()).map { $1.start.timeIntervalSince($0.start) }
        return ContractionSummary(
            count: recent.count,
            averageIntervalSeconds: intervals.isEmpty ? nil : intervals.reduce(0, +) / Double(intervals.count),
            averageDurationSeconds: recent.isEmpty ? nil : recent.map(\.duration).reduce(0, +) / Double(recent.count)
        )
    }

    /// 최근 기록이 모두 간격 기준을 지키고, 평균 지속시간이 기준 이상이며,
    /// 첫 진통 시작부터 마지막 진통 종료까지가 `sustainedSeconds` 이상 이어졌는지 본다.
    public static func meetsGuideline(
        _ records: [ContractionRecord],
        guideline: ContractionGuideline = ContractionGuideline(),
        now: Date
    ) -> Bool {
        // 지속 시간만큼의 구간을 덮으려면 구간 시작 직전(최대 간격만큼 앞) 진통부터 봐야 한다.
        let lookback = guideline.sustainedSeconds + guideline.maxIntervalSeconds
        let recent = records
            .filter { $0.start >= now.addingTimeInterval(-lookback) && $0.start <= now }
            .sorted { $0.start < $1.start }
        guard recent.count >= 2, let first = recent.first, let last = recent.last else { return false }

        let intervals = zip(recent, recent.dropFirst()).map { $1.start.timeIntervalSince($0.start) }
        guard intervals.allSatisfy({ $0 <= guideline.maxIntervalSeconds }) else { return false }

        let averageDuration = recent.map(\.duration).reduce(0, +) / Double(recent.count)
        guard averageDuration >= guideline.minAverageDurationSeconds else { return false }

        return last.end.timeIntervalSince(first.start) >= guideline.sustainedSeconds
    }
}

// MARK: - 태동 카운터

public struct KickCountSummary: Hashable, Sendable {
    public let count: Int
    public let durationSeconds: Double

    /// 시간당 태동 수. 1분 미만이면 의미 없으므로 nil.
    public var perHour: Double? {
        durationSeconds >= 60 ? Double(count) / (durationSeconds / 3600) : nil
    }

    public init(count: Int, start: Date, end: Date) {
        self.count = count
        self.durationSeconds = max(0, end.timeIntervalSince(start))
    }
}
