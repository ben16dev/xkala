import Charts
import SwiftUI

/// Formato compartido de ejes para gráficos temporales (Insights, Progreso, Carga).
enum InsightsChartAxisFormatting {
    static let lineInterpolation: InterpolationMethod = .catmullRom
    static let lineWidth: CGFloat = 2.75
    static let pointSize: CGFloat = 54

    static func formatDurationHoursMinutes(totalMinutes: Double) -> String {
        let total = Int((totalMinutes).rounded(.toNearestOrAwayFromZero))
        let h = total / 60
        let m = abs(total % 60)
        return String(format: "%d:%02d", h, m)
    }

    static func timeAxisTickMinutes(maxDataMinutes: Double) -> [Double] {
        let raw = max(0, maxDataMinutes)
        let cap30 = max(ceil(raw / 30) * 30, 30)
        var ticks: [Double] = []
        var v: Double = 0
        while v <= cap30 + 1e-9 {
            ticks.append(v)
            v += 30
        }
        if ticks.count > 7 {
            ticks = []
            let cap60 = max(ceil(raw / 60) * 60, 60)
            v = 0
            while v <= cap60 + 1e-9 {
                ticks.append(v)
                v += 60
            }
        }
        return ticks
    }

    static func sessionAxisTickValues(maxCount: Int) -> [Int] {
        let m = max(1, maxCount)
        let roughStep = max(1, (m + 3) / 4)
        var out: [Int] = [0]
        var v = roughStep
        while v < m {
            out.append(v)
            v += roughStep
        }
        out.append(m)
        return Array(Set(out)).sorted()
    }

    static func chartXDomain(bucketCount: Int, range: StatsRange) -> ClosedRange<Double> {
        guard bucketCount > 0 else { return 0...0 }
        let last = Double(bucketCount - 1)
        let inset = xAxisDomainInset(for: range)
        return -inset...(last + inset)
    }

    static func xAxisDomainInset(for range: StatsRange) -> Double {
        switch range {
        case .sevenDays: 0.42
        case .oneMonth: 0.62
        case .threeMonths: 0.52
        case .sixMonths: 0.48
        case .oneYear: 0.52
        }
    }

    static let xAxisLabelBelowPlotOffset: CGFloat = 12
    static let verticalGuideLineWidth: CGFloat = 0.5
    static let verticalGuideColor = Color.white.opacity(0.06)
    static let horizontalGuideLineWidth: CGFloat = 0.5
    static let horizontalGuideColor = Color.white.opacity(0.06)

    static func chartPlotPadding(for range: StatsRange) -> EdgeInsets {
        let bottom: CGFloat = switch range {
        case .oneMonth: 22
        case .oneYear, .sixMonths, .sevenDays, .threeMonths: 20
        }
        return EdgeInsets(top: 4, leading: 6, bottom: bottom, trailing: 6)
    }

    static let timeLineColor = XkalaTheme.chartTimeLine
    static let timeAxisLabelColor = Color.white.opacity(0.88)

    /// Etiqueta visible del eje X: semanas numeradas por posición cronológica en 1M/3M.
    static func displayAxisLabel(storedLabel: String, index: Int, range: StatsRange) -> String {
        switch range {
        case .oneMonth, .threeMonths:
            return "SEM \(index + 1)"
        case .sevenDays, .sixMonths, .oneYear:
            return storedLabel
        }
    }

    /// Índices con etiqueta visible; 1M muestra todas las SEM; 3M solo cada 3 semanas.
    static func displayAxisLabelIndices(bucketCount: Int, range: StatsRange) -> [Int] {
        switch range {
        case .oneMonth:
            return InsightsCalculator.allBucketAxisIndices(bucketCount: bucketCount)
        case .threeMonths:
            return [0, 3, 6, 9, 12].filter { $0 < bucketCount }
        case .sevenDays, .sixMonths, .oneYear:
            return InsightsCalculator.visibleAxisLabelIndices(bucketCount: bucketCount, range: range)
        }
    }
}

extension View {
    func insightsChartAxisOverlay(orderedBuckets: [InsightsBucket], range: StatsRange) -> some View {
        insightsChartAxisOverlay(
            axisLabels: orderedBuckets.map(\.axisLabel),
            bucketCount: orderedBuckets.count,
            range: range
        )
    }

    func insightsChartAxisOverlay(axisLabels: [String], bucketCount: Int, range: StatsRange) -> some View {
        chartOverlay { proxy in
            GeometryReader { geometry in
                let plotFrame = geometry[proxy.plotAreaFrame]
                let guideIndices = InsightsCalculator.allBucketAxisIndices(bucketCount: bucketCount)
                let labelIndices = InsightsChartAxisFormatting.displayAxisLabelIndices(
                    bucketCount: bucketCount,
                    range: range
                )

                ForEach(guideIndices, id: \.self) { index in
                    if let x = proxy.position(forX: Double(index)) {
                        let lineX = plotFrame.origin.x + x
                        Path { path in
                            path.move(to: CGPoint(x: lineX, y: plotFrame.minY))
                            path.addLine(to: CGPoint(x: lineX, y: plotFrame.maxY))
                        }
                        .stroke(
                            InsightsChartAxisFormatting.verticalGuideColor,
                            lineWidth: InsightsChartAxisFormatting.verticalGuideLineWidth
                        )
                    }
                }

                ForEach(labelIndices, id: \.self) { index in
                    if axisLabels.indices.contains(index),
                       let x = proxy.position(forX: Double(index)) {
                        let tickX = plotFrame.origin.x + x
                        let labelY = plotFrame.maxY + InsightsChartAxisFormatting.xAxisLabelBelowPlotOffset
                        let label = InsightsChartAxisFormatting.displayAxisLabel(
                            storedLabel: axisLabels[index],
                            index: index,
                            range: range
                        )
                        Text(label)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(Color.white.opacity(0.82))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: true, vertical: false)
                            .lineLimit(1)
                            .minimumScaleFactor(1)
                            .allowsTightening(false)
                            .position(x: tickX, y: labelY)
                    }
                }
            }
        }
    }
}
