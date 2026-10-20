import Foundation

public enum GrowthMeasure: String, Codable, CaseIterable, Sendable {
    case weight, height, headCircumference, bodyMassIndex
}

public enum GrowthSex: String, Codable, CaseIterable, Sendable {
    case female, male
}

/// 성장도표 LMS 한 점: 월령 `ageMonths` 에서의 (L, M, S)
public struct LMSPoint: Codable, Hashable, Sendable {
    public let ageMonths: Double
    public let l: Double
    public let m: Double
    public let s: Double

    public init(ageMonths: Double, l: Double, m: Double, s: Double) {
        self.ageMonths = ageMonths
        self.l = l
        self.m = m
        self.s = s
    }
}

public struct GrowthTable: Codable, Hashable, Sendable {
    public let measure: GrowthMeasure
    public let sex: GrowthSex
    /// 월령 오름차순
    public let points: [LMSPoint]

    public init(measure: GrowthMeasure, sex: GrowthSex, points: [LMSPoint]) {
        self.measure = measure
        self.sex = sex
        self.points = points
    }
}

public struct GrowthReference: Codable, Sendable {
    public let meta: RuleMeta
    public let tables: [GrowthTable]

    /// 번들 데이터. 공식 LMS 표를 채우기 전에는 `meta.status == .missing` 이고 tables 가 비어 있다.
    public static func bundled() throws -> GrowthReference {
        try RuleLoader.loadBundled("growth-lms")
    }

    public init(meta: RuleMeta, tables: [GrowthTable]) {
        self.meta = meta
        self.tables = tables
    }

    public func table(measure: GrowthMeasure, sex: GrowthSex) -> GrowthTable? {
        tables.first { $0.measure == measure && $0.sex == sex }
    }
}

public struct GrowthResult: Hashable, Sendable {
    public let zScore: Double
    /// 0…100
    public let percentile: Double
}

public enum GrowthPercentile {
    /// 표시용 백분위 밴드 (3·15·50·85·97)와 표준정규 z 값
    public static let bands: [(percentile: Int, z: Double)] = [
        (3, -1.8808), (15, -1.0364), (50, 0), (85, 1.0364), (97, 1.8808),
    ]

    /// 한 달을 30.4375일(= 365.25 / 12)로 본 월령
    public static func ageMonths(birth: Date, on date: Date, calendar: Calendar = .korea) -> Double {
        Double(calendar.daysBetween(birth, date)) / 30.4375
    }

    /// LMS → z: L ≠ 0 이면 ((x/M)^L − 1) / (L·S), L = 0 이면 ln(x/M) / S
    public static func zScore(value: Double, point: LMSPoint) -> Double {
        if abs(point.l) < 1e-9 {
            return log(value / point.m) / point.s
        }
        return (pow(value / point.m, point.l) - 1) / (point.l * point.s)
    }

    /// 표준정규분포 누적확률 × 100
    public static func percentile(z: Double) -> Double {
        0.5 * erfc(-z / 2.0.squareRoot()) * 100
    }

    /// z 에 해당하는 측정값 (밴드 곡선 그리기용). L ≠ 0 이면 M·(1 + L·S·z)^(1/L)
    public static func value(z: Double, point: LMSPoint) -> Double {
        if abs(point.l) < 1e-9 {
            return point.m * exp(point.s * z)
        }
        return point.m * pow(1 + point.l * point.s * z, 1 / point.l)
    }

    /// 월령 사이를 선형 보간한 LMS. 표의 범위 밖이면 nil.
    public static func interpolate(_ table: GrowthTable, ageMonths: Double) -> LMSPoint? {
        let points = table.points
        guard let first = points.first, let last = points.last,
              ageMonths >= first.ageMonths, ageMonths <= last.ageMonths else { return nil }
        guard let upperIndex = points.firstIndex(where: { $0.ageMonths >= ageMonths }) else { return nil }
        let upper = points[upperIndex]
        if upper.ageMonths == ageMonths || upperIndex == 0 { return upper }
        let lower = points[upperIndex - 1]
        let t = (ageMonths - lower.ageMonths) / (upper.ageMonths - lower.ageMonths)
        func mix(_ a: Double, _ b: Double) -> Double { a + (b - a) * t }
        return LMSPoint(
            ageMonths: ageMonths,
            l: mix(lower.l, upper.l), m: mix(lower.m, upper.m), s: mix(lower.s, upper.s)
        )
    }

    /// 측정값 하나의 z·백분위. 표가 없거나 월령이 범위 밖이면 nil.
    public static func evaluate(
        value: Double,
        measure: GrowthMeasure,
        sex: GrowthSex,
        ageMonths: Double,
        reference: GrowthReference
    ) -> GrowthResult? {
        guard value > 0,
              let table = reference.table(measure: measure, sex: sex),
              let point = interpolate(table, ageMonths: ageMonths) else { return nil }
        let z = zScore(value: value, point: point)
        return GrowthResult(zScore: z, percentile: percentile(z: z))
    }
}
