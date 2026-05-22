import Charts
import SwiftUI

/// Gráfica de carga acumulada (duración × RPE). Reutilizable en Perfil e Insights y Progreso.
struct LoadChartSectionView: View {
    let buckets: [LoadBucket]
    let range: StatsRange

    private let chartHeight: CGFloat = 200

    private struct LoadChartPoint: Identifiable {
        let id: String
        let chronologicalIndex: Int
        let axisLabel: String
        let totalLoad: Int
    }

    private var pointsOrdered: [LoadChartPoint] {
        buckets
            .sorted { $0.date < $1.date }
            .enumerated()
            .map { index, bucket in
                LoadChartPoint(
                    id: "\(bucket.id)",
                    chronologicalIndex: index,
                    axisLabel: InsightsCalculator.bucketAxisLabel(
                        intervalStart: bucket.date,
                        range: range
                    ),
                    totalLoad: bucket.totalLoad
                )
            }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Carga")
                    .font(.headline)
                Text("Carga acumulada (duración × RPE)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            loadChart
                .frame(maxWidth: .infinity)
                .frame(height: chartHeight)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .xkalaCard()
    }

    private var loadChart: some View {
        let ordered = pointsOrdered
        let xDomain = InsightsChartAxisFormatting.chartXDomain(bucketCount: ordered.count, range: range)
        let maxLoad = ordered.map(\.totalLoad).max() ?? 0
        let yTicks = InsightsChartAxisFormatting.sessionAxisTickValues(maxCount: maxLoad)
        let yMax = Double(yTicks.last ?? 1)
        let loadColor = XkalaTheme.mint

        return Chart {
            ForEach(ordered) { point in
                BarMark(
                    x: .value("Periodo", point.chronologicalIndex),
                    y: .value("Carga", point.totalLoad)
                )
                .foregroundStyle(loadColor.opacity(0.92))
                .cornerRadius(4)
            }
        }
        .chartXScale(domain: xDomain)
        .chartYScale(domain: 0...yMax)
        .chartPlotStyle { plotArea in
            plotArea.padding(InsightsChartAxisFormatting.chartPlotPadding(for: range))
        }
        .chartXAxis(.hidden)
        .insightsChartAxisOverlay(
            axisLabels: ordered.map(\.axisLabel),
            bucketCount: ordered.count,
            range: range
        )
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
