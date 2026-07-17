import Charts
import SwiftData
import SwiftUI

/// Tendencias globales de entreno (estilo Strava): gráficos derivados, sin persistencia.
struct InsightsView: View {
    /// Si es `true`, solo el contenido (para incrustar en el scroll de otra pantalla, p. ej. Perfil).
    var isEmbedded: Bool = false

    @Query(sort: \WorkoutDay.date, order: .reverse) private var workouts: [WorkoutDay]
    @State private var selectedRange: StatsRange = .sevenDays
    @State private var selectedMetric: InsightsMetric = .time

    private var snapshot: InsightsSnapshot {
        InsightsCalculator.snapshot(from: workouts, range: selectedRange)
    }

    var body: some View {
        Group {
            if isEmbedded {
                insightsContent
            } else {
                ScrollView {
                    insightsContent
                }
                .navigationTitle("Insights")
                .navigationBarTitleDisplayMode(.large)
            }
        }
    }

    private var insightsContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Tu actividad")
                .font(.title2.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)

            InsightsRangePicker(selection: $selectedRange)

            InsightsMetricPicker(selection: $selectedMetric)
            InsightsChartCard(
                buckets: snapshot.buckets,
                metric: selectedMetric,
                range: selectedRange
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, isEmbedded ? 4 : 12)
    }

}

// MARK: - Métrica del gráfico

private enum InsightsMetric: String, CaseIterable, Identifiable {
    case time = "Tiempo"
    case sessions = "Sesiones"

    var id: String { rawValue }
}

// MARK: - Selectores

private struct InsightsRangePicker: View {
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

private struct InsightsMetricPicker: View {
    @Binding var selection: InsightsMetric

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(InsightsMetric.allCases) { metric in
                    let isOn = selection == metric
                    Button {
                        selection = metric
                    } label: {
                        Text(metric.rawValue)
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

// MARK: - Gráfico principal

private struct InsightsChartCard: View {
    let buckets: [InsightsBucket]
    let metric: InsightsMetric
    let range: StatsRange

    private let chartHeight: CGFloat = 200

    /// Orden estable para series y ejes (cronológico ascendente real).
    private var bucketsOrdered: [InsightsBucket] {
        buckets.sorted {
            if $0.intervalStart != $1.intervalStart {
                return $0.intervalStart < $1.intervalStart
            }
            return $0.chronologicalIndex < $1.chronologicalIndex
        }
    }

    /// Orígenes con datos para la métrica activa (solo los presentes).
    private var originsForMetric: [SessionOrigin] {
        switch metric {
        case .time:
            return SessionOrigin.originsPresent(in: bucketsOrdered) { bucket, origin in
                bucket.timeSeconds(for: origin) / 60
            }
        case .sessions:
            return SessionOrigin.originsPresent(in: bucketsOrdered) { bucket, origin in
                Double(bucket.sessionCount(for: origin))
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            if originsForMetric.count > 1 {
                SessionOriginChartLegend(origins: originsForMetric)
            }

            chartCore
                .frame(maxWidth: .infinity)
                .frame(height: chartHeight)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .xkalaCard()
    }

    @ViewBuilder
    private var chartCore: some View {
        switch metric {
        case .time:
            timeChart()
        case .sessions:
            sessionsChart()
        }
    }

    @ViewBuilder
    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(headerTitle)
                .font(.headline)
            Text(headerSubtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var headerTitle: String {
        switch metric {
        case .time: return "Tiempo entrenado"
        case .sessions: return "Sesiones"
        }
    }

    private var headerSubtitle: String {
        switch metric {
        case .time:
            return "Duración de todas las sesiones finalizadas por periodo"
        case .sessions:
            return "Entrenos con inicio y fin registrados."
        }
    }

    private func timeChart() -> some View {
        let ordered = bucketsOrdered
        let origins = originsForMetric
        let xDomain = InsightsChartAxisFormatting.chartXDomain(bucketCount: ordered.count, range: range)
        let maxDataMinutes = ordered.map { bucket in
            origins.map { bucket.timeSeconds(for: $0) / 60 }.max() ?? 0
        }.max() ?? 0
        let yTicks = InsightsChartAxisFormatting.timeAxisTickMinutes(maxDataMinutes: maxDataMinutes)
        let yMax = yTicks.last ?? 30
        let interp = InsightsChartAxisFormatting.lineInterpolation
        let lw = InsightsChartAxisFormatting.lineWidth
        let ps = InsightsChartAxisFormatting.pointSize

        return Chart {
            ForEach(origins, id: \.rawValue) { origin in
                ForEach(ordered, id: \.id) { bucket in
                    let minutes = bucket.timeSeconds(for: origin) / 60
                    LineMark(
                        x: .value("Periodo", bucket.chronologicalIndex),
                        y: .value("Minutos", minutes),
                        series: .value("Origen", origin.displayName)
                    )
                    .interpolationMethod(interp)
                    .foregroundStyle(origin.chartColor.opacity(0.94))
                    .lineStyle(StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round))

                    PointMark(
                        x: .value("Periodo", bucket.chronologicalIndex),
                        y: .value("Minutos", minutes)
                    )
                    .foregroundStyle(origin.chartColor)
                    .symbolSize(ps)
                }
            }
        }
        .chartXScale(domain: xDomain)
        .chartYScale(domain: 0...yMax)
        .chartPlotStyle { plotArea in
            plotArea.padding(InsightsChartAxisFormatting.chartPlotPadding(for: range))
        }
        .chartXAxis(.hidden)
        .insightsChartAxisOverlay(orderedBuckets: ordered, range: range)
        .chartYAxis {
            AxisMarks(position: .leading, values: yTicks) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: InsightsChartAxisFormatting.horizontalGuideLineWidth))
                    .foregroundStyle(InsightsChartAxisFormatting.horizontalGuideColor)
                AxisValueLabel {
                    if let mins = value.as(Double.self) {
                        Text(InsightsChartAxisFormatting.formatDurationHoursMinutes(totalMinutes: mins))
                            .font(.caption2.monospacedDigit().weight(.medium))
                    }
                }
                .foregroundStyle(InsightsChartAxisFormatting.timeAxisLabelColor)
            }
        }
        .chartLegend(.hidden)
    }

    private func sessionsChart() -> some View {
        let ordered = bucketsOrdered
        let origins = originsForMetric
        let xDomain = InsightsChartAxisFormatting.chartXDomain(bucketCount: ordered.count, range: range)
        let maxSessions = ordered.map { bucket in
            origins.map { Double(bucket.sessionCount(for: $0)) }.max() ?? 0
        }.max() ?? 0
        let yTicks = InsightsChartAxisFormatting.sessionAxisTickValues(maxCount: Int(maxSessions))
        let yMax = Double(yTicks.last ?? 1)
        let interp = InsightsChartAxisFormatting.lineInterpolation
        let lw = InsightsChartAxisFormatting.lineWidth
        let ps = InsightsChartAxisFormatting.pointSize

        return Chart {
            ForEach(origins, id: \.rawValue) { origin in
                ForEach(ordered, id: \.id) { bucket in
                    let count = bucket.sessionCount(for: origin)
                    LineMark(
                        x: .value("Periodo", bucket.chronologicalIndex),
                        y: .value("Sesiones", count),
                        series: .value("Origen", origin.displayName)
                    )
                    .interpolationMethod(interp)
                    .foregroundStyle(origin.chartColor.opacity(0.96))
                    .lineStyle(StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round))

                    PointMark(
                        x: .value("Periodo", bucket.chronologicalIndex),
                        y: .value("Sesiones", count)
                    )
                    .foregroundStyle(origin.chartColor)
                    .symbolSize(ps)
                }
            }
        }
        .chartXScale(domain: xDomain)
        .chartYScale(domain: 0...yMax)
        .chartPlotStyle { plotArea in
            plotArea.padding(InsightsChartAxisFormatting.chartPlotPadding(for: range))
        }
        .chartXAxis(.hidden)
        .insightsChartAxisOverlay(orderedBuckets: ordered, range: range)
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
        .chartLegend(.hidden)
    }
}

