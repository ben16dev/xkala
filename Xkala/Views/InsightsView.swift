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
    case venue = "Tipo"

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

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            if metric == .venue {
                venueLegend
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
            timeOnlyChart()
        case .sessions:
            sessionsOnlyChart()
        case .venue:
            venueStackedChart()
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
        case .venue: return "Tipo de sesión"
        }
    }

    private var headerSubtitle: String {
        switch metric {
        case .time:
            return "Cronómetro por periodo (sesiones finalizadas)."
        case .sessions:
            return "Entrenos con inicio y fin registrados."
        case .venue:
            return "Sesiones por tipo (rocódromo y roca), mismos periodos y filtro de cronómetro que arriba."
        }
    }

    private var venueLegend: some View {
        HStack(spacing: 16) {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(XkalaTheme.sessionTraining)
                    .frame(width: 12, height: 12)
                Text("Rocódromo")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(XkalaTheme.sessionClimbing)
                    .frame(width: 12, height: 12)
                Text("Roca")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func timeOnlyChart() -> some View {
        let ordered = bucketsOrdered
        let xDomain = InsightsChartAxisFormatting.chartXDomain(bucketCount: ordered.count, range: range)
        let yTicks = InsightsChartAxisFormatting.timeAxisTickMinutes(
            maxDataMinutes: ordered.map { $0.trainingTimeSeconds / 60 }.max() ?? 0
        )
        let yMax = yTicks.last ?? 30
        let interp = InsightsChartAxisFormatting.lineInterpolation
        let lw = InsightsChartAxisFormatting.lineWidth
        let ps = InsightsChartAxisFormatting.pointSize
        let timeColor = InsightsChartAxisFormatting.timeLineColor

        return Chart {
            ForEach(ordered, id: \.id) { bucket in
                LineMark(
                    x: .value("Periodo", bucket.chronologicalIndex),
                    y: .value("Minutos", bucket.trainingTimeSeconds / 60)
                )
                .interpolationMethod(interp)
                .foregroundStyle(timeColor.opacity(0.95))
                .lineStyle(StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round))

                PointMark(
                    x: .value("Periodo", bucket.chronologicalIndex),
                    y: .value("Minutos", bucket.trainingTimeSeconds / 60)
                )
                .foregroundStyle(timeColor)
                .symbolSize(ps)
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
    }

    private func sessionsOnlyChart() -> some View {
        let ordered = bucketsOrdered
        let xDomain = InsightsChartAxisFormatting.chartXDomain(bucketCount: ordered.count, range: range)
        let maxSessions = ordered.map(\.sessionCount).max() ?? 0
        let yTicks = InsightsChartAxisFormatting.sessionAxisTickValues(maxCount: maxSessions)
        let yMax = Double(yTicks.last ?? 1)
        let interp = InsightsChartAxisFormatting.lineInterpolation
        let lw = InsightsChartAxisFormatting.lineWidth
        let ps = InsightsChartAxisFormatting.pointSize

        return Chart {
            ForEach(ordered, id: \.id) { bucket in
                LineMark(
                    x: .value("Periodo", bucket.chronologicalIndex),
                    y: .value("Sesiones", bucket.sessionCount)
                )
                .interpolationMethod(interp)
                .foregroundStyle(XkalaTheme.chartSessions.opacity(0.96))
                .lineStyle(StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round))

                PointMark(
                    x: .value("Periodo", bucket.chronologicalIndex),
                    y: .value("Sesiones", bucket.sessionCount)
                )
                .foregroundStyle(XkalaTheme.chartSessions)
                .symbolSize(ps)
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
    }

    /// Dos líneas: rocódromo (turquesa) y roca (amarillo); misma ventana que tiempo/sesiones.
    private func venueStackedChart() -> some View {
        let ordered = bucketsOrdered
        let xDomain = InsightsChartAxisFormatting.chartXDomain(bucketCount: ordered.count, range: range)
        let maxVenue = ordered.map { max($0.trainingSessions, $0.climbingSessions) }.max() ?? 0
        let yTicks = InsightsChartAxisFormatting.sessionAxisTickValues(maxCount: maxVenue)
        let yMax = Double(yTicks.last ?? 1)
        let interp = InsightsChartAxisFormatting.lineInterpolation
        let lw = InsightsChartAxisFormatting.lineWidth
        let ps = InsightsChartAxisFormatting.pointSize

        return Chart {
            ForEach(ordered, id: \.id) { bucket in
                LineMark(
                    x: .value("Periodo", bucket.chronologicalIndex),
                    y: .value("Sesiones", bucket.trainingSessions),
                    series: .value("Tipo", "Rocódromo")
                )
                .interpolationMethod(interp)
                .foregroundStyle(XkalaTheme.sessionTraining.opacity(0.94))
                .lineStyle(StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round))

                PointMark(
                    x: .value("Periodo", bucket.chronologicalIndex),
                    y: .value("Sesiones", bucket.trainingSessions)
                )
                .foregroundStyle(XkalaTheme.sessionTraining)
                .symbolSize(ps)
            }
            ForEach(ordered, id: \.id) { bucket in
                LineMark(
                    x: .value("Periodo", bucket.chronologicalIndex),
                    y: .value("Sesiones", bucket.climbingSessions),
                    series: .value("Tipo", "Roca")
                )
                .interpolationMethod(interp)
                .foregroundStyle(XkalaTheme.sessionClimbing.opacity(0.94))
                .lineStyle(StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round))

                PointMark(
                    x: .value("Periodo", bucket.chronologicalIndex),
                    y: .value("Sesiones", bucket.climbingSessions)
                )
                .foregroundStyle(XkalaTheme.sessionClimbing)
                .symbolSize(ps)
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
                .foregroundStyle(InsightsChartAxisFormatting.timeAxisLabelColor)
            }
        }
        .chartLegend(.hidden)
    }
}

