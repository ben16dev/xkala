import Charts
import SwiftData
import SwiftUI

/// Progreso global: ejercicios realizados por categoría y carga acumulada (derivado, sin persistencia).
struct XkalaProgressView: View {
    @Query(sort: \WorkoutDay.date, order: .reverse) private var workouts: [WorkoutDay]
    @State private var selectedRange: StatsRange = .oneMonth
    @State private var selectedCategoryId: String?

    private var categoryOptions: [ProgressCategoryOption] {
        ProgressCategoryCalculator.allCategoryOptions(from: workouts)
    }

    private var loadBuckets: [LoadBucket] {
        InsightsCalculator.loadBuckets(from: workouts, range: selectedRange)
    }

    private var effectiveCategoryId: String? {
        if let id = selectedCategoryId,
           categoryOptions.contains(where: { $0.id == id }) {
            return id
        }
        return categoryOptions.first?.id
    }

    private var exerciseBuckets: [ProgressCategoryBucket] {
        guard let categoryId = effectiveCategoryId else {
            return ProgressCategoryCalculator.buckets(
                forCategoryKey: "__none__",
                from: workouts,
                range: selectedRange
            )
        }
        return ProgressCategoryCalculator.buckets(
            forCategoryKey: categoryId,
            from: workouts,
            range: selectedRange
        )
    }

    private var categoryPickerSelection: Binding<String> {
        Binding(
            get: { effectiveCategoryId ?? "" },
            set: { selectedCategoryId = $0 }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ProgressRangePicker(selection: $selectedRange)

                ProgressExercisesChartCard(
                    buckets: exerciseBuckets,
                    range: selectedRange,
                    categoryOptions: categoryOptions,
                    categorySelection: categoryPickerSelection
                )

                LoadChartSectionView(buckets: loadBuckets, range: selectedRange)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .xkalaScreenBackground(.calendar)
        .navigationTitle("Progreso")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            reconcileCategorySelection()
        }
        .onChange(of: selectedRange) { _, _ in
            reconcileCategorySelection()
        }
        .onChange(of: categoryOptions.map(\.id)) { _, _ in
            reconcileCategorySelection()
        }
    }

    private func reconcileCategorySelection() {
        let options = categoryOptions
        guard !options.isEmpty else {
            selectedCategoryId = nil
            return
        }
        if let id = selectedCategoryId, options.contains(where: { $0.id == id }) {
            return
        }
        selectedCategoryId = options.first?.id
    }
}

// MARK: - Selector de rango

private struct ProgressRangePicker: View {
    @Binding var selection: StatsRange

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(StatsRange.allCases) { range in
                    let isOn = selection == range
                    Button {
                        selection = range
                    } label: {
                        Text(range.shortLabel)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(isOn ? XkalaTheme.accent : XkalaTheme.card)
                            )
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(isOn ? Color.clear : XkalaTheme.stroke, lineWidth: 1)
                            )
                            .foregroundStyle(isOn ? Color.white : Color.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Ejercicios realizados

private struct ProgressExercisesChartCard: View {
    let buckets: [ProgressCategoryBucket]
    let range: StatsRange
    let categoryOptions: [ProgressCategoryOption]
    @Binding var categorySelection: String

    private let chartHeight: CGFloat = 200

    private var bucketsOrdered: [ProgressCategoryBucket] {
        buckets.sorted { $0.chronologicalIndex < $1.chronologicalIndex }
    }

    private var selectedCategory: ProgressCategoryOption? {
        categoryOptions.first { $0.id == categorySelection }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Ejercicios")
                    .font(.headline)
                    .layoutPriority(1)

                Spacer(minLength: 8)

                if !categoryOptions.isEmpty {
                    categoryMenu
                }
            }

            exercisesChart
                .frame(maxWidth: .infinity)
                .frame(height: chartHeight)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .xkalaCard()
    }

    private var categoryMenu: some View {
        Menu {
            ForEach(categoryOptions) { category in
                Button {
                    categorySelection = category.id
                } label: {
                    HStack {
                        Text(category.displayName)
                        if category.id == categorySelection {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(selectedCategory?.displayName ?? "Categoría")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 148, alignment: .trailing)
        }
        .accessibilityLabel(selectedCategory?.displayName ?? "Categoría")
        .accessibilityHint("Seleccionar categoría")
    }

    @ViewBuilder
    private var exercisesChart: some View {
        let ordered = bucketsOrdered
        if ordered.isEmpty {
            Color.clear.frame(height: chartHeight)
        } else {
            exercisesChartContent(ordered: ordered)
        }
    }

    private func exercisesChartContent(ordered: [ProgressCategoryBucket]) -> some View {
        let xDomain = InsightsChartAxisFormatting.chartXDomain(bucketCount: ordered.count, range: range)
        let maxCount = ordered.map(\.completedCount).max() ?? 0
        let yTicks = InsightsChartAxisFormatting.sessionAxisTickValues(maxCount: max(1, maxCount))
        let yMax = Double(yTicks.last ?? 1)
        let lineColor = XkalaTheme.chartSessions

        return Chart {
            ForEach(ordered) { bucket in
                LineMark(
                    x: .value("Periodo", bucket.chronologicalIndex),
                    y: .value("Ejercicios", bucket.completedCount)
                )
                .interpolationMethod(InsightsChartAxisFormatting.lineInterpolation)
                .foregroundStyle(lineColor.opacity(0.96))
                .lineStyle(
                    StrokeStyle(
                        lineWidth: InsightsChartAxisFormatting.lineWidth,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )

                PointMark(
                    x: .value("Periodo", bucket.chronologicalIndex),
                    y: .value("Ejercicios", bucket.completedCount)
                )
                .foregroundStyle(lineColor)
                .symbolSize(InsightsChartAxisFormatting.pointSize)
            }
        }
        .chartXScale(domain: xDomain)
        .chartYScale(domain: 0...yMax)
        .chartPlotStyle { plotArea in
            plotArea.padding(InsightsChartAxisFormatting.chartPlotPadding(for: range))
        }
        .chartXAxis(.hidden)
        .insightsChartAxisOverlay(axisLabels: ordered.map(\.axisLabel), bucketCount: ordered.count, range: range)
        .chartYAxis {
            AxisMarks(position: .leading, values: yTicks.map(Double.init)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: InsightsChartAxisFormatting.horizontalGuideLineWidth))
                    .foregroundStyle(InsightsChartAxisFormatting.horizontalGuideColor)
                AxisValueLabel {
                    if let n = value.as(Double.self) {
                        Text(String(Int(n)))
                            .font(.caption2.monospacedDigit().weight(.medium))
                    }
                }
                .foregroundStyle(InsightsChartAxisFormatting.timeAxisLabelColor.opacity(0.85))
            }
        }
    }
}
