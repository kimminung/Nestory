import Charts
import NestoryData
import NestoryKit
import NestoryUI
import SwiftData
import SwiftUI

/// 성장 기록: 키·몸무게·머리둘레 입력, 변화 그래프, (공식 표가 있으면) 백분위
struct GrowthView: View {
    let child: Child

    @Environment(\.ruleCatalog) private var catalog
    @Environment(\.referenceDate) private var referenceDate
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @State private var measure: GrowthMeasure = .weight
    @State private var isAdding = false

    private var now: Date { referenceDate ?? Date() }

    private var sex: GrowthSex? {
        switch child.sex {
        case .female: .female
        case .male: .male
        case .unknown: nil
        }
    }

    private var records: [GrowthRecord] {
        (child.growthRecords ?? []).sorted { $0.date < $1.date }
    }

    private func value(_ record: GrowthRecord) -> Double? {
        switch measure {
        case .weight: record.weightKg
        case .height: record.heightCm
        case .headCircumference: record.headCm
        case .bodyMassIndex: nil
        }
    }

    private var unit: String {
        switch measure {
        case .weight: "kg"
        case .height, .headCircumference: "cm"
        case .bodyMassIndex: ""
        }
    }

    private func ageMonths(_ record: GrowthRecord) -> Double {
        guard let birth = child.birthDate else { return 0 }
        return GrowthPercentile.ageMonths(birth: birth, on: record.date)
    }

    private func percentile(_ record: GrowthRecord) -> GrowthResult? {
        guard let catalog, let sex, let value = value(record) else { return nil }
        return GrowthPercentile.evaluate(
            value: value, measure: measure, sex: sex, ageMonths: ageMonths(record), reference: catalog.growth
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NestorySpacing.l) {
                Picker("항목", selection: $measure) {
                    Text("몸무게").tag(GrowthMeasure.weight)
                    Text("키").tag(GrowthMeasure.height)
                    Text("머리둘레").tag(GrowthMeasure.headCircumference)
                }
                .pickerStyle(.segmented)

                notices
                chartCard
                recordList
            }
            .padding(NestorySpacing.l)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(NestoryColor.cream)
        .navigationTitle("성장 기록")
        .toolbar {
            ToolbarItem {
                Menu {
                    Picker("성별", selection: Binding(get: { child.sex }, set: { child.sex = $0 })) {
                        Text("선택 안 함").tag(ChildSex.unknown)
                        Text("여아").tag(ChildSex.female)
                        Text("남아").tag(ChildSex.male)
                    }
                } label: {
                    Label("성별", systemImage: "person.crop.circle")
                }
            }
            ToolbarItem {
                Button("측정 추가", systemImage: "plus") { isAdding = true }
            }
        }
        .sheet(isPresented: $isAdding) {
            GrowthAddSheet(child: child, now: now)
        }
    }

    // MARK: - 안내

    @ViewBuilder
    private var notices: some View {
        if let catalog, catalog.growth.meta.status == .missing {
            NestoryCard(fill: .butter, contentColor: .onPastel) {
                Label("성장도표 데이터가 아직 앱에 없어요", systemImage: "info.circle.fill")
                    .font(.nestory(.subheadline, weight: .bold))
                Text("기록은 그대로 저장되고, 공식 표가 들어오면 백분위를 보여 드릴게요.")
                    .font(.nestory(.footnote))
            }
        } else if sex == nil {
            NestoryCard(fill: .butter, contentColor: .onPastel) {
                Label("백분위를 보려면 성별을 알려 주세요", systemImage: "person.crop.circle")
                    .font(.nestory(.subheadline, weight: .bold))
                Text("오른쪽 위 메뉴에서 선택할 수 있어요.")
                    .font(.nestory(.footnote))
            }
        }
    }

    // MARK: - 그래프

    @ViewBuilder
    private var chartCard: some View {
        let points = records.compactMap { record in value(record).map { (age: ageMonths(record), value: $0) } }
        if points.isEmpty {
            EmptyState(title: "아직 측정 기록이 없어요", message: "오른쪽 위 + 로 처음 잰 값을 남겨 보세요.", systemImage: "chart.line.uptrend.xyaxis")
                .frame(maxWidth: .infinity)
        } else {
            NestoryCard {
                Chart {
                    ForEach(bandLines, id: \.percentile) { line in
                        ForEach(line.points, id: \.age) { point in
                            LineMark(
                                x: .value("월령", point.age),
                                y: .value("값", point.value),
                                series: .value("백분위", "P\(line.percentile)")
                            )
                            .foregroundStyle(NestoryColor.cocoaSoft.color(in: colorScheme).opacity(line.percentile == 50 ? 0.7 : 0.35))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: line.percentile == 50 ? [] : [3, 3]))
                        }
                    }
                    ForEach(points, id: \.age) { point in
                        LineMark(x: .value("월령", point.age), y: .value("값", point.value), series: .value("백분위", "우리 아이"))
                            .foregroundStyle(NestoryColor.peachDeep.color(in: colorScheme))
                        PointMark(x: .value("월령", point.age), y: .value("값", point.value))
                            .foregroundStyle(NestoryColor.peachDeep.color(in: colorScheme))
                    }
                }
                .chartXAxisLabel("월령(개월)")
                .chartYAxisLabel(unit)
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(height: 220)
                .accessibilityLabel("성장 그래프")
                .accessibilityValue(points.last.map { "최근 \($0.value.formatted())\(unit)" } ?? "")
            }
        }
    }

    /// 공식 표가 있을 때만 그리는 3·50·97 백분위 곡선
    private var bandLines: [(percentile: Int, points: [(age: Double, value: Double)])] {
        guard let catalog, let sex, let table = catalog.growth.table(measure: measure, sex: sex) else { return [] }
        return GrowthPercentile.bands.filter { [3, 50, 97].contains($0.percentile) }.map { band in
            (band.percentile, table.points.map { (age: $0.ageMonths, value: GrowthPercentile.value(z: band.z, point: $0)) })
        }
    }

    // MARK: - 목록

    @ViewBuilder
    private var recordList: some View {
        let list = records.reversed()
        if !list.isEmpty {
            VStack(alignment: .leading, spacing: NestorySpacing.s) {
                SectionTitle("기록")
                NestoryCard {
                    ForEach(Array(list), id: \.id) { record in
                        GrowthRow(
                            record: record,
                            summary: summary(record),
                            percentileText: percentile(record).map { "상위 \(Int((100 - $0.percentile).rounded()))%" }
                        ) { modelContext.delete(record) }
                        if record.id != list.last?.id { Divider() }
                    }
                }
            }
        }
    }

    private func summary(_ record: GrowthRecord) -> String {
        var parts: [String] = []
        if let weight = record.weightKg { parts.append("\(weight.formatted())kg") }
        if let height = record.heightCm { parts.append("\(height.formatted())cm") }
        if let head = record.headCm { parts.append("머리 \(head.formatted())cm") }
        return parts.joined(separator: " · ")
    }
}

private struct GrowthRow: View {
    let record: GrowthRecord
    let summary: String
    let percentileText: String?
    let onDelete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(KoreanFormat.longDate(record.date)).font(.nestory(.body, weight: .semibold))
                Text(summary).font(.nestory(.footnote)).foregroundStyle(NestoryColor.cocoaSoft)
            }
            Spacer()
            if let percentileText {
                Text(percentileText).font(.nestory(.subheadline, weight: .bold))
            }
        }
        .foregroundStyle(NestoryColor.cocoa)
        .contextMenu { Button("삭제", role: .destructive, action: onDelete) }
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: "삭제", onDelete)
    }
}

private struct GrowthAddSheet: View {
    let child: Child
    let now: Date

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var date: Date
    @State private var weight = ""
    @State private var height = ""
    @State private var head = ""

    init(child: Child, now: Date) {
        self.child = child
        self.now = now
        _date = State(initialValue: now)
    }

    private func number(_ text: String) -> Double? {
        Double(text.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces))
    }

    private var isValid: Bool {
        [weight, height, head].contains { number($0).map { $0 > 0 } ?? false }
    }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("측정일", selection: $date, in: ...now, displayedComponents: .date)
                TextField("몸무게(kg)", text: $weight)
                TextField("키(cm)", text: $height)
                TextField("머리둘레(cm)", text: $head)
                Text("잰 값만 입력해도 돼요.")
                    .font(.nestory(.footnote))
                    .foregroundStyle(NestoryColor.cocoaSoft)
            }
            .formStyle(.grouped)
            .navigationTitle("측정 추가")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("저장", action: save).disabled(!isValid) }
            }
        }
        #if os(macOS)
        .frame(minWidth: 400, minHeight: 320)
        #endif
    }

    private func save() {
        let record = GrowthRecord(date: Calendar.korea.startOfDay(for: date))
        record.weightKg = number(weight).flatMap { $0 > 0 ? $0 : nil }
        record.heightCm = number(height).flatMap { $0 > 0 ? $0 : nil }
        record.headCm = number(head).flatMap { $0 > 0 ? $0 : nil }
        modelContext.insert(record)
        record.child = child
        dismiss()
    }
}

#Preview("성장 기록") {
    NavigationStack {
        WithActiveChild { GrowthView(child: $0) }
    }
    .bornPreviewEnvironment()
}
