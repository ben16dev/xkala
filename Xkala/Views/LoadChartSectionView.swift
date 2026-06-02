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
        let rockLoad: Int
        let gymLoad: Int
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
                    totalLoad: bucket.totalLoad,
                    rockLoad: bucket.rockLoad,
                    gymLoad: bucket.gymLoad
                )
            }
    }

    private var showsOriginLegend: Bool {
        buckets.contains { $0.rockLoad > 0 } && buckets.contains { $0.gymLoad > 0 }
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

            if showsOriginLegend {
                SessionOriginChartLegend(origins: [.gym, .rock])
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

        return Chart {
            ForEach(ordered) { point in
                let gymEnd = Double(point.gymLoad)
                let totalEnd = Double(point.totalLoad)

                if point.gymLoad > 0 {
                    BarMark(
                        x: .value("Periodo", point.chronologicalIndex),
                        yStart: .value("Carga", 0),
                        yEnd: .value("Carga", gymEnd)
                    )
                    .foregroundStyle(SessionOrigin.gym.chartColor.opacity(0.92))
                    .cornerRadius(point.rockLoad > 0 ? 0 : 4)
                }

                if point.rockLoad > 0 {
                    BarMark(
                        x: .value("Periodo", point.chronologicalIndex),
                        yStart: .value("Carga", gymEnd),
                        yEnd: .value("Carga", totalEnd)
                    )
                    .foregroundStyle(SessionOrigin.rock.chartColor.opacity(0.92))
                    .cornerRadius(4)
                }
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
